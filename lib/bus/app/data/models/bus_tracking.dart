import 'pickup_point.dart';

/// État du bus au fil de la tournée, tel que le renvoie le backend.
enum BusStatus {
  /// Le service n'est pas encore activé ce matin.
  idle,

  /// Le bus roule vers les points de ramassage.
  enRoute,

  /// Le bus est à l'arrêt, embarquement en cours.
  boarding,

  /// Le bus a quitté l'arrêt, direction le campus.
  toCampus,

  /// Tournée terminée.
  arrived,
}

extension BusStatusX on BusStatus {
  String get label => switch (this) {
    BusStatus.idle => 'Pas encore parti',
    BusStatus.enRoute => 'En route',
    BusStatus.boarding => 'À ton arrêt',
    BusStatus.toCampus => 'En route vers le campus',
    BusStatus.arrived => 'Arrivé au campus',
  };

  /// Un suivi n'a de sens que lorsque le bus circule.
  bool get isLive =>
      this == BusStatus.enRoute ||
      this == BusStatus.boarding ||
      this == BusStatus.toCampus;

  /// Statut renvoyé par l'API (`en_attente`, `embarquement`, `en_transit`…).
  static BusStatus fromApi(String? value) => switch (value) {
    'en_attente' => BusStatus.enRoute,
    'embarquement' => BusStatus.boarding,
    'en_transit' => BusStatus.toCampus,
    'termine' => BusStatus.arrived,
    _ => BusStatus.idle,
  };
}

/// Position géographique simple, indépendante du moteur de carte.
class LatLngPoint {
  const LatLngPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  static LatLngPoint? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final lat = _toDouble(json['latitude']);
    final lng = _toDouble(json['longitude']);
    if (lat == null || lng == null) return null;

    return LatLngPoint(lat, lng);
  }

  static double? _toDouble(Object? value) => switch (value) {
    num n => n.toDouble(),
    String s => double.tryParse(s),
    _ => null,
  };
}

/// Suivi en direct du bus desservant l'arrêt de l'étudiant (CDC §3.1).
class BusTracking {
  const BusTracking({
    required this.tourneeId,
    required this.status,
    this.busId = '',
    required this.busLabel,
    required this.plate,
    required this.driverName,
    required this.lineName,
    this.etaMinutes,
    this.distanceMeters,
    this.busPosition,
    this.myStop,
    this.routeStops = const [],
    this.realtimeChannel = '',
  });

  final String tourneeId;
  final BusStatus status;

  /// Identifiant du bus suivi, tel que le porte la flotte en ligne : il
  /// évite de dessiner deux fois le même véhicule sur la carte.
  final String busId;

  /// Nom affiché du véhicule, ex. « Bus 04 ».
  final String busLabel;
  final String plate;
  final String driverName;
  final String lineName;

  /// Minutes estimées avant l'arrivée ; `null` sans position connue.
  final int? etaMinutes;
  final int? distanceMeters;

  final LatLngPoint? busPosition;

  /// Point de ramassage de l'étudiant.
  final PickupPoint? myStop;

  /// Lieux du parcours, dans l'ordre : ils dessinent le tracé.
  final List<PickupPoint> routeStops;

  /// Canal de diffusion temps réel des positions.
  final String realtimeChannel;

  bool get isLive => status.isLive;

  /// Rejoue le suivi avec une position fraîche.
  ///
  /// La diffusion temps réel n'apporte que la position : tout le reste
  /// du suivi vient du dernier sondage et doit être conservé.
  BusTracking copyWith({LatLngPoint? busPosition, int? etaMinutes}) =>
      BusTracking(
        tourneeId: tourneeId,
        status: status,
        busId: busId,
        busLabel: busLabel,
        plate: plate,
        driverName: driverName,
        lineName: lineName,
        etaMinutes: etaMinutes ?? this.etaMinutes,
        distanceMeters: distanceMeters,
        busPosition: busPosition ?? this.busPosition,
        myStop: myStop,
        routeStops: routeStops,
        realtimeChannel: realtimeChannel,
      );

  factory BusTracking.fromJson(Map<String, dynamic> json) {
    final tournee = json['tournee'] as Map<String, dynamic>? ?? const {};
    final affectation = tournee['affectation'] as Map<String, dynamic>?;
    final bus = affectation?['bus'] as Map<String, dynamic>?;
    final chauffeur = affectation?['chauffeur'] as Map<String, dynamic>?;
    final ligne = affectation?['ligne'] as Map<String, dynamic>?;
    final parcours = tournee['parcours'] as Map<String, dynamic>?;
    final estimation = json['estimation_arrivee'] as Map<String, dynamic>?;
    final monArret = json['mon_arret'] as Map<String, dynamic>?;

    // Les étapes du parcours donnent le tracé à dessiner sur la carte.
    final etapes = (parcours?['etapes'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((e) => e['lieu'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map(PickupPoint.fromJson)
        .toList();

    return BusTracking(
      tourneeId: tournee['id']?.toString() ?? '',
      status: BusStatusX.fromApi(tournee['statut'] as String?),
      busId: bus?['id']?.toString() ?? '',
      busLabel: bus?['immatriculation'] as String? ?? 'Bus',
      plate: bus?['immatriculation'] as String? ?? '',
      driverName:
          chauffeur?['nom_complet'] as String? ??
          (chauffeur?['user'] as Map<String, dynamic>?)?['nom_complet']
              as String? ??
          '',
      lineName: ligne?['nom'] as String? ?? '',
      etaMinutes: (estimation?['minutes_estimees'] as num?)?.toInt(),
      distanceMeters: (estimation?['distance_metres'] as num?)?.toInt(),
      busPosition: LatLngPoint.fromJson(
        json['position'] as Map<String, dynamic>?,
      ),
      myStop: monArret == null ? null : PickupPoint.fromJson(monArret),
      routeStops: etapes,
      realtimeChannel: json['canal_temps_reel'] as String? ?? '',
    );
  }
}
