/// Formule d'abonnement proposée à l'étudiant (CDC §3.1).
///
/// Le catalogue vient du backend : les montants et les durées ne sont plus
/// codés dans l'application.
class PassTarif {
  const PassTarif({
    required this.id,
    required this.code,
    required this.label,
    required this.amount,
    required this.daysCovered,
    required this.tripsPerDay,
    required this.totalAmount,
  });

  final String id;
  final String code;
  final String label;

  /// Montant unitaire en FCFA : par trajet, ou par jour pour un pass.
  final int amount;

  /// Nombre de jours couverts ; 0 pour un ticket au trajet.
  final int daysCovered;
  final int tripsPerDay;

  /// Montant total à régler pour souscrire.
  final int totalAmount;

  /// Une formule couvrant plusieurs jours est un abonnement, pas un ticket.
  bool get isSubscription => daysCovered > 1;

  factory PassTarif.fromJson(Map<String, dynamic> json) => PassTarif(
    id: json['id'].toString(),
    code: json['code'] as String? ?? '',
    label: json['libelle'] as String? ?? '',
    amount: (json['montant_fcfa'] as num?)?.toInt() ?? 0,
    daysCovered: (json['jours_couverts'] as num?)?.toInt() ?? 0,
    tripsPerDay: (json['trajets_par_jour'] as num?)?.toInt() ?? 0,
    totalAmount: (json['montant_total_fcfa'] as num?)?.toInt() ?? 0,
  );
}

/// Abonnement souscrit par l'étudiant.
class StudentPass {
  const StudentPass({
    required this.id,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.tripsLeft,
    required this.amountPaid,
    this.tarif,
    this.statusLabel = '',
    this.paymentMethod = '',
    this.paidAt,
    this.pendingTrips = 0,
    this.amountDue = 0,
    this.usable = false,
  });

  final String id;

  /// Statut brut du backend : `actif`, `en_attente`, `expire`…
  final String status;
  final String statusLabel;

  final DateTime? startDate;
  final DateTime? endDate;

  /// Trajets restants pour une formule au ticket.
  final int tripsLeft;
  final int amountPaid;

  final PassTarif? tarif;
  final String paymentMethod;
  final DateTime? paidAt;

  /// Trajets ajoutés par une recharge, acquis une fois réglés.
  ///
  /// Le pass reste utilisable entre-temps pour ce qui est déjà payé : ces
  /// trajets-là attendent à part.
  final int pendingTrips;

  /// Somme restant à régler : le pass entier s'il n'a jamais été payé,
  /// la seule recharge s'il est déjà actif.
  final int amountDue;

  /// Le backend juge ce pass utilisable ici et maintenant.
  final bool usable;

  /// Ce pass attend un paiement, qu'il soit neuf ou rechargé.
  bool get needsPayment => amountDue > 0;

  /// Des trajets ont été ajoutés et attendent leur règlement.
  bool get hasRecharge => pendingTrips > 0;

  /// Seul le backend décide de la validité : l'application ne recalcule pas
  /// la règle, elle en rend compte.
  bool get isActive => status == 'actif';

  bool get isPending => status == 'en_attente';

  /// Jours restants avant expiration, jamais négatif.
  int get daysLeft {
    final fin = endDate;
    if (fin == null) return 0;

    final aujourdhui = DateTime.now();
    final reste = DateTime(fin.year, fin.month, fin.day)
        .difference(DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day))
        .inDays;

    return reste < 0 ? 0 : reste;
  }

  /// Le pass arrive à échéance : l'accueil le signale.
  bool get isExpiringSoon => isActive && daysLeft <= 2;

  factory StudentPass.fromJson(Map<String, dynamic> json) {
    final tarif = json['tarif'] as Map<String, dynamic>?;

    return StudentPass(
      id: json['id'].toString(),
      status: json['statut'] as String? ?? '',
      statusLabel: json['statut_libelle'] as String? ?? '',
      startDate: DateTime.tryParse(json['date_debut'] as String? ?? ''),
      endDate: DateTime.tryParse(json['date_fin'] as String? ?? ''),
      tripsLeft: (json['trajets_restants'] as num?)?.toInt() ?? 0,
      amountPaid: (json['montant_paye_fcfa'] as num?)?.toInt() ?? 0,
      tarif: tarif == null ? null : PassTarif.fromJson(tarif),
      paymentMethod: json['moyen_paiement'] as String? ?? '',
      paidAt: DateTime.tryParse(json['paye_le'] as String? ?? ''),
      pendingTrips: (json['trajets_en_attente'] as num?)?.toInt() ?? 0,
      amountDue: (json['montant_a_regler_fcfa'] as num?)?.toInt() ?? 0,
      usable: json['utilisable'] as bool? ?? false,
    );
  }
}
