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

  // Obtenir la position actuelle
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

      // Obtenir la position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
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
  }) {
    double distance = calculateDistance(userLat, userLon, zoneLat, zoneLon);
    return distance <= radius;
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
