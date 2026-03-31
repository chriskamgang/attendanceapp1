import 'package:geolocator/geolocator.dart';

class LocationService {
  // Vérifier si les services de localisation sont activés
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Demander les permissions (utilise Geolocator pour iOS)
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // Vérifier les permissions
  Future<bool> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // Obtenir la position actuelle avec meilleure précision
  // Fait jusqu'à 3 tentatives et garde la meilleure précision
  Future<Position?> getCurrentPosition() async {
    try {
      // Vérifier si le service est activé
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Le service de localisation est désactivé');
      }

      // Vérifier les permissions
      bool hasPermission = await checkPermission();
      if (!hasPermission) {
        hasPermission = await requestPermission();
        if (!hasPermission) {
          throw Exception('Permission de localisation refusée');
        }
      }

      Position? bestPosition;

      // Tentative 1 : position haute précision
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 10),
        );
        bestPosition = pos;
        print('GPS tentative 1: ${pos.latitude}, ${pos.longitude} (précision: ${pos.accuracy}m)');

        // Si bonne précision (<50m), retourner directement
        if (pos.accuracy <= 50) {
          return pos;
        }
      } catch (e) {
        print('GPS tentative 1 échouée: $e');
      }

      // Tentative 2 : réessayer après un court délai
      await Future.delayed(const Duration(seconds: 2));
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 10),
        );
        print('GPS tentative 2: ${pos.latitude}, ${pos.longitude} (précision: ${pos.accuracy}m)');

        if (bestPosition == null || pos.accuracy < bestPosition.accuracy) {
          bestPosition = pos;
        }

        // Si bonne précision, retourner
        if (bestPosition.accuracy <= 50) {
          return bestPosition;
        }
      } catch (e) {
        print('GPS tentative 2 échouée: $e');
      }

      // Tentative 3 : dernière chance avec délai plus long
      await Future.delayed(const Duration(seconds: 3));
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        print('GPS tentative 3: ${pos.latitude}, ${pos.longitude} (précision: ${pos.accuracy}m)');

        if (bestPosition == null || pos.accuracy < bestPosition.accuracy) {
          bestPosition = pos;
        }
      } catch (e) {
        print('GPS tentative 3 échouée: $e');
      }

      if (bestPosition != null) {
        print('GPS final: ${bestPosition.latitude}, ${bestPosition.longitude} (précision: ${bestPosition.accuracy}m)');
      }

      return bestPosition;
    } catch (e) {
      print('Erreur lors de l\'obtention de la position: $e');
      return null;
    }
  }

  // Calculer la distance entre deux points en mètres
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Vérifier si l'utilisateur est dans une zone
  bool isInZone({
    required double userLat,
    required double userLon,
    required double zoneLat,
    required double zoneLon,
    required double radius,
    double accuracy = 0,
  }) {
    double distance = calculateDistance(userLat, userLon, zoneLat, zoneLon);
    // Ajouter la marge de précision GPS (comme le backend)
    double tolerance = accuracy > 50 ? accuracy : 50;
    if (tolerance > 500) tolerance = 500; // max 500m de tolérance
    return distance <= (radius + tolerance);
  }

  // Stream de position pour suivre en temps réel
  Stream<Position> getPositionStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    return Geolocator.getPositionStream(
      locationSettings: locationSettings,
    );
  }
}
