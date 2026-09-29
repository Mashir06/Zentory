package com.example.zentoryapp.uipr

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.util.*

object NotificationHelper {

    fun scheduleProductNotifications(context: Context, productName: String, expiryDateStr: String) {
        val expiryDate = try {
            sdf.parse(expiryDateStr)
        } catch (_: Exception) {
            null
        } ?: return

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // 1. Notificación 3 días antes (Cerca de vencer)
        val threeDaysBefore = Calendar.getInstance().apply {
            time = expiryDate
            add(Calendar.DAY_OF_YEAR, -3)
            set(Calendar.HOUR_OF_DAY, 9)
            set(Calendar.MINUTE, 0)
        }
        
        if (threeDaysBefore.timeInMillis > System.currentTimeMillis()) {
            scheduleNotification(
                context, 
                alarmManager, 
                productName, 
                "Está cerca de vencer (3 días)", 
                (productName + "3").hashCode(), 
                threeDaysBefore.timeInMillis,
            )
        }

        // 2. Notificación 1 día antes
        val oneDayBefore = Calendar.getInstance().apply {
            time = expiryDate
            add(Calendar.DAY_OF_YEAR, -1)
            set(Calendar.HOUR_OF_DAY, 9)
            set(Calendar.MINUTE, 0)
        }

        if (oneDayBefore.timeInMillis > System.currentTimeMillis()) {
            scheduleNotification(
                context, 
                alarmManager, 
                productName, 
                "Vence mañana", 
                (productName + "1").hashCode(), 
                oneDayBefore.timeInMillis
            )
        }
    }

    private fun scheduleNotification(
        context: Context,
        alarmManager: AlarmManager,
        productName: String,
        message: String,
        notificationId: Int,
        timeInMillis: Long
    ) {
        val intent = Intent(context, NotificationReceiver::class.java).apply {
            putExtra("productName", productName)
            putExtra("message", message)
            putExtra("notificationId", notificationId)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        timeInMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        timeInMillis,
                        pendingIntent
                    )
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    timeInMillis,
                    pendingIntent
                )
            }
        } catch (e: SecurityException) {
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                timeInMillis,
                pendingIntent
            )
        }
    }

    fun sendTestNotification(context: Context) {
        val intent = Intent(context, NotificationReceiver::class.java).apply {
            putExtra("productName", "Prueba de Zentory")
            putExtra("message", "¡Las notificaciones están funcionando correctamente! 🎉")
            putExtra("notificationId", 999)
        }
        context.sendBroadcast(intent)
    }

    fun cancelProductNotifications(context: Context, productName: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val ids = listOf((productName + "3").hashCode(), (productName + "1").hashCode())
        
        ids.forEach { id ->
            val intent = Intent(context, NotificationReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }
    }
}
