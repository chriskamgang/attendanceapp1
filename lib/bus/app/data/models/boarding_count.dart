/// Comptage billettique d'un tour, côté chauffeur (CDC §3.2).
///
/// Confronte l'effectif que le chauffeur déclare au nombre de pass
/// réellement scannés : la différence, ce sont les passagers sans ticket.
class BoardingCount {
  const BoardingCount({
    this.headcount,
    this.validated = 0,
    this.withoutTicket = 0,
    this.reason = '',
    this.comment = '',
    this.justified = true,
  });

  /// Effectif compté par le chauffeur ; `null` tant qu'il ne l'a pas saisi.
  final int? headcount;

  /// Nombre de pass scannés sur ce tour.
  final int validated;

  /// Passagers montés sans ticket validé.
  final int withoutTicket;

  /// Motif d'écart retenu et son éventuel commentaire.
  final String reason;
  final String comment;

  /// L'écart est nul, ou bien il porte une justification.
  final bool justified;

  bool get hasGap => withoutTicket > 0;

  /// Le départ reste bloqué tant qu'un écart n'est pas motivé.
  bool get blocksDeparture => hasGap && !justified;

  factory BoardingCount.fromJson(Map<String, dynamic> json) => BoardingCount(
    headcount: (json['effectif_embarque'] as num?)?.toInt(),
    validated: (json['embarquements_valides'] as num?)?.toInt() ?? 0,
    withoutTicket: (json['passagers_sans_ticket'] as num?)?.toInt() ?? 0,
    reason: json['motif_ecart'] as String? ?? '',
    comment: json['commentaire_ecart'] as String? ?? '',
    justified: json['ecart_justifie'] as bool? ?? true,
  );
}

/// Motif proposé au chauffeur pour justifier l'écart de comptage.
class GapReason {
  const GapReason({
    required this.value,
    required this.label,
    required this.needsComment,
  });

  final String value;
  final String label;

  /// Un motif libre n'a de valeur pour la supervision que commenté.
  final bool needsComment;

  factory GapReason.fromJson(Map<String, dynamic> json) => GapReason(
    value: json['valeur'] as String? ?? '',
    label: json['libelle'] as String? ?? '',
    needsComment: json['exige_commentaire'] as bool? ?? false,
  );
}

/// Résultat d'un scan de QR : qui vient de monter, et l'état du comptage.
class ScanResult {
  const ScanResult({
    required this.message,
    required this.alreadyBoarded,
    required this.studentName,
    required this.matricule,
    required this.tripsLeft,
    required this.count,
  });

  final String message;

  /// Vrai si cet étudiant avait déjà été scanné sur ce tour : aucun
  /// trajet n'a été débité une seconde fois.
  final bool alreadyBoarded;

  final String studentName;
  final String matricule;

  /// Trajets restant sur le pass après le scan ; `null` pour un forfait
  /// de jours, qui ne décompte pas les trajets.
  final int? tripsLeft;

  final BoardingCount count;

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final etudiant = json['etudiant'] as Map<String, dynamic>? ?? const {};
    final abonnement = json['abonnement'] as Map<String, dynamic>?;

    return ScanResult(
      message: json['message'] as String? ?? '',
      alreadyBoarded: json['deja_valide'] as bool? ?? false,
      studentName: etudiant['nom_complet'] as String? ?? 'Étudiant',
      matricule: etudiant['matricule'] as String? ?? '',
      tripsLeft: (abonnement?['trajets_restants'] as num?)?.toInt(),
      count: BoardingCount.fromJson(
        json['comptage'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}
