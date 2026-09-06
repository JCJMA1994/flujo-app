package com.flujo.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import android.util.LruCache
import androidx.core.app.NotificationCompat
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
            // ── Banco de la Nación ──
            "pe.gob.bn.bnamovil",
            "pe.gob.bn.app",
            // ── Banco Falabella ──
            "pe.bancofalabella.movil",
            "pe.falabella.bancofalabella",
            // ── Banco Ripley ──
            "pe.com.ripley.banco",
            // ── BanBif ──
            "pe.com.banbif.android",
            "pe.com.banbif.banbifmovil",
            // ── Banco Pichincha ──
            "com.pichincha.pe",
            // ── Cajas Municipales (Apps oficiales) ──
            "pe.com.cajaarequipa.cajamovil",
            "pe.com.cajaarequipa.agora",
            "pe.com.cajahuancayo.cajamovil",
            "pe.com.cajahuancayo.migente",
            "pe.com.cajapiura.cajamovil",
            "pe.com.cajapiura.pexpe",
            "com.pexpe.app",
            "pe.com.cajacusco.cmacmovil",
            // ── Billeteras Digitales Peruanas ──
            "pe.com.pdp.bim",
            "pe.interbank.tunki",
            "com.tunki.app",
            "pe.com.agora.wallet",
            "pe.com.agora",
            "pe.com.tarjetasperuanas.ligo",
            "pe.com.ligo.app",
            "pe.com.maximo.app",
            "com.maximo.wallet",
            // ── Billeteras Internacionales / Remesas ──
            "com.paypal.android.p2pmobile",
            "com.mercadopago.wallet",
            "com.mercadolibre.wallet",
            "ar.com.lemon",
            "com.lemoncash.app",
            "com.grability.rappi",
            "com.westernunion.android.wsapp.pe",
            "com.westernunion.moneytransfer"
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

                // 5. Si Flutter está disponible (primer o segundo plano), emitir evento en tiempo real
                if (rawId != -1L) {
                    val mainActivity = MainActivity.currentInstance
                    if (mainActivity != null) {
                        val notifMap = mapOf(
                            "id" to rawId,
                            "notificationKey" to notifKey,
                            "notificationHash" to notifHash,
                            "packageName" to packageName,
                            "title" to title,
                            "content" to text,
                            "timestamp" to postTime
                        )
                        // Marcar como procesada inmediatamente para evitar doble entrega al reanudar
                        dbHelper.markAsProcessed(listOf(rawId))
                        mainActivity.sendNotificationToFlutter(notifMap)
                        Log.i(TAG, "Notificación financiera emitida exitosamente a Flutter: $packageName")
                    } else {
                        // 6. Si Flutter no está activo en memoria, alertar en segundo plano y encolar Worker
                        Log.i(TAG, "Flutter no activo en memoria. Mostrando alerta nativa en segundo plano.")
                        showBackgroundNotification(applicationContext, title, text)
                        com.flujo.app.worker.NotificationProcessingWorker.enqueueImmediate(applicationContext)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error procesando notificación financiera", e)
        }
    }

    private fun showBackgroundNotification(context: Context, title: String, text: String) {
        try {
            val channelId = "flujo_transactions"
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "Movimientos y Pagos",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notificaciones de confirmación cuando se registra un gasto o ingreso"
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val notif = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(if (title.isNotBlank()) "💰 $title" else "💰 Movimiento detectado")
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()

            notificationManager.notify((System.currentTimeMillis() % 10000).toInt(), notif)
        } catch (e: Exception) {
            Log.e(TAG, "Error mostrando notificación nativa en segundo plano", e)
        }
    }

    private fun computeSha256(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = digest.digest(input.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
