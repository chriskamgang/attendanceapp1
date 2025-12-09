import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'location_service.dart';
import 'storage_service.dart';
import '../utils/constants.dart';

/// Service de suivi de localisation en temps réel
/// Envoie la position de l'utilisateur au serveur toutes les 45 secondes
/// pour permettre le suivi en temps réel sur le dashboard admin
class LocationTrackingService {
  static Timer? _locationTimer;
  static const Duration UPDATE_INTERVAL = Duration(seconds: 45);
  static bool _isTracking = false;

  static final LocationService _locationService = LocationService();
  static final StorageService _storageService = StorageService();

  /// Démarrer le suivi de localisation
  static Future<void> startTracking() async {
    if (_isTracking) {
      print('⚠️  Le suivi de localisation est déjà actif');
      return;
    }

    // Vérifier les permissions
    bool hasPermission = await _locationService.checkPermission();
    if (!hasPermission) {
      hasPermission = await _locationService.requestPermission();
      if (!hasPermission) {
        print('❌ Permission de localisation refusée');
        return;
      }
    }

    // Vérifier que le service de localisation est activé
    bool serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ Le service de localisation est désactivé');
      return;
    }

    _isTracking = true;
    print('✓ Démarrage du suivi de localisation (toutes les ${UPDATE_INTERVAL.inSeconds}s)');

    // Envoyer la position immédiatement au démarrage
    await _sendCurrentLocation();

    // Puis envoyer périodiquement
    _locationTimer = Timer.periodic(UPDATE_INTERVAL, (timer) async {
      await _sendCurrentLocation();
    });
  }

  /// Arrêter le suivi de localisation
  static Future<void> stopTracking() async {
    if (!_isTracking) {
      return;
    }

    _isTracking = false;
    _locationTimer?.cancel();
    _locationTimer = null;

    // Marquer l'utilisateur comme inactif sur le serveur
    await _deactivateLocation();

    print('✓ Suivi de localisation arrêté');
  }

  /// Envoyer la position actuelle au serveur
  static Future<void> _sendCurrentLocation() async {
    try {
      // Récupérer la position actuelle
      Position? position = await _locationService.getCurrentPosition();
      if (position == null) {
        print('❌ Impossible de récupérer la position');
        return;
      }

      // Vérifier que l'utilisateur est connecté
      final token = await _storageService.getToken();
      if (token == null) {
        print('❌ Utilisateur non connecté - arrêt du tracking');
        await stopTracking();
        return;
      }

      // Envoyer la position au serveur
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/location/update'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'device_info': 'Flutter App',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✓ Position envoyée: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');

          // Afficher si l'utilisateur est dans un campus
          final inCampus = data['data']?['in_campus'];
          if (inCampus != null) {
            print('  → Dans le campus: ${inCampus['name']}');
          } else {
            print('  → Hors zone campus');
          }
        }
      } else {
        print('❌ Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'envoi de la position: $e');
    }
  }

  /// Marquer l'utilisateur comme inactif sur le serveur
  static Future<void> _deactivateLocation() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) return;

      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/location/deactivate'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      print('✓ Position désactivée sur le serveur');
    } catch (e) {
      print('❌ Erreur lors de la désactivation: $e');
    }
  }

  /// Vérifier si le suivi est actif
  static bool isTracking() => _isTracking;

  /// Forcer l'envoi immédiat de la position (utile pour le debug)
  static Future<void> sendNow() async {
    if (_isTracking) {
      await _sendCurrentLocation();
    } else {
      print('⚠️  Le tracking n\'est pas actif. Démarrez-le d\'abord avec startTracking()');
    }
  }

  /// Changer l'intervalle de mise à jour (en secondes)
  /// Note: Nécessite de redémarrer le tracking pour prendre effet
  static void setUpdateInterval(int seconds) {
    // Cette fonction pourrait être améliorée pour permettre
    // de changer l'intervalle dynamiquement
    print('⚠️  Pour changer l\'intervalle, modifiez UPDATE_INTERVAL et redémarrez l\'app');
  }
}
