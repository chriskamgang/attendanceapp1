import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'api_service.dart';

/// Service de gestion des notifications Firebase
class FirebaseNotificationService {
  static final FirebaseNotificationService _instance =
      FirebaseNotificationService._internal();

  factory FirebaseNotificationService() => _instance;

  FirebaseNotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  FirebaseMessaging get firebaseMessaging {
    _firebaseMessaging ??= FirebaseMessaging.instance;
    return _firebaseMessaging!;
  }

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  Function(Map<String, dynamic>)? onPresenceCheckReceived;
  Function(Map<String, dynamic>)? onGeofenceEntryTapped;

  /// Initialiser Firebase et les notifications
  Future<void> initialize() async {
    await Firebase.initializeApp();

    // Demander les permissions
    await _requestPermissions();

    // Configurer les notifications locales
    await _setupLocalNotifications();

    // Récupérer le token FCM
    await _getFCMToken();

    // Configurer les handlers
    _setupMessageHandlers();

    print('✓ Firebase Notification Service initialized');
  }

  /// Demander les permissions de notifications
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✓ Notification permissions granted');
    } else {
      print('⚠ Notification permissions denied');
    }
  }

  /// Configurer les notifications locales
  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Récupérer le token FCM
  Future<void> _getFCMToken() async {
    try {
      // Sur iOS, attendre que le token APNS soit disponible
      String? apnsToken = await firebaseMessaging.getAPNSToken();
      if (apnsToken == null) {
        print('⏳ APNS token not ready, waiting...');
        // Attendre et réessayer jusqu'à 3 fois
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await firebaseMessaging.getAPNSToken();
          if (apnsToken != null) {
            print('✓ APNS token received after ${(i + 1) * 3}s');
            break;
          }
        }
      }

      _fcmToken = await firebaseMessaging.getToken();
      print('FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        // Envoyer le token au backend
        await _sendTokenToBackend(_fcmToken!);
      }

      // Écouter les changements de token
      firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _sendTokenToBackend(newToken);
      });
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  /// Envoyer le token au backend (seulement si connecté)
  Future<void> _sendTokenToBackend(String token) async {
    try {
      final storageService = StorageService();
      final authToken = await storageService.getToken();
      if (authToken == null || authToken.isEmpty) {
        print('⏳ FCM token not sent: user not logged in yet');
        return;
      }
      final apiService = ApiService();
      await apiService.updateFcmToken(token);
      print('✓ FCM token sent to backend');
    } catch (e) {
      print('Error sending FCM token to backend: $e');
    }
  }

  /// Forcer le renvoi du token FCM au backend (à appeler après login)
  Future<void> resendTokenToBackend() async {
    if (_fcmToken != null) {
      await _sendTokenToBackend(_fcmToken!);
    } else {
      // Token null — réessayer de l'obtenir (important pour iOS)
      await _getFCMToken();
    }

    // Si toujours null après _getFCMToken (iOS peut être lent), retry en arrière-plan
    if (_fcmToken == null) {
      Future.delayed(const Duration(seconds: 5), () async {
        try {
          final token = await firebaseMessaging.getToken();
          if (token != null) {
            _fcmToken = token;
            print('✓ FCM token obtained on delayed retry: $token');
            await _sendTokenToBackend(token);
          }
        } catch (e) {
          print('Error on delayed FCM token retry: $e');
        }
      });
    }
  }

  /// Configurer les handlers de messages
  void _setupMessageHandlers() {
    // Notification reçue en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Notification tapée (app en background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Background handler (défini au niveau global)
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Vérifier si l'app a été ouverte depuis une notification
    _checkInitialMessage();
  }

  /// Handler pour les messages en foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      // Afficher une notification locale
      await _showLocalNotification(
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        payload: jsonEncode(data),
      );
    }

    // Gérer les données
    _handleNotificationData(data);
  }

  /// Handler pour le tap sur notification
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.messageId}');
    _handleNotificationData(message.data);
  }

  /// Vérifier si l'app a été lancée depuis une notification
  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Gérer les données de la notification
  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'presence_check':
        // Notification "Êtes-vous en place?"
        if (onPresenceCheckReceived != null) {
          onPresenceCheckReceived!(data);
        }
        break;

      case 'geofence_entry':
        // Notification "Vous êtes dans la zone"
        print('📍 Notification géofencing reçue: ${data['campus_name']}');
        print('🔔 Action disponible: ${data['action']}');

        // Rediriger vers l'écran de check-in
        if (onGeofenceEntryTapped != null) {
          onGeofenceEntryTapped!(data);
        }
        break;

      case 'scan_available':
        // Notification "Vous pouvez scanner"
        // Naviguer vers l'écran de check-in
        break;

      default:
        print('Unknown notification type: $type');
    }
  }

  /// Afficher une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'attendance_channel',
      'Attendance Notifications',
      channelDescription: 'Notifications de pointage et présence',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Afficher une notification avec bouton d'action
  Future<void> showPresenceCheckNotification({
    required int incidentId,
    required String campusName,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'presence_check_channel',
      'Vérification de Présence',
      channelDescription: 'Notifications de vérification de présence',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'respond_yes',
          'OUI, je suis en place',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      incidentId,
      'Confirmation de présence',
      'Êtes-vous toujours en place au $campusName ?',
      notificationDetails,
      payload: jsonEncode({
        'type': 'presence_check',
        'incident_id': incidentId,
        'campus_name': campusName,
      }),
    );
  }

  /// Afficher une notification "Check-in disponible" quand l'employé entre dans la zone
  Future<void> showCheckInAvailableNotification({
    required String campusName,
    required int campusId,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'checkin_available_channel',
      'Check-in Disponible',
      channelDescription: 'Notifications quand vous êtes dans la zone de check-in',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      campusId + 10000, // ID unique basé sur le campus
      'Pointage disponible',
      'Vous êtes à $campusName. Vous pouvez faire votre check-in maintenant !',
      notificationDetails,
      payload: jsonEncode({
        'type': 'geofence_entry',
        'campus_id': campusId,
        'campus_name': campusName,
        'action': 'check_in',
      }),
    );
  }

  /// Planifier une notification pour plus tard
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    Map<String, dynamic>? data,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'scheduled_channel',
      'Notifications Planifiées',
      channelDescription: 'Notifications planifiées et rappels',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Note: flutter_local_notifications ne supporte pas directement les scheduled notifications
    // Il faudrait utiliser un package comme awesome_notifications ou workmanager
    print('Scheduled notification for $scheduledDate: $title');
  }

  /// Annuler une notification spécifique
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Annuler toutes les notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Obtenir le nombre de notifications actives
  Future<int> getActiveNotificationCount() async {
    final List<dynamic> activeNotifications =
        await _localNotifications.getActiveNotifications();
    return activeNotifications.length;
  }

  /// Configurer les badges (iOS principalement)
  Future<void> setBadgeCount(int count) async {
    // iOS seulement - Android gère automatiquement
    print('Badge count set to: $count');
  }

  /// Callback quand une notification est tapée
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);

      // Si c'est une réponse au bouton "OUI"
      if (response.actionId == 'respond_yes') {
        _respondToPresenceCheck(data);
      } else {
        // Tap sur la notification
        _handleNotificationData(data);
      }
    }
  }

  /// Répondre à une vérification de présence
  Future<void> _respondToPresenceCheck(Map<String, dynamic> data) async {
    try {
      final incidentId = data['incident_id'];
      final apiService = ApiService();

      // Récupérer la position actuelle
      // TODO: Implémenter la géolocalisation
      final double latitude = 0.0; // Remplacer par vraie position
      final double longitude = 0.0;

      final response = await apiService.respondToPresenceCheck(
        incidentId: incidentId,
        latitude: latitude,
        longitude: longitude,
      );

      if (response['success'] == true) {
        print('✓ Présence confirmée avec succès');
        _showLocalNotification(
          title: 'Confirmé',
          body: 'Votre présence a été confirmée avec succès',
        );
      }
    } catch (e) {
      print('Error responding to presence check: $e');
      _showLocalNotification(
        title: 'Erreur',
        body: 'Impossible de confirmer votre présence',
      );
    }
  }

  /// Obtenir le token FCM actuel
  String? get fcmToken => _fcmToken;

  /// Se désinscrire des notifications
  Future<void> unsubscribe() async {
    await firebaseMessaging.deleteToken();
    _fcmToken = null;
  }
}

/// Handler pour les messages en background (doit être top-level)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message received: ${message.messageId}');

  // Afficher une notification locale si nécessaire
  if (message.notification != null) {
    final notificationService = FirebaseNotificationService();
    await notificationService._showLocalNotification(
      title: message.notification!.title ?? 'Notification',
      body: message.notification!.body ?? '',
      payload: jsonEncode(message.data),
    );
  }
}
