import 'package:flutter/material.dart';
import 'firebase_notification_service.dart';

/// Manager centralisé pour gérer tous les types de notifications de l'app
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final FirebaseNotificationService _notificationService =
      FirebaseNotificationService();

  // Callbacks pour différents types de notifications
  Function(Map<String, dynamic>)? onPresenceCheckReceived;
  Function(Map<String, dynamic>)? onScanAvailableReceived;
  Function(Map<String, dynamic>)? onAttendanceReminderReceived;
  Function(Map<String, dynamic>)? onGeneralNotificationReceived;

  /// Initialiser le manager
  Future<void> initialize() async {
    await _notificationService.initialize();

    // Configurer le callback pour les vérifications de présence
    _notificationService.onPresenceCheckReceived = (data) {
      if (onPresenceCheckReceived != null) {
        onPresenceCheckReceived!(data);
      }
    };
  }

  /// Envoyer une notification de vérification de présence
  Future<void> sendPresenceCheck({
    required int incidentId,
    required String campusName,
  }) async {
    await _notificationService.showPresenceCheckNotification(
      incidentId: incidentId,
      campusName: campusName,
    );
  }

  /// Envoyer une notification générale
  Future<void> sendGeneralNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _notificationService._showLocalNotification(
      title: title,
      body: body,
      payload: data != null ? _encodeData(data) : null,
    );
  }

  /// Envoyer une notification de scan disponible
  Future<void> sendScanAvailableNotification({
    required String campusName,
    String? message,
  }) async {
    await _notificationService._showLocalNotification(
      title: 'Scanner disponible',
      body: message ?? 'Vous pouvez maintenant scanner votre QR code au $campusName',
    );
  }

  /// Envoyer une notification de rappel de pointage
  Future<void> sendAttendanceReminder({
    required String courseName,
    required DateTime startTime,
  }) async {
    final timeStr = '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}';
    await _notificationService._showLocalNotification(
      title: 'Rappel de pointage',
      body: 'N\'oubliez pas de pointer pour le cours "$courseName" à $timeStr',
    );
  }

  /// Planifier une notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    Map<String, dynamic>? data,
  }) async {
    await _notificationService.scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      data: data,
    );
  }

  /// Annuler une notification
  Future<void> cancelNotification(int id) async {
    await _notificationService.cancelNotification(id);
  }

  /// Annuler toutes les notifications
  Future<void> cancelAllNotifications() async {
    await _notificationService.cancelAllNotifications();
  }

  /// Obtenir le token FCM
  String? get fcmToken => _notificationService.fcmToken;

  /// Obtenir le nombre de notifications actives
  Future<int> getActiveNotificationCount() async {
    return await _notificationService.getActiveNotificationCount();
  }

  /// Configurer le badge count
  Future<void> setBadgeCount(int count) async {
    await _notificationService.setBadgeCount(count);
  }

  /// Helper pour encoder les données
  String _encodeData(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }
}

/// Widget pour afficher un centre de notifications dans l'app
class NotificationCenterWidget extends StatefulWidget {
  const NotificationCenterWidget({Key? key}) : super(key: key);

  @override
  State<NotificationCenterWidget> createState() =>
      _NotificationCenterWidgetState();
}

class _NotificationCenterWidgetState extends State<NotificationCenterWidget> {
  final List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    // Charger les notifications depuis le stockage local
    // TODO: Implémenter le chargement depuis SharedPreferences ou une base de données locale
    setState(() {
      // Exemple de notifications
      _notifications.addAll([
        NotificationItem(
          id: 1,
          title: 'Vérification de présence',
          body: 'Êtes-vous toujours en place au Campus Nord ?',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          type: NotificationType.presenceCheck,
          isRead: false,
        ),
        NotificationItem(
          id: 2,
          title: 'Scanner disponible',
          body: 'Vous pouvez maintenant scanner votre QR code',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          type: NotificationType.scanAvailable,
          isRead: true,
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearAllNotifications,
            tooltip: 'Tout effacer',
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucune notification',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _buildNotificationItem(notification);
              },
            ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    return Dismissible(
      key: Key(notification.id.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        setState(() {
          _notifications.remove(notification);
        });
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: _getIconForType(notification.type),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(notification.timestamp),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        onTap: () {
          setState(() {
            notification.isRead = true;
          });
          _handleNotificationTap(notification);
        },
        tileColor: notification.isRead ? null : Colors.blue.withOpacity(0.1),
      ),
    );
  }

  Icon _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.presenceCheck:
        return const Icon(Icons.person_pin_circle, color: Colors.orange);
      case NotificationType.scanAvailable:
        return const Icon(Icons.qr_code_scanner, color: Colors.blue);
      case NotificationType.attendanceReminder:
        return const Icon(Icons.alarm, color: Colors.green);
      case NotificationType.general:
        return const Icon(Icons.notifications, color: Colors.grey);
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return 'Il y a ${difference.inDays}j';
    }
  }

  void _handleNotificationTap(NotificationItem notification) {
    // Gérer l'action selon le type de notification
    switch (notification.type) {
      case NotificationType.presenceCheck:
        // Naviguer vers l'écran de confirmation de présence
        break;
      case NotificationType.scanAvailable:
        // Naviguer vers l'écran de scan QR
        break;
      case NotificationType.attendanceReminder:
        // Naviguer vers l'écran de pointage
        break;
      case NotificationType.general:
        // Action générique
        break;
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer toutes les notifications'),
        content: const Text(
            'Voulez-vous vraiment supprimer toutes les notifications ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _notifications.clear();
      });
      await NotificationManager().cancelAllNotifications();
    }
  }
}

/// Modèle de notification
class NotificationItem {
  final int id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  bool isRead;
  final Map<String, dynamic>? data;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.data,
  });
}

/// Types de notifications
enum NotificationType {
  presenceCheck,
  scanAvailable,
  attendanceReminder,
  general,
}
