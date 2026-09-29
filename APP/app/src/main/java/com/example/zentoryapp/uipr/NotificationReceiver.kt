package com.example.zentoryapp.uipr

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import com.example.zentoryapp.MainActivity
import com.example.zentoryapp.R

class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val productName = intent.getStringExtra("productName") ?: "Producto"
        val message = intent.getStringExtra("message") ?: "Está por vencer"
        val notificationId = intent.getIntExtra("notificationId", 0)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Usamos un nuevo ID de canal para asegurar que los cambios de sonido se apliquen
        val channelId = "expiration_notifications_custom_sound"

        // Buscamos el sonido personalizado en res/raw/notification_sound
        val soundResId = context.resources.getIdentifier("notification_sound", "raw", context.packageName)
        val soundUri = if (soundResId != 0) {
            Uri.parse("android.resource://${context.packageName}/$soundResId")
        } else {
            // Sonido por defecto si aún no se ha agregado el archivo
            android.provider.Settings.System.DEFAULT_NOTIFICATION_URI
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Vencimientos de Productos",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificaciones con sonido personalizado"
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build()
                setSound(soundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val activityIntent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.logozentory)
            .setContentTitle("Alerta de Vencimiento")
            .setContentText("$productName: $message")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setSound(soundUri)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(notificationId, notification)
    }
}
