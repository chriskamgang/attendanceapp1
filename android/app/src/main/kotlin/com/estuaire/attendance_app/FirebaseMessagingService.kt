package com.estuaire.attendance_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONObject

class FirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "FCMService"
        private const val CHANNEL_ID_ATTENDANCE = "attendance_channel"
        private const val CHANNEL_ID_PRESENCE = "presence_check_channel"
        private const val CHANNEL_ID_GENERAL = "general_channel"
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        // Vérifier si le message contient des données
        if (remoteMessage.data.isNotEmpty()) {
            handleDataMessage(remoteMessage.data)
        }

        // Vérifier si le message contient une notification
        remoteMessage.notification?.let {
            sendNotification(
                title = it.title ?: "Notification",
                body = it.body ?: "",
                data = remoteMessage.data
            )
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Le token sera envoyé au backend par le service Dart
        android.util.Log.d(TAG, "New FCM token: $token")
    }

    private fun handleDataMessage(data: Map<String, String>) {
        val type = data["type"] ?: return

        when (type) {
            "presence_check" -> {
                sendPresenceCheckNotification(data)
            }
            "scan_available" -> {
                sendScanAvailableNotification(data)
            }
            "attendance_reminder" -> {
                sendAttendanceReminderNotification(data)
            }
            else -> {
                sendNotification(
                    title = data["title"] ?: "Notification",
                    body = data["body"] ?: "",
                    data = data
                )
            }
        }
    }

    private fun sendPresenceCheckNotification(data: Map<String, String>) {
        val incidentId = data["incident_id"]?.toIntOrNull() ?: return
        val campusName = data["campus_name"] ?: "campus"

        createNotificationChannel(CHANNEL_ID_PRESENCE, "Vérification de Présence", NotificationManager.IMPORTANCE_HIGH)

        // Intent pour répondre "OUI"
        val yesIntent = Intent(this, NotificationActionReceiver::class.java).apply {
            action = "ACTION_PRESENCE_YES"
            putExtra("incident_id", incidentId)
            putExtra("notification_id", incidentId)
        }
        val yesPendingIntent = PendingIntent.getBroadcast(
            this,
            incidentId,
            yesIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Intent pour ouvrir l'app
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_data", JSONObject(data as Map<*, *>).toString())
        }
        val openPendingIntent = PendingIntent.getActivity(
            this,
            incidentId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID_PRESENCE)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Confirmation de présence")
            .setContentText("Êtes-vous toujours en place au $campusName ?")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("Êtes-vous toujours en place au $campusName ?\n\nVeuillez confirmer votre présence maintenant."))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .setContentIntent(openPendingIntent)
            .addAction(R.drawable.ic_check, "OUI, je suis en place", yesPendingIntent)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(incidentId, notificationBuilder.build())
    }

    private fun sendScanAvailableNotification(data: Map<String, String>) {
        val title = data["title"] ?: "Scanner disponible"
        val body = data["body"] ?: "Vous pouvez maintenant scanner votre QR code"

        createNotificationChannel(CHANNEL_ID_ATTENDANCE, "Notifications de pointage", NotificationManager.IMPORTANCE_DEFAULT)

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_data", JSONObject(data as Map<*, *>).toString())
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID_ATTENDANCE)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(System.currentTimeMillis().toInt(), notificationBuilder.build())
    }

    private fun sendAttendanceReminderNotification(data: Map<String, String>) {
        val title = data["title"] ?: "Rappel de pointage"
        val body = data["body"] ?: "N'oubliez pas de pointer votre présence"

        sendNotification(title, body, data, CHANNEL_ID_ATTENDANCE)
    }

    private fun sendNotification(
        title: String,
        body: String,
        data: Map<String, String>,
        channelId: String = CHANNEL_ID_GENERAL
    ) {
        createNotificationChannel(channelId, "Notifications générales", NotificationManager.IMPORTANCE_DEFAULT)

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_data", JSONObject(data as Map<*, *>).toString())
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(System.currentTimeMillis().toInt(), notificationBuilder.build())
    }

    private fun createNotificationChannel(channelId: String, channelName: String, importance: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = when (channelId) {
                    CHANNEL_ID_ATTENDANCE -> "Notifications de pointage et présence"
                    CHANNEL_ID_PRESENCE -> "Vérifications de présence urgentes"
                    else -> "Notifications générales de l'application"
                }
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}
