import 'bus_tracking.dart';

/// État d'un bus vu depuis la carte des étudiants.
enum OnlineBusState {
  /// Le chauffeur est en ligne, mais aucun tour n'est ouvert : le bus
  /// attend, au dépôt ou en bout de ligne.
  parked,

  /// Un tour est en cours ; le bus dessert des arrêts.
  onTour,
}

extension OnlineBusStateX on OnlineBusState {
  String get label => switch (this) {
    OnlineBusState.parked => 'À l’arrêt',
    OnlineBusState.onTour => 'En service',
  };

  static OnlineBusState fromApi(String? value) =>
      value == 'en_tournee' ? OnlineBusState.onTour : OnlineBusState.parked;
}

/// Un bus actuellement en ligne, tel que l'affiche la carte (CDC §3.1).
///
/// Le chauffeur diffuse sa position dès l'ouverture de son application :
/// l'étudiant voit donc le bus stationné aussi bien que le bus en route.
/// Le conducteur n'est pas nommé — on suit un véhicule, pas une personne.
class OnlineBus {
  const OnlineBus({
    required this.busId,
    required this.plate,
    required this.position,
    required this.state,
    this.tourneeId,
    this.lineName = '',
    this.speedKmh,
    this.headingDegrees,
    this.servedStopIds = const [],
  });

  final String busId;
  final String plate;
  final LatLngPoint position;
  final OnlineBusState state;

  /// Tour en cours, `null` quand le bus est stationné.
  final String? tourneeId;

  final String lineName;
  final int? speedKmh;

  /// Cap en degrés : oriente l'icône du bus dans son sens de marche.
  /// `null` à l'arrêt, où le cap part en girouette.
  final int? headingDegrees;

  /// Identifiants des lieux desservis par le tour en cours ; vide quand le
  /// bus est stationné. Sert à repérer le bus qui passe par chez soi.
  final List<String> servedStopIds;

  bool get isMoving => state == OnlineBusState.onTour && (speedKmh ?? 0) > 3;

  /// Ce bus dessert-il l'arrêt donné ?
  bool serves(String? stopId) =>
      stopId != null && servedStopIds.contains(stopId);

  static OnlineBus? fromJson(Map<String, dynamic> json) {
    final position = LatLngPoint.fromJson({
      'latitude': json['latitude'],
      'longitude': json['longitude'],
    });

    // Un bus sans position ne se dessine pas : le chauffeur est en ligne
    // mais son GPS n'a pas encore fixé de point.
    if (position == null) return null;

    final busId = json['bus_id']?.toString();
    if (busId == null || busId.isEmpty) return null;

    return OnlineBus(
      busId: busId,
      plate: json['immatriculation'] as String? ?? 'Bus',
      position: position,
      state: OnlineBusStateX.fromApi(json['etat'] as String?),
      tourneeId: json['tournee_id']?.toString(),
      lineName: json['ligne'] as String? ?? '',
      speedKmh: (json['vitesse_kmh'] as num?)?.toInt(),
      headingDegrees: (json['cap_degres'] as num?)?.toInt(),
      servedStopIds: (json['lieux_desservis'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }

  /// Rejoue le bus avec une position fraîche, reçue en temps réel.
  OnlineBus copyWith({
    LatLngPoint? position,
    OnlineBusState? state,
    String? tourneeId,
    int? speedKmh,
    int? headingDegrees,
  }) => OnlineBus(
    busId: busId,
    plate: plate,
    position: position ?? this.position,
    state: state ?? this.state,
    tourneeId: tourneeId ?? this.tourneeId,
    lineName: lineName,
    speedKmh: speedKmh ?? this.speedKmh,
    headingDegrees: headingDegrees ?? this.headingDegrees,
    servedStopIds: servedStopIds,
  );
}
