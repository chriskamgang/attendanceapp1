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

  /// Obtenir la position actuelle - FORCE le GPS hardware (pas de cache)
  Future<Position?> getCurrentPosition() async {
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

      // Récupérer la position en cache pour comparer après
      Position? cachedPosition;
      try {
        cachedPosition = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // METHODE 1 : Stream GPS avec forceLocationManager (bypass cache Google)
      Position? freshPosition = await _getHardwareGPSPosition();
      if (freshPosition != null && _isPositionFresh(freshPosition, cachedPosition)) {
        print('GPS HARDWARE: ${freshPosition.latitude}, ${freshPosition.longitude} (précision: ${freshPosition.accuracy}m)');
        return freshPosition;
      }

      // METHODE 2 : Stream GPS normal (Fused Location Provider)
      Position? streamPosition = await _getStreamGPSPosition();
      if (streamPosition != null && _isPositionFresh(streamPosition, cachedPosition)) {
        print('GPS STREAM: ${streamPosition.latitude}, ${streamPosition.longitude} (précision: ${streamPosition.accuracy}m)');
        return streamPosition;
      }

      // METHODE 3 : getCurrentPosition direct
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 15),
          );

          final age = DateTime.now().difference(pos.timestamp).inSeconds;
          print('GPS tentative $attempt: ${pos.latitude}, ${pos.longitude} (précision: ${pos.accuracy}m, age: ${age}s)');

          if (age <= 15 && pos.accuracy <= 100) {
            return pos;
          }

          // Même si pas parfait, garder comme meilleur résultat
          if (freshPosition == null || pos.accuracy < freshPosition.accuracy) {
            freshPosition = pos;
          }
        } catch (e) {
          print('GPS tentative $attempt échouée: $e');
        }
        if (attempt < 3) await Future.delayed(const Duration(seconds: 2));
      }

      // Retourner la meilleure position trouvée, ou la position en cache en dernier recours
      return freshPosition ?? streamPosition ?? cachedPosition;
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

      // Timeout 12 secondes
      Future.delayed(const Duration(seconds: 12), () {
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
