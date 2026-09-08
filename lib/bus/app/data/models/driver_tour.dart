import 'tour_stage.dart';

/// Un tour de la journée du chauffeur (CDC §3.2).
///
/// Une journée compte plusieurs tours prévus (ex. « Tour 1 validé sur 4 »).
/// Chaque tour parcourt le cycle de pointage de bout en bout.
class DriverTour {
  const DriverTour({
    required this.index,
    required this.lineName,
    required this.pickupName,
    required this.stage,
    this.id,
    this.headcount = 0,
    this.startedAt,
    this.arrivedAtPickupAt,
    this.departedAt,
    this.finishedAt,
    this.expectedMinutes = 25,
    this.scanned = 0,
    this.withoutTicket = 0,
    this.gapJustified = true,
    this.busPlate = '',
    this.busCapacity = 0,
    this.hasDurationAnomaly = false,
    this.pickupLat,
    this.pickupLng,
    this.pickupRadius,
    this.terminusName = '',
    this.terminusLat,
    this.terminusLng,
    this.terminusRadius,
  });

  /// Identifiant du tour côté backend ; `null` tant qu'aucun tour n'est
  /// ouvert — c'est ce qui distingue un service à démarrer d'un tour en
  /// cours, et ce que visent tous les appels de pointage.
  final int? id;

  /// Numéro du tour dans la journée, à partir de 1.
  final int index;
  final String lineName;
  final String pickupName;
  final TourStage stage;

  /// Effectif embarqué, saisi à l'étape 3.
  final int headcount;

  /// Horodatage de chaque étape, conservé pour le récapitulatif.
  final DateTime? startedAt;
  final DateTime? arrivedAtPickupAt;
  final DateTime? departedAt;
  final DateTime? finishedAt;

  /// Durée minimale attendue du parcours, en minutes.
  ///
  /// Le CDC §3.4 signale comme anomalie un tour clos plus vite que cela.
  final int expectedMinutes;

  /// Comptage billettique du tour : pass scannés, et écart avec l'effectif.
  final int scanned;
  final int withoutTicket;

  /// L'écart est nul, ou bien il porte déjà un motif.
  final bool gapJustified;

  final String busPlate;
  final int busCapacity;

  /// Anomalie de cohérence temporelle retenue par le backend (CDC §3.4).
  final bool hasDurationAnomaly;

  /// Position de l'arrêt desservi et son rayon de validation, tels que le
  /// backend les applique (CDC §3.4).
  final double? pickupLat;
  final double? pickupLng;
  final double? pickupRadius;

  /// Terminus du parcours : c'est là que se joue le contrôle de zone de
  /// clôture, et donc la prime du tour (CDC §3.4).
  final String terminusName;
  final double? terminusLat;
  final double? terminusLng;
  final double? terminusRadius;

  bool get isDone => stage == TourStage.finished;

  /// Un tour est ouvert dès qu'il porte un identifiant et n'est pas clos.
  bool get isOpen => id != null && !isDone;

  /// Le départ reste bloqué tant qu'un écart n'est pas motivé (CDC §3.4).
  bool get departureBlocked => withoutTicket > 0 && !gapJustified;

  /// Durée réelle du tour, une fois clos.
  Duration? get duration {
    final from = startedAt;
    final to = finishedAt;
    if (from == null || to == null) return null;
    return to.difference(from);
  }

  /// Vrai si le tour a été clos plus vite que le temps minimal estimé
  /// (CDC §3.4 — cohérence temporelle de trajet).
  ///
  /// Le backend tranche ; on retombe sur la durée locale s'il ne s'est
  /// pas prononcé.
  bool get isSuspiciouslyFast {
    if (hasDurationAnomaly) return true;
    final d = duration;
    if (d == null) return false;
    return d.inMinutes < expectedMinutes;
  }

  /// Lit un tour tel que le renvoie l'API (`TourneeResource`).
  ///
  /// [lineName] et [pickupName] viennent de l'affectation quand la
  /// ressource ne les porte pas : le tour n'embarque son parcours que sur
  /// les réponses qui le chargent explicitement.
  factory DriverTour.fromApi(
    Map<String, dynamic> json, {
    String lineName = '',
    String pickupName = '',
    int expectedMinutes = 25,
  }) {
    final horodatage = json['horodatage'] as Map<String, dynamic>? ?? const {};
    final affectation = json['affectation'] as Map<String, dynamic>?;
    final bus = affectation?['bus'] as Map<String, dynamic>?;
    final ligne = affectation?['ligne'] as Map<String, dynamic>?;
    final lieu = json['lieu'] as Map<String, dynamic>?;

    // Le terminus se lit sur la dernière étape du parcours ; le drapeau
    // `est_terminus` prime quand il est posé.
    final etapes = ((json['parcours'] as Map<String, dynamic>?)?['etapes']
            as List<dynamic>? ??
        const []).whereType<Map<String, dynamic>>().toList();

    Map<String, dynamic>? terminus;
    for (final etape in etapes) {
      if (etape['est_terminus'] == true) {
        terminus = etape;
        break;
      }
    }
    terminus ??= etapes.isEmpty ? null : etapes.last;
    final lieuTerminus = terminus?['lieu'] as Map<String, dynamic>?;

    final effectif = (json['effectif_embarque'] as num?)?.toInt();

    DateTime? at(String key) {
      final raw = horodatage[key] as String?;
      return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    }

    return DriverTour(
      id: (json['id'] as num?)?.toInt(),
      index: (json['numero_tour'] as num?)?.toInt() ?? 1,
      lineName: (ligne?['nom'] as String?)?.trim().isNotEmpty == true
          ? ligne!['nom'] as String
          : lineName,
      pickupName: (lieu?['nom'] as String?)?.trim().isNotEmpty == true
          ? lieu!['nom'] as String
          : pickupName,
      stage: TourStageX.fromApi(
        statut: json['statut'] as String? ?? '',
        hasHeadcount: effectif != null,
      ),
      headcount: effectif ?? 0,
      startedAt: at('demarre_le'),
      arrivedAtPickupAt: at('arrive_point_le'),
      departedAt: at('depart_le'),
      finishedAt: at('termine_le'),
      expectedMinutes:
          (ligne?['duree_trajet_minutes'] as num?)?.toInt() ?? expectedMinutes,
      scanned: (json['embarquements_valides'] as num?)?.toInt() ?? 0,
      withoutTicket: (json['passagers_sans_ticket'] as num?)?.toInt() ?? 0,
      gapJustified: json['ecart_justifie'] as bool? ?? true,
      busPlate: bus?['immatriculation'] as String? ?? '',
      busCapacity: (bus?['capacite'] as num?)?.toInt() ?? 0,
      hasDurationAnomaly: json['anomalie_duree'] as bool? ?? false,
      pickupLat: (lieu?['latitude'] as num?)?.toDouble(),
      pickupLng: (lieu?['longitude'] as num?)?.toDouble(),
      pickupRadius: (lieu?['rayon_validation_metres'] as num?)?.toDouble(),
      terminusName: lieuTerminus?['nom'] as String? ?? '',
      terminusLat: (lieuTerminus?['latitude'] as num?)?.toDouble(),
      terminusLng: (lieuTerminus?['longitude'] as num?)?.toDouble(),
      terminusRadius:
          (lieuTerminus?['rayon_validation_metres'] as num?)?.toDouble(),
    );
  }

  DriverTour copyWith({
    int? id,
    int? index,
    TourStage? stage,
    int? headcount,
    DateTime? startedAt,
    DateTime? arrivedAtPickupAt,
    DateTime? departedAt,
    DateTime? finishedAt,
    int? scanned,
    int? withoutTicket,
    bool? gapJustified,
  }) => DriverTour(
    id: id ?? this.id,
    index: index ?? this.index,
    lineName: lineName,
    pickupName: pickupName,
    stage: stage ?? this.stage,
    headcount: headcount ?? this.headcount,
    startedAt: startedAt ?? this.startedAt,
    arrivedAtPickupAt: arrivedAtPickupAt ?? this.arrivedAtPickupAt,
    departedAt: departedAt ?? this.departedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    expectedMinutes: expectedMinutes,
    scanned: scanned ?? this.scanned,
    withoutTicket: withoutTicket ?? this.withoutTicket,
    gapJustified: gapJustified ?? this.gapJustified,
    busPlate: busPlate,
    busCapacity: busCapacity,
    hasDurationAnomaly: hasDurationAnomaly,
    pickupLat: pickupLat,
    pickupLng: pickupLng,
    pickupRadius: pickupRadius,
    terminusName: terminusName,
    terminusLat: terminusLat,
    terminusLng: terminusLng,
    terminusRadius: terminusRadius,
  );
}
