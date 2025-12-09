package com.estuaire.attendance_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class NotificationActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            "ACTION_PRESENCE_YES" -> {
                val incidentId = intent.getIntExtra("incident_id", -1)
                val notificationId = intent.getIntExtra("notification_id", -1)

                if (incidentId != -1) {
                    // Annuler la notification
                    val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.cancel(notificationId)

                    // Envoyer la réponse au backend
                    sendPresenceConfirmation(context, incidentId)
                }
            }
        }
    }

    private fun sendPresenceConfirmation(context: Context, incidentId: Int) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Récupérer le token d'authentification depuis SharedPreferences
                val sharedPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val token = sharedPrefs.getString("flutter.auth_token", null)
                val apiUrl = sharedPrefs.getString("flutter.api_url", "http://10.0.2.2:8000")

                if (token != null) {
                    val url = URL("$apiUrl/api/presence-checks/$incidentId/respond")
                    val connection = url.openConnection() as HttpURLConnection

                    connection.requestMethod = "POST"
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.setRequestProperty("Authorization", "Bearer $token")
                    connection.doOutput = true

                    // Données à envoyer (latitude et longitude à 0 pour l'instant)
                    val jsonBody = JSONObject().apply {
                        put("latitude", 0.0)
                        put("longitude", 0.0)
                        put("confirmed_from_notification", true)
                    }

                    connection.outputStream.use { os ->
                        os.write(jsonBody.toString().toByteArray())
                    }

                    val responseCode = connection.responseCode
                    if (responseCode == HttpURLConnection.HTTP_OK) {
                        android.util.Log.d("NotificationAction", "Présence confirmée avec succès")

                        // Afficher une notification de confirmation
                        showConfirmationNotification(context, true)
                    } else {
                        android.util.Log.e("NotificationAction", "Erreur: $responseCode")
                        showConfirmationNotification(context, false)
                    }

                    connection.disconnect()
                }
            } catch (e: Exception) {
                android.util.Log.e("NotificationAction", "Erreur lors de la confirmation: ${e.message}")
                showConfirmationNotification(context, false)
            }
        }
    }

    private fun showConfirmationNotification(context: Context, success: Boolean) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val builder = android.app.Notification.Builder(context, "attendance_channel")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(if (success) "Confirmé" else "Erreur")
            .setContentText(if (success) "Votre présence a été confirmée" else "Impossible de confirmer votre présence")
            .setAutoCancel(true)

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            builder.setChannelId("attendance_channel")
        }

        notificationManager.notify(System.currentTimeMillis().toInt(), builder.build())
    }
}
