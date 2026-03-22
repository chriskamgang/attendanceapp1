import 'package:geofence_service/geofence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campus.dart';
import '../services/api_service.dart';
import '../services/firebase_notification_service.dart';

class GeofencingService {
  static final GeofencingService _instance = GeofencingService._internal();
  factory GeofencingService() => _instance;
  GeofencingService._internal();

  final GeofenceService _geofenceService = GeofenceService.instance.setup(
    interval: 5000, // 5 secondes
    accuracy: 100, // 100 mètres
    loiteringDelayMs: 60000, // 1 minute de délai avant de déclencher
    statusChangeDelayMs: 10000, // 10 secondes
    useActivityRecognition: false, // Désactivé pour iOS simulator
    allowMockLocations: true, // Activé pour permettre le test sur simulateur
    printDevLog: true,
    geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
  );

  final List<Geofence> _geofences = [];
  final ApiService _apiService = ApiService();
  bool _isInitialized = false;
  bool _isEnabled = true;
  List<Campus> _campuses = [];

  /// Initialiser le service de géofencing
  Future<void> initialize(List<Campus> campuses) async {
    try {
      print('🔧 Initialisation du géofencing...');

      // Vérifier si le géofencing est activé côté serveur
      final status = await _apiService.getGeofencingStatus();
      if (status['success'] == true) {
        _isEnabled = status['data']['enabled'] ?? true;
      }

      if (!_isEnabled) {
        print('⚠️ Géofencing désactivé côté serveur');
        return;
      }

      // Sauvegarder la liste des campuses
      _campuses = campuses;

      // Créer les geofences pour chaque campus
      _geofences.clear();
      for (final campus in campuses) {
        final geofence = Geofence(
          id: 'campus_${campus.id}',
          latitude: campus.latitude,
          longitude: campus.longitude,
          radius: [
            GeofenceRadius(id: 'radius_${campus.id}', length: campus.radius.toDouble()),
          ],
        );
        _geofences.add(geofence);
        print('📍 Geofence créé pour ${campus.name} (${campus.radius}m)');
      }

      // Ajouter les listeners avant de démarrer
      _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
      _geofenceService.addLocationChangeListener(_onLocationChanged);
      _geofenceService.addActivityChangeListener(_onActivityChanged);
      _geofenceService.addStreamErrorListener(_onStreamError);

      // Démarrer le service avec les geofences
      await _geofenceService.start(_geofences);

      _isInitialized = true;
      print('✅ Géofencing initialisé avec ${_geofences.length} zones');
    } catch (e) {
      print('❌ Erreur initialisation géofencing: $e');
    }
  }

  /// Callback appelé quand le statut d'une geofence change
  Future<void> _onGeofenceStatusChanged(
    Geofence geofence,
    GeofenceRadius geofenceRadius,
    GeofenceStatus geofenceStatus,
    Location location,
  ) async {
    print('📡 Geofence Status Changed: ${geofence.id}');
    print('   Status: $geofenceStatus');
    print('   Location: (${location.latitude}, ${location.longitude})');

    // Gérer les événements ENTER et DWELL (DWELL = déjà dans la zone au démarrage)
    if (geofenceStatus == GeofenceStatus.ENTER || geofenceStatus == GeofenceStatus.DWELL) {
      final campusId = _extractCampusIdFromGeofenceId(geofence.id);
      final campus = _campuses.firstWhere(
        (c) => c.id == campusId,
        orElse: () => _campuses.first,
      );

      final statusLabel = geofenceStatus == GeofenceStatus.ENTER ? 'Entrée' : 'Présence';
      print('🚶 $statusLabel détectée dans ${campus.name}');
      await _handleGeofenceEntry(campus);
    }
  }

  /// Callback appelé quand la localisation change
  void _onLocationChanged(Location location) {
    print('📍 Location changed: (${location.latitude}, ${location.longitude})');
  }

  /// Callback appelé quand l'activité change
  void _onActivityChanged(Activity prevActivity, Activity currActivity) {
    print('🏃 Activity changed: $prevActivity → $currActivity');
  }

  /// Callback appelé en cas d'erreur dans le stream
  void _onStreamError(error) {
    print('❌ Geofence stream error: $error');
  }

  /// Extraire l'ID du campus depuis l'ID du geofence
  int _extractCampusIdFromGeofenceId(String geofenceId) {
    // geofenceId format: "campus_123"
    return int.parse(geofenceId.split('_')[1]);
  }

  /// Gérer l'entrée dans une zone (afficher notification de check-in)
  Future<void> _handleGeofenceEntry(Campus campus) async {
    try {
      // Vérifier le cooldown local (ne pas spammer)
      if (await _isInCooldown(campus.id)) {
        print('⏰ Cooldown actif pour ${campus.name}');
        return;
      }

      // Afficher une notification locale pour inviter au check-in
      final notificationService = FirebaseNotificationService();
      await notificationService.showCheckInAvailableNotification(
        campusName: campus.name,
        campusId: campus.id,
      );

      print('✅ Notification check-in disponible affichée pour ${campus.name}');

      // Sauvegarder le timestamp local
      await _saveCooldownTimestamp(campus.id);

      // Notifier aussi le backend
      try {
        await _apiService.sendGeofenceEntry(campus.id);
      } catch (e) {
        print('⚠️ Erreur envoi geofence au backend: $e');
      }
    } catch (e) {
      print('❌ Erreur handleGeofenceEntry: $e');
    }
  }

  /// Vérifier si on est en cooldown pour un campus (1 notification par jour par campus)
  Future<bool> _isInCooldown(int campusId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'geofence_cooldown_campus_${campusId}_$today';
    final alreadySent = prefs.getBool(key) ?? false;

    if (alreadySent) {
      print('⏰ Notification déjà envoyée aujourd\'hui pour campus $campusId');
    }

    return alreadySent;
  }

  /// Sauvegarder le cooldown (1 par jour par campus)
  Future<void> _saveCooldownTimestamp(int campusId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'geofence_cooldown_campus_${campusId}_$today';
    await prefs.setBool(key, true);
  }

  /// Mettre à jour les geofences quand les campus changent
  Future<void> updateGeofences(List<Campus> campuses) async {
    if (!_isEnabled) return;

    print('🔄 Mise à jour des geofences...');
    await stop();
    await initialize(campuses);
  }

  /// Arrêter le géofencing
  Future<void> stop() async {
    // Retirer les listeners
    _geofenceService.removeGeofenceStatusChangeListener(_onGeofenceStatusChanged);

    // Arrêter le service
    await _geofenceService.stop();

    _isInitialized = false;
    print('⏹️ Géofencing arrêté');
  }

  /// Vérifier si le géofencing est initialisé
  bool get isInitialized => _isInitialized;

  /// Vérifier si le géofencing est activé
  bool get isEnabled => _isEnabled;

  /// Obtenir la liste des geofences
  List<Geofence> get geofences => _geofences;
}
