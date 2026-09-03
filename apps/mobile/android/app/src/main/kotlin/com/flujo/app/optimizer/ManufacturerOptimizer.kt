package com.flujo.app.optimizer

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

/**
 * Optimizador de ciclo de vida para dispositivos con gestión de batería agresiva
 * (Xiaomi/HyperOS, Samsung, Oppo, Realme, Vivo, Huawei).
 * Provee apertura de pantallas de configuración de Auto-inicio y Exención de Batería con fallbacks seguros.
 */
object ManufacturerOptimizer {
    private const val TAG = "ManufacturerOptimizer"

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return true
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun isAggressiveOem(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return manufacturer.contains("xiaomi") ||
                manufacturer.contains("redmi") ||
                manufacturer.contains("poco") ||
                manufacturer.contains("samsung") ||
                manufacturer.contains("huawei") ||
                manufacturer.contains("honor") ||
                manufacturer.contains("oppo") ||
                manufacturer.contains("realme") ||
                manufacturer.contains("oneplus") ||
                manufacturer.contains("vivo")
    }

    fun getManufacturerGuide(): Map<String, Any> {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val oemName = when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> "Xiaomi (HyperOS / MIUI)"
            manufacturer.contains("samsung") -> "Samsung (One UI)"
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> "Huawei / Honor"
            manufacturer.contains("oppo") || manufacturer.contains("realme") || manufacturer.contains("oneplus") -> "Oppo / Realme"
            manufacturer.contains("vivo") -> "Vivo"
            else -> "Estándar Android"
        }

        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "oemName" to oemName,
            "isAggressive" to isAggressiveOem()
        )
    }

    /**
     * Intenta abrir la pantalla propietaria de Auto-inicio (Autostart) del fabricante.
     * Si no existe o lanza SecurityException, recurre a la configuración de la aplicación de AOSP.
     */
    fun openAutostartSettings(context: Context): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val intents = mutableListOf<Intent>()

        when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> {
                intents.add(
                    Intent().setComponent(
                        ComponentName(
                            "com.miui.securitycenter",
                            "com.miui.permcenter.autostart.AutoStartManagementActivity"
                        )
                    )
                )
                intents.add(
                    Intent().setComponent(
                        ComponentName(
                            "com.miui.securitycenter",
                            "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"
                        )
                    )
                )
            }
            manufacturer.contains("samsung") -> {
                intents.add(
                    Intent().setComponent(
                        ComponentName(
                            "com.samsung.android.lool",
                            "com.samsung.android.sm.ui.battery.BatteryActivity"
                        )
                    )
                )
            }
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                intents.add(
                    Intent().setComponent(
                        ComponentName(
                            "com.huawei.systemmanager",
                            "com.huawei.systemmanager.optimize.process.ProtectActivity"
                        )
                    )
                )
                intents.add(
                    Intent().setComponent(
                        ComponentName(
                            "com.huawei.systemmanager",
                            "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity"
                        )
                    )
                )
            }
            manufacturer.contains("oppo") || manufacturer.contains("realme") -> {
                intents.add(
                    Intent().setComponent(
                        ComponentName(
                            "com.coloros.safecenter",
                            "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                        )
                    )
                )
                intents.add(
                    Intent().setComponent(
                        ComponentName(
                            "com.coloros.safecenter",
                            "com.coloros.safecenter.startupapp.StartupAppListActivity"
                        )
                    )
                )
            }
            manufacturer.contains("vivo") -> {
                intents.add(
                    Intent().setComponent(
                        ComponentName(
                            "com.iqoo.secure",
                            "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"
                        )
                    )
                )
            }
        }

        // Probar los intents propietarios en orden
        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                Log.i(TAG, "Lanzado intent propietario de fabricante: ${intent.component}")
                return true
            } catch (e: Exception) {
                Log.d(TAG, "Componente OEM no disponible: ${intent.component}, probando siguiente...")
            }
        }

        // Fallback universal a la pantalla de detalles de la aplicación
        return try {
            val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(fallbackIntent)
            Log.i(TAG, "Lanzado fallback universal de configuración de aplicación")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error abriendo fallback universal de configuración", e)
            false
        }
    }
}
