import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Obtenir la position actuelle - rapide, utilise le cache si récent
  Future<Position?> getCurrentPosition({bool forceRefresh = false}) async {
    try {
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Le service de localisation est désactivé');
      }

      bool hasPermission = await checkPermission();
      if (!hasPermission) {
        hasPermission = await requestPermission();
        if (!hasPermission) {
          throw Exception('Permission de localisation refusée');
        }
      }

      // D'abord essayer la position en cache (instantané)
      if (!forceRefresh) {
        try {
          final cached = await Geolocator.getLastKnownPosition();
          if (cached != null) {
            final age = DateTime.now().difference(cached.timestamp).inSeconds;
            if (age <= 30 && cached.accuracy <= 100) {
              print('GPS CACHE: ${cached.latitude}, ${cached.longitude} (précision: ${cached.accuracy}m, age: ${age}s)');
              return cached;
            }
          }
        } catch (_) {}
      }

      // Méthode rapide : getCurrentPosition direct avec timeout court
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        print('GPS DIRECT: ${pos.latitude}, ${pos.longitude} (précision: ${pos.accuracy}m)');
        return pos;
      } catch (e) {
        print('GPS direct échoué: $e');
      }

      // Fallback : Stream GPS hardware (plus fiable mais plus lent)
      Position? freshPosition = await _getHardwareGPSPosition();
      if (freshPosition != null) {
        print('GPS HARDWARE: ${freshPosition.latitude}, ${freshPosition.longitude} (précision: ${freshPosition.accuracy}m)');
        return freshPosition;
      }

      // Dernier recours : position en cache même ancienne
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {}

      return null;
    } catch (e) {
      print('Erreur GPS: $e');
      return null;
    }
  }

  /// Vérifier si une position est fraîche (différente du cache)
  bool _isPositionFresh(Position position, Position? cached) {
    final age = DateTime.now().difference(position.timestamp).inSeconds;
    // Position récente (< 10s) = fraîche
    if (age <= 10) return true;
    // Si pas de cache à comparer, accepter si < 30s
    if (cached == null) return age <= 30;
    // Si différente du cache (> 10m de différence), c'est une nouvelle position
    final distance = Geolocator.distanceBetween(
      position.latitude, position.longitude,
      cached.latitude, cached.longitude,
    );
    return distance > 10;
  }

  /// Forcer le GPS hardware Android (bypass Fused Location Provider)
  Future<Position?> _getHardwareGPSPosition() async {
    try {
      final completer = Completer<Position?>();
      Position? bestPosition;
      int count = 0;

      final LocationSettings settings;
      if (Platform.isAndroid) {
        settings = AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          forceLocationManager: true, // CLÉ : bypass le cache Google
          intervalDuration: const Duration(seconds: 1),
        );
      } else {
        settings = const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        );
      }

      StreamSubscription<Position>? sub;
      sub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
        count++;
        final age = DateTime.now().difference(pos.timestamp).inSeconds;
        print('GPS HW #$count: ${pos.latitude}, ${pos.longitude} (précision: ${pos.accuracy}m, age: ${age}s)');

        if (age > 10) return; // Ignorer les vieilles positions

        if (bestPosition == null || pos.accuracy < bestPosition!.accuracy) {
          bestPosition = pos;
        }

        // Bonne précision ou 4 positions reçues -> terminé
        if (pos.accuracy <= 30 || count >= 4) {
          if (!completer.isCompleted) completer.complete(bestPosition);
        }
      }, onError: (e) {
        print('Erreur GPS HW stream: $e');
        if (!completer.isCompleted) completer.complete(null);
      });

      // Timeout 6 secondes
      Future.delayed(const Duration(seconds: 6), () {
        if (!completer.isCompleted) completer.complete(bestPosition);
      });

      final result = await completer.future;
      await sub.cancel();
      return result;
    } catch (e) {
      print('Erreur GPS hardware: $e');
      return null;
    }
  }

  /// Stream GPS via Fused Location Provider (fallback)
  Future<Position?> _getStreamGPSPosition() async {
    try {
      final completer = Completer<Position?>();
      Position? bestPosition;
      int count = 0;

      const settings = LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      );

      StreamSubscription<Position>? sub;
      sub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
        count++;
        final age = DateTime.now().difference(pos.timestamp).inSeconds;
        print('GPS FUSED #$count: ${pos.latitude}, ${pos.longitude} (précision: ${pos.accuracy}m, age: ${age}s)');

        if (age > 10) return;

        if (bestPosition == null || pos.accuracy < bestPosition!.accuracy) {
          bestPosition = pos;
        }

        if (pos.accuracy <= 30 || count >= 3) {
          if (!completer.isCompleted) completer.complete(bestPosition);
        }
      }, onError: (e) {
        if (!completer.isCompleted) completer.complete(null);
      });

      Future.delayed(const Duration(seconds: 8), () {
        if (!completer.isCompleted) completer.complete(bestPosition);
      });

      final result = await completer.future;
      await sub.cancel();
      return result;
    } catch (e) {
      print('Erreur GPS fused stream: $e');
      return null;
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  bool isInZone({
    required double userLat,
    required double userLon,
    required double zoneLat,
    required double zoneLon,
    required double radius,
    double accuracy = 0,
  }) {
    double distance = calculateDistance(userLat, userLon, zoneLat, zoneLon);
    double tolerance = accuracy > 50 ? accuracy : 50;
    if (tolerance > 500) tolerance = 500;
    return distance <= (radius + tolerance);
  }

  Stream<Position> getPositionStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
