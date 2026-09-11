import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

/// Coordonnée géographique simple, indépendante du moteur de carte.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  String toString() => '$lat,$lng';
}

/// Résultat d'un calcul d'itinéraire OSRM.
class OsmRoute {
  const OsmRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// Tracé complet, à dessiner en polyline sur la carte.
  final List<GeoPoint> points;
  final double distanceMeters;
  final double durationSeconds;

  int get durationMinutes => (durationSeconds / 60).round();
}

/// Services géographiques adossés à OpenStreetMap.
///
/// Google Maps ne sert qu'au rendu visuel de la carte : le géocodage
/// (Nominatim) et le calcul d'itinéraire (OSRM) passent par OSM.
class OsmService extends GetxService {
  static const String _nominatim = 'https://nominatim.openstreetmap.org';
  static const String _osrm = 'https://router.project-osrm.org';

  /// Nominatim impose un User-Agent identifiant l'application.
  static const Map<String, String> _headers = {
    'User-Agent': 'InsamBus/1.0 (transport étudiant INSAM)',
    'Accept': 'application/json',
  };

  /// Recherche une adresse et renvoie ses coordonnées.
  Future<GeoPoint?> geocode(String query) async {
    final uri = Uri.parse(
      '$_nominatim/search'
      '?q=${Uri.encodeQueryComponent(query)}&format=json&limit=1',
    );

    try {
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as List<dynamic>;
      if (data.isEmpty) return null;

      final first = data.first as Map<String, dynamic>;
      return GeoPoint(
        double.parse(first['lat'] as String),
        double.parse(first['lon'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  /// Retrouve le libellé d'un point : utile pour nommer un arrêt.
  Future<String?> reverseGeocode(GeoPoint point) async {
    final uri = Uri.parse(
      '$_nominatim/reverse?lat=${point.lat}&lon=${point.lng}&format=json',
    );

    try {
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Calcule l'itinéraire routier entre deux points, tracé compris.
  Future<OsmRoute?> route(GeoPoint from, GeoPoint to) async {
    final uri = Uri.parse(
      '$_osrm/route/v1/driving/'
      '${from.lng},${from.lat};${to.lng},${to.lat}'
      '?overview=full&geometries=geojson',
    );

    try {
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final first = routes.first as Map<String, dynamic>;
      final coords = (first['geometry']['coordinates'] as List<dynamic>)
          // GeoJSON ordonne en [longitude, latitude].
          .map(
            (c) => GeoPoint((c as List<dynamic>)[1] as double, c[0] as double),
          )
          .toList();

      return OsmRoute(
        points: coords,
        distanceMeters: (first['distance'] as num).toDouble(),
        durationSeconds: (first['duration'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
