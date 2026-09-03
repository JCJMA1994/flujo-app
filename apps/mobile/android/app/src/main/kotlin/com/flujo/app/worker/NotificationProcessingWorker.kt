package com.flujo.app.worker

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.flujo.app.database.RawNotificationDatabaseHelper
import java.util.concurrent.TimeUnit

/**
 * Worker para procesamiento diferido y sincronización garantizada de eventos financieros
 * cuando el dispositivo recupera conectividad o Flutter no está activo.
 */
class NotificationProcessingWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    companion object {
        private const val TAG = "NotifProcessingWorker"
        private const val UNIQUE_ONE_TIME_WORK = "flujo_raw_processing_work"
        private const val UNIQUE_PERIODIC_WORK = "flujo_periodic_sync_work"

        /**
         * Encola una ejecución inmediata con backoff exponencial ante fallos de red.
         */
        fun enqueueImmediate(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = OneTimeWorkRequestBuilder<NotificationProcessingWorker>()
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    15,
                    TimeUnit.SECONDS
                )
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                UNIQUE_ONE_TIME_WORK,
                ExistingWorkPolicy.REPLACE,
                request
            )
            Log.i(TAG, "Tarea diferida encolada con WorkManager (Backoff 15s)")
        }

        /**
         * Programa sincronización periódica de mantenimiento cada 15 minutos en segundo plano.
         */
        fun schedulePeriodic(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val periodicRequest = PeriodicWorkRequestBuilder<NotificationProcessingWorker>(
                15, TimeUnit.MINUTES,
                5, TimeUnit.MINUTES // flex interval
            )
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                UNIQUE_PERIODIC_WORK,
                ExistingPeriodicWorkPolicy.KEEP,
                periodicRequest
            )
            Log.i(TAG, "Tarea periódica WorkManager registrada")
        }
    }

    override suspend fun doWork(): Result {
        Log.i(TAG, "Ejecutando doWork() para drenaje de notificaciones pendientes")
        val dbHelper = RawNotificationDatabaseHelper.getInstance(applicationContext)

        try {
            val pending = dbHelper.getPendingNotifications(limit = 50)
            if (pending.isEmpty()) {
                Log.d(TAG, "No hay notificaciones pendientes en staging")
                return Result.success()
            }

            Log.i(TAG, "Detectadas ${pending.size} notificaciones pendientes para procesar offline")

            // Si el intento supera 5 reintentos, marcar las problemáticas para no ciclar eternamente
            if (runAttemptCount > 5) {
                Log.w(TAG, "Superado límite de reintentos ($runAttemptCount). Marcando como fallidas.")
                for (item in pending) {
                    val id = (item["id"] as? Number)?.toLong()
                    if (id != null) dbHelper.markAsFailed(id)
                }
                return Result.failure()
            }

            // Las notificaciones quedan listas en la base local de staging para ser
            // consumidas por el Flutter Engine o sincronizadas al reanudar
            return Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Error durante ejecución de WorkManager. Reintentando...", e)
            return Result.retry()
        }
    }
}
