import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription? _linkSubscription;
  Function(DeepLinkData)? _onDeepLinkReceived;

  /// Initialiser le service de deep links
  Future<void> initialize({required Function(DeepLinkData) onDeepLinkReceived}) async {
    _onDeepLinkReceived = onDeepLinkReceived;

    // Gérer le deep link initial (quand l'app était fermée)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        print('📲 Initial deep link: $initialUri');
        _handleDeepLinkUri(initialUri);
      }
    } on PlatformException catch (e) {
      print('❌ Erreur initial link: $e');
    }

    // Écouter les nouveaux deep links (quand l'app est ouverte)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        print('📲 Deep link reçu: $uri');
        _handleDeepLinkUri(uri);
      },
      onError: (err) {
        print('❌ Erreur deep link stream: $err');
      },
    );
  }

  /// Parser et gérer un deep link URI
  void _handleDeepLinkUri(Uri uri) {
    try {
      print('🔍 Parsing deep link: ${uri.scheme}://${uri.host}${uri.path}');

      // Format attendu: attendanceapp://checkin?campus_id=123&geofence_notification_id=456
      if (uri.host == 'checkin' || uri.path == '/checkin') {
        final campusId = uri.queryParameters['campus_id'];
        final geofenceNotificationId = uri.queryParameters['geofence_notification_id'];

        if (campusId != null) {
          final data = DeepLinkData(
            type: DeepLinkType.quickCheckin,
            campusId: int.tryParse(campusId),
            geofenceNotificationId: geofenceNotificationId != null
                ? int.tryParse(geofenceNotificationId)
                : null,
          );

          print('✅ Deep link parsé: campus_id=${data.campusId}, notification_id=${data.geofenceNotificationId}');

          if (_onDeepLinkReceived != null) {
            _onDeepLinkReceived!(data);
          }
        }
      }
    } catch (e) {
      print('❌ Erreur parsing deep link: $e');
    }
  }

  /// Dispose
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}

/// Type de deep link
enum DeepLinkType {
  quickCheckin,
  other,
}

/// Données d'un deep link
class DeepLinkData {
  final DeepLinkType type;
  final int? campusId;
  final int? geofenceNotificationId;

  DeepLinkData({
    required this.type,
    this.campusId,
    this.geofenceNotificationId,
  });
}
