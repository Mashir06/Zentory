package com.example.zentoryapp

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Además de la actividad de Flutter, expone el canal "zentory/device" para que
 * Dart pueda revisar y abrir los ajustes que afectan a las notificaciones
 * programadas. Esto es clave en ROMs chinas (ColorOS, MIUI/HyperOS, OriginOS,
 * EMUI/HarmonyOS...), que bloquean por defecto el inicio automático, la
 * actividad en segundo plano y a veces las propias notificaciones.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getStatus" -> result.success(status())
                        "openNotificationSettings" -> result.success(openNotificationSettings())
                        "openExactAlarmSettings" -> result.success(openExactAlarmSettings())
                        "requestIgnoreBatteryOptimizations" -> result.success(requestIgnoreBatteryOptimizations())
                        "openAutoStartSettings" -> result.success(openAutoStartSettings())
                        "openAppDetails" -> result.success(openAppDetails())
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("device_error", e.message, null)
                }
            }
    }

    private fun status(): Map<String, Any> {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val exact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) am.canScheduleExactAlarms() else true
        return mapOf(
            "manufacturer" to Build.MANUFACTURER.orEmpty(),
            "brand" to Build.BRAND.orEmpty(),
            "model" to Build.MODEL.orEmpty(),
            "sdkInt" to Build.VERSION.SDK_INT,
            "notificationsEnabled" to nm.areNotificationsEnabled(),
            "exactAlarmsAllowed" to exact,
            "ignoringBatteryOptimizations" to pm.isIgnoringBatteryOptimizations(packageName),
        )
    }

    private fun tryStart(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            // ActivityNotFoundException / SecurityException: esa pantalla no
            // existe o no es accesible en esta versión del sistema.
            false
        }
    }

    private fun openNotificationSettings(): Boolean {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        return tryStart(intent) || openAppDetails()
    }

    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))
        return tryStart(intent) || openAppDetails()
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        val request = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:$packageName"),
        )
        return tryStart(request) ||
            tryStart(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) ||
            openAppDetails()
    }

    /**
     * Intenta abrir la pantalla de "Inicio automático" / "Actividad en segundo
     * plano" propia de cada fabricante. Devuelve "oem" si abrió una pantalla del
     * fabricante, "app_details" si tuvo que abrir la ficha de la app, o "none".
     */
    private fun openAutoStartSettings(): String {
        for (component in AUTOSTART_COMPONENTS) {
            val intent = Intent().setComponent(component)
            if (tryStart(intent)) return "oem"
        }
        return if (openAppDetails()) "app_details" else "none"
    }

    private fun openAppDetails(): Boolean {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        return tryStart(intent)
    }

    companion object {
        private const val CHANNEL = "zentory/device"

        /** Pantallas conocidas de inicio automático / segundo plano por fabricante. */
        private val AUTOSTART_COMPONENTS = listOf(
            // OPPO / realme / OnePlus (ColorOS, realme UI, OxygenOS 13+)
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
            ComponentName("com.oplus.safecenter", "com.oplus.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            ComponentName("com.coloros.oppoguardelf", "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"),
            ComponentName("com.oplus.battery", "com.oplus.powermanager.fuelgaue.PowerControlActivity"),
            ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"),
            // Xiaomi / Redmi / POCO (MIUI, HyperOS)
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            // vivo / iQOO (OriginOS, Funtouch)
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"),
            // Huawei / Honor (EMUI, HarmonyOS, MagicOS)
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
            ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            // Meizu, Asus, Letv
            ComponentName("com.meizu.safe", "com.meizu.safe.security.SHOW_APPSEC"),
            ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity"),
            ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity"),
        )
    }
}
