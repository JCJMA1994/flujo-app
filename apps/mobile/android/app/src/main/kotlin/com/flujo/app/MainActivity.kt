package com.flujo.app

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import com.flujo.app.database.RawNotificationDatabaseHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.math.max

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "FlujoMainActivity"
        private const val CHANNEL = "com.flujo.app/share"
        var currentInstance: MainActivity? = null
    }

    var isAppForeground = false
        private set

    private var sharedData: Map<String, Any?>? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val dbHelper = RawNotificationDatabaseHelper.getInstance(applicationContext)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedData" -> {
                    val data = sharedData
                    sharedData = null
                    result.success(data)
                }

                // ── API Nativa de Captura de Notificaciones ──
                "getPendingRawNotifications" -> {
                    val limit = (call.argument<Int>("limit")) ?: 100
                    val pending = dbHelper.getPendingNotifications(limit)
                    result.success(pending)
                }

                "markRawNotificationsProcessed" -> {
                    val rawIds = call.argument<List<Any>>("ids")
                    if (rawIds != null) {
                        val ids = rawIds.mapNotNull {
                            when (it) {
                                is Number -> it.toLong()
                                is String -> it.toLongOrNull()
                                else -> null
                            }
                        }
                        dbHelper.markAsProcessed(ids)
                    }
                    result.success(true)
                }

                "isNotificationPermissionGranted" -> {
                    val isGranted = NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)
                    result.success(isGranted)
                }

                "isListenerConnected" -> {
                    result.success(FlujoNotificationListener.isListenerConnected())
                }

                "getCaptureDiagnostics" -> {
                    val isGranted = NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)
                    val isConnected = FlujoNotificationListener.isListenerConnected()
                    val metrics = dbHelper.getDiagnosticMetrics()
                    val isBatteryIgnoring = com.flujo.app.optimizer.ManufacturerOptimizer.isIgnoringBatteryOptimizations(this)
                    val diagnostics = mapOf(
                        "permissionGranted" to isGranted,
                        "listenerConnected" to isConnected,
                        "isIgnoringBattery" to isBatteryIgnoring,
                        "isAggressiveOem" to com.flujo.app.optimizer.ManufacturerOptimizer.isAggressiveOem(),
                        "pendingCount" to (metrics[RawNotificationDatabaseHelper.STATUS_RECEIVED] ?: 0L),
                        "processedCount" to (metrics[RawNotificationDatabaseHelper.STATUS_PROCESSED] ?: 0L),
                        "failedCount" to (metrics[RawNotificationDatabaseHelper.STATUS_FAILED] ?: 0L),
                        "manufacturer" to Build.MANUFACTURER,
                        "model" to Build.MODEL,
                        "androidVersion" to Build.VERSION.SDK_INT,
                        "oemGuide" to com.flujo.app.optimizer.ManufacturerOptimizer.getManufacturerGuide()
                    )
                    result.success(diagnostics)
                }

                "openAutostartSettings" -> {
                    val success = com.flujo.app.optimizer.ManufacturerOptimizer.openAutostartSettings(this)
                    result.success(success)
                }

                "isIgnoringBatteryOptimizations" -> {
                    val isIgnoring = com.flujo.app.optimizer.ManufacturerOptimizer.isIgnoringBatteryOptimizations(this)
                    result.success(isIgnoring)
                }

                "requestNotificationPermission" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error opening notification listener settings", e)
                        result.success(false)
                    }
                }

                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            Log.e(TAG, "Error opening battery settings", e2)
                            result.success(false)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        currentInstance = this
        com.flujo.app.worker.NotificationProcessingWorker.schedulePeriodic(applicationContext)
        handleIntent(intent, isColdStart = true)
    }

    override fun onResume() {
        super.onResume()
        currentInstance = this
        isAppForeground = true
        // Notificar al canal que la app reanudó para sincronizar notificaciones pendientes
        methodChannel?.invokeMethod("onAppResumed", null)
    }

    override fun onPause() {
        super.onPause()
        isAppForeground = false
    }

    override fun onDestroy() {
        if (currentInstance == this) currentInstance = null
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, isColdStart = false)
    }

    fun sendNotificationToFlutter(data: Map<String, Any?>) {
        runOnUiThread {
            methodChannel?.invokeMethod("onNotificationReceived", data)
        }
    }

    private fun handleIntent(intent: Intent?, isColdStart: Boolean) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type

        if ((Intent.ACTION_SEND == action || Intent.ACTION_SEND_MULTIPLE == action) && type != null) {
            if (type.startsWith("image/")) {
                var imageUri: Uri? = null
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    try {
                        imageUri = intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    } catch (e: Exception) {
                        Log.w(TAG, "getParcelableExtra Tiramisu failed", e)
                    }
                }
                if (imageUri == null) {
                    @Suppress("DEPRECATION")
                    imageUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                }
                if (imageUri == null && intent.clipData != null && intent.clipData!!.itemCount > 0) {
                    imageUri = intent.clipData!!.getItemAt(0).uri
                }

                if (imageUri != null) {
                    try {
                        val inputStream = contentResolver.openInputStream(imageUri)
                        val originalBitmap = BitmapFactory.decodeStream(inputStream)
                        inputStream?.close()

                        if (originalBitmap != null) {
                            val maxDim = max(originalBitmap.width, originalBitmap.height)
                            val scaledBitmap = if (maxDim > 1280) {
                                val scale = 1280f / maxDim
                                Bitmap.createScaledBitmap(
                                    originalBitmap,
                                    (originalBitmap.width * scale).toInt(),
                                    (originalBitmap.height * scale).toInt(),
                                    true
                                )
                            } else {
                                originalBitmap
                            }

                            val out = ByteArrayOutputStream()
                            scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
                            val bytes = out.toByteArray()
                            out.close()

                            if (bytes.isNotEmpty()) {
                                val data = mapOf(
                                    "type" to "image",
                                    "bytes" to bytes,
                                    "mimeType" to "image/jpeg"
                                )
                                if (isColdStart) {
                                    sharedData = data
                                } else {
                                    methodChannel?.invokeMethod("onSharedData", data)
                                }
                                intent.action = null
                                return
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing image stream from $imageUri", e)
                    }
                }
            }

            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.text?.toString()

            if (!sharedText.isNullOrBlank()) {
                val data = mapOf(
                    "type" to "text",
                    "text" to sharedText
                )
                if (isColdStart) {
                    sharedData = data
                } else {
                    methodChannel?.invokeMethod("onSharedData", data)
                }
                intent.action = null
            }
        }
    }
}
