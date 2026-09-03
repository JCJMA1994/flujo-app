package com.flujo.app

import android.app.Notification
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import android.util.LruCache
import com.flujo.app.database.RawNotificationDatabaseHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.security.MessageDigest

class FlujoNotificationListener : NotificationListenerService() {

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    companion object {
        private const val TAG = "FlujoNotifListener"

        // Cache LRU de 100 hashes para descartar en microsegundos duplicados en ráfaga
        private val recentHashes = LruCache<String, Boolean>(100)

        /**
         * Whitelist estricta de paquetes financieros autorizados.
         * NUNCA agregar apps de mensajería, correo o redes sociales.
         */
        private val BANK_PACKAGES = setOf(
            // ── Yape / BCP ──
            "pe.com.bcp.bank.bcp",
            "com.bcp.innovacxion.yapeapp",
            "pe.com.bcp.innovacxion.yapeapp",
            "com.bcp.yape",
            // ── Plin / Interbank ──
            "pe.interbank.appnew",
            "pe.plin.app",
            // ── BBVA ──
            "com.bbva.pe.bbvacontigo",
            // ── Scotiabank ──
            "pe.scotiabank.banking",
            // ── BanBif ──
            "pe.com.banbif.android",
            "pe.com.banbif.banbifmovil",
            // ── Banco Pichincha ──
            "com.pichincha.pe",
            // ── Pexpe (Caja Piura) ──
            "pe.com.cajapiura.pexpe",
            "com.pexpe.app",
            // ── Tunki (Interbank) ──
            "pe.interbank.tunki",
            "com.tunki.app",
            // ── Agora (Caja Arequipa) ──
            "pe.com.cajaarequipa.agora",
            // ── MiGente (Caja Huancayo) ──
            "pe.com.cajahuancayo.migente",
            // ── Mercado Pago ──
            "com.mercadopago.wallet",
            "com.mercadolibre.wallet",
            // ── Máximo ──
            "pe.com.maximo.app",
            "com.maximo.wallet",
            // ── Lemon Cash ──
            "ar.com.lemon",
            "com.lemoncash.app",
            // ── Rappi Pay ──
            "com.grability.rappi"
        )

        @Volatile
        var activeInstance: FlujoNotificationListener? = null
            private set

        fun isListenerConnected(): Boolean = activeInstance != null
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        activeInstance = this
        Log.i(TAG, "FlujoNotificationListener conectado exitosamente al sistema Android")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        if (activeInstance == this) activeInstance = null
        Log.w(TAG, "FlujoNotificationListener desconectado del sistema Android")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null || sbn.notification == null) return

        val packageName = (sbn.packageName ?: "").lowercase()

        // 1. Whitelist estricta: Descartar de inmediato cualquier app que no esté en la lista
        if (!BANK_PACKAGES.contains(packageName)) {
            return
        }

        try {
            val extras = sbn.notification.extras ?: Bundle()
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
            val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString()?.trim() ?: ""

            // Descartar notificaciones vacías de control del sistema
            if (title.isBlank() && text.isBlank()) return

            val postTime = sbn.postTime
            val notifKey = sbn.key ?: "${packageName}_${sbn.id}_$postTime"

            // 2. Hash determinístico con bucket corto de 15 segundos para evitar falsos positivos
            // de pagos legítimos consecutivos pero filtrar reemisiones en ráfaga
            val timeBucket = postTime / 15000L
            val rawPayload = "$packageName|$title|$text|$timeBucket"
            val notifHash = computeSha256(rawPayload)

            // 3. Deduplicación rápida en memoria
            synchronized(recentHashes) {
                if (recentHashes.get(notifHash) != null) {
                    Log.d(TAG, "Notificación duplicada en memoria descartada: $packageName")
                    return
                }
                recentHashes.put(notifHash, true)
            }

            Log.i(TAG, "Notificación financiera válida recibida de: $packageName (key=$notifKey)")

            // 4. Persistencia RAW inmediata en la base de datos de staging nativa (Dispatchers.IO)
            serviceScope.launch {
                val dbHelper = RawNotificationDatabaseHelper.getInstance(applicationContext)
                val rawId = dbHelper.insertRawNotification(
                    notificationKey = notifKey,
                    notificationHash = notifHash,
                    packageName = packageName,
                    title = title,
                    body = text,
                    postTime = postTime
                )

                // 5. Si Flutter está activo en primer plano, emitir evento en tiempo real
                if (rawId != -1L) {
                    val mainActivity = MainActivity.currentInstance
                    if (mainActivity != null && mainActivity.isAppForeground) {
                        val notifMap = mapOf(
                            "id" to rawId,
                            "notificationKey" to notifKey,
                            "notificationHash" to notifHash,
                            "packageName" to packageName,
                            "title" to title,
                            "content" to text,
                            "timestamp" to postTime
                        )
                        mainActivity.sendNotificationToFlutter(notifMap)
                    } else {
                        // 6. Si Flutter está cerrado o en background, encolar procesamiento con WorkManager
                        com.flujo.app.worker.NotificationProcessingWorker.enqueueImmediate(applicationContext)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error procesando notificación financiera", e)
        }
    }

    private fun computeSha256(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = digest.digest(input.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
