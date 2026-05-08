import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../models/campus.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/offline_queue_service.dart';

class AttendanceProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final OfflineQueueService _offlineQueue = OfflineQueueService();

  bool _isLoading = false;
  bool _hasActiveCheckIn = false;
  List<Attendance> _activeCheckIns = [];
  List<Attendance> _todayAttendances = [];

  bool get isLoading => _isLoading;
  bool get hasActiveCheckIn => _hasActiveCheckIn;
  List<Attendance> get activeCheckIns => _activeCheckIns;
  List<Attendance> get todayAttendances => _todayAttendances;
  bool get isOnline => _offlineQueue.isOnline;
  OfflineQueueService get offlineQueue => _offlineQueue;

  // Vérifier le statut actuel
  Future<void> checkCurrentStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.getCurrentStatus();
      if (result['success']) {
        _hasActiveCheckIn = result['has_active_checkin'];
        _activeCheckIns = result['active_checkins'];
      }
    } catch (e) {
      print('Erreur checkCurrentStatus: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Check-in
  Future<Map<String, dynamic>> checkIn(Campus campus, {int? uniteEnseignementId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Obtenir la position (GPS fonctionne sans internet)
      var position = await _locationService.getCurrentPosition();
      if (position == null) {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'Impossible d\'obtenir votre position'
        };
      }

      // Vérifier si dans la zone (avec tolérance GPS)
      bool inZone = _locationService.isInZone(
        userLat: position.latitude,
        userLon: position.longitude,
        zoneLat: campus.latitude,
        zoneLon: campus.longitude,
        radius: campus.radius.toDouble(),
        accuracy: position.accuracy,
      );

      if (!inZone) {
        double distance = _locationService.calculateDistance(
          position.latitude, position.longitude,
          campus.latitude, campus.longitude,
        );
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message':
              'Vous êtes à ${distance.round()}m du campus (rayon: ${campus.radius}m, précision GPS: ${position.accuracy.round()}m). Essayez de vous déplacer ou redémarrez le GPS.'
        };
      }

      // Si hors-ligne, sauvegarder localement
      if (!_offlineQueue.isOnline) {
        await _offlineQueue.queueCheckIn(
          campusId: campus.id,
          campusName: campus.name,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          uniteEnseignementId: uniteEnseignementId,
        );

        _isLoading = false;
        notifyListeners();
        return {
          'success': true,
          'message': 'Check-in enregistré hors-ligne. Il sera synchronisé automatiquement.',
          'offline': true,
        };
      }

      // En ligne : effectuer le check-in normalement
      final result = await _apiService.checkIn(
        campusId: campus.id,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        uniteEnseignementId: uniteEnseignementId,
      );

      if (result['success']) {
        await Future.wait([checkCurrentStatus(), getTodayAttendances()]);
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // Check-out
  Future<Map<String, dynamic>> checkOut(Campus campus) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Obtenir la position
      var position = await _locationService.getCurrentPosition();
      if (position == null) {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'Impossible d\'obtenir votre position'
        };
      }

      // Si hors-ligne, sauvegarder localement
      if (!_offlineQueue.isOnline) {
        await _offlineQueue.queueCheckOut(
          campusId: campus.id,
          campusName: campus.name,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        );

        _isLoading = false;
        notifyListeners();
        return {
          'success': true,
          'message': 'Check-out enregistré hors-ligne. Il sera synchronisé automatiquement.',
          'offline': true,
        };
      }

      // En ligne : effectuer le check-out normalement
      final result = await _apiService.checkOut(
        campusId: campus.id,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );

      if (result['success']) {
        await Future.wait([checkCurrentStatus(), getTodayAttendances()]);
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // Synchroniser manuellement
  Future<Map<String, dynamic>> syncOfflineActions() async {
    final result = await _offlineQueue.syncPendingActions();
    if (result['synced'] != null && result['synced'] > 0) {
      await Future.wait([checkCurrentStatus(), getTodayAttendances()]);
    }
    notifyListeners();
    return result;
  }

  // Obtenir les pointages d'aujourd'hui
  Future<void> getTodayAttendances() async {
    try {
      final result = await _apiService.getAttendanceToday();
      if (result['success']) {
        _todayAttendances = (result['data']['all_attendances'] as List)
            .map((a) => Attendance.fromJson(a))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Erreur getTodayAttendances: $e');
    }
  }
}
