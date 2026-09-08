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

  /// Obtenir la position actuelle avec GPS optimisé
  /// Essaie plusieurs méthodes et retente si la précision est mauvaise
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

      // Méthode rapide : getCurrentPosition direct
      Position? bestPosition;
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        print('GPS DIRECT: ${pos.latitude}, ${pos.longitude} (précision: ${pos.accuracy}m)');
        bestPosition = pos;

        // Si bonne précision, retourner directement
        if (pos.accuracy <= 100) {
          return pos;
        }
      } catch (e) {
        print('GPS direct échoué: $e');
      }

      // GPS Hardware - round 1 (10 secondes, 6 positions max)
      Position? hwPosition = await _getHardwareGPSPosition(
        maxReadings: 6,
        timeoutSeconds: 10,
        targetAccuracy: 50,
      );
      if (hwPosition != null) {
        print('GPS HW R1: ${hwPosition.latitude}, ${hwPosition.longitude} (précision: ${hwPosition.accuracy}m)');
        if (bestPosition == null || hwPosition.accuracy < bestPosition.accuracy) {
          bestPosition = hwPosition;
        }
        if (bestPosition!.accuracy <= 100) {
          return bestPosition;
        }
      }

      // Si précision toujours mauvaise (>200m), round 2 plus long
      if (bestPosition == null || bestPosition.accuracy > 200) {
        print('GPS précision insuffisante (${bestPosition?.accuracy}m), round 2...');
        Position? hwPosition2 = await _getHardwareGPSPosition(
          maxReadings: 10,
          timeoutSeconds: 15,
          targetAccuracy: 100,
        );
        if (hwPosition2 != null) {
          print('GPS HW R2: ${hwPosition2.latitude}, ${hwPosition2.longitude} (précision: ${hwPosition2.accuracy}m)');
          if (bestPosition == null || hwPosition2.accuracy < bestPosition.accuracy) {
            bestPosition = hwPosition2;
          }
        }
      }

      // Si toujours >500m, dernier essai avec Fused Location
      if (bestPosition == null || bestPosition.accuracy > 500) {
        print('GPS précision très faible (${bestPosition?.accuracy}m), essai Fused...');
        Position? fusedPos = await _getStreamGPSPosition(
          maxReadings: 8,
          timeoutSeconds: 12,
        );
        if (fusedPos != null) {
          print('GPS FUSED: ${fusedPos.latitude}, ${fusedPos.longitude} (précision: ${fusedPos.accuracy}m)');
          if (bestPosition == null || fusedPos.accuracy < bestPosition.accuracy) {
            bestPosition = fusedPos;
          }
        }
      }

      // Retourner la meilleure position obtenue
      if (bestPosition != null) {
        print('GPS FINAL: ${bestPosition.latitude}, ${bestPosition.longitude} (précision: ${bestPosition.accuracy}m)');
        return bestPosition;
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

  /// Forcer le GPS hardware Android (bypass Fused Location Provider)
  Future<Position?> _getHardwareGPSPosition({
    int maxReadings = 6,
    int timeoutSeconds = 10,
    double targetAccuracy = 50,
  }) async {
    try {
      final completer = Completer<Position?>();
      Position? bestPosition;
      int count = 0;

      final LocationSettings settings;
      if (Platform.isAndroid) {
        settings = AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          forceLocationManager: true,
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

        if (age > 15) return; // Ignorer les vieilles positions

        if (bestPosition == null || pos.accuracy < bestPosition!.accuracy) {
          bestPosition = pos;
        }

        // Bonne précision atteinte ou assez de lectures
        if (pos.accuracy <= targetAccuracy || count >= maxReadings) {
          if (!completer.isCompleted) completer.complete(bestPosition);
        }
      }, onError: (e) {
        print('Erreur GPS HW stream: $e');
        if (!completer.isCompleted) completer.complete(bestPosition);
      });

      Future.delayed(Duration(seconds: timeoutSeconds), () {
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

  /// Stream GPS via Fused Location Provider
  Future<Position?> _getStreamGPSPosition({
    int maxReadings = 8,
    int timeoutSeconds = 12,
  }) async {
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

        if (age > 15) return;

        if (bestPosition == null || pos.accuracy < bestPosition!.accuracy) {
          bestPosition = pos;
        }

        if (pos.accuracy <= 50 || count >= maxReadings) {
          if (!completer.isCompleted) completer.complete(bestPosition);
        }
      }, onError: (e) {
        if (!completer.isCompleted) completer.complete(bestPosition);
      });

      Future.delayed(Duration(seconds: timeoutSeconds), () {
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

  /// Vérifier si une position est fraîche
  bool _isPositionFresh(Position position, Position? cached) {
    final age = DateTime.now().difference(position.timestamp).inSeconds;
    if (age <= 10) return true;
    if (cached == null) return age <= 30;
    final distance = Geolocator.distanceBetween(
      position.latitude, position.longitude,
      cached.latitude, cached.longitude,
    );
    return distance > 10;
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

    // Tolérance basée sur le chevauchement du cercle d'incertitude GPS
    double tolerance;
    if (accuracy <= 100) {
      tolerance = 50; // Bon GPS : tolérance fixe
    } else if (accuracy <= 500) {
      tolerance = accuracy; // GPS moyen : précision complète
    } else if (accuracy <= 3000) {
      tolerance = accuracy * 0.7; // GPS faible : 70% pour sécurité
    } else {
      tolerance = 2000; // GPS inutilisable : cap
    }

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
