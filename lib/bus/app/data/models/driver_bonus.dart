/// Barème des primes chauffeur (CDC §3.3).
///
/// Les montants font foi côté backend (`baremes_primes`) ; ceux-ci ne
/// servent qu'aux libellés explicatifs affichés au chauffeur.
abstract class BonusRates {
  BonusRates._();

  /// Prime par tour validé.
  static const int perTour = 500;

  /// Prime forfaitaire par mission de secours honorée.
  static const int perRescue = 2000;

  /// Prime d'assiduité si 100 % des tours prévus sont réalisés.
  static const int dailyAssiduity = 500;

  /// Bonus mensuel de régularité, sans tour manqué ni retard.
  static const int monthlyRegularity = 10000;
}

/// Une ligne du récapitulatif de cagnotte.
enum BonusEntryKind { tour, rescue, assiduity, regularity, penalty }

extension BonusEntryKindX on BonusEntryKind {
  String get label => switch (this) {
    BonusEntryKind.tour => 'Tour validé',
    BonusEntryKind.rescue => 'Mission de secours',
    BonusEntryKind.assiduity => 'Prime d’assiduité',
    BonusEntryKind.regularity => 'Bonus de régularité',
    BonusEntryKind.penalty => 'Pénalité',
  };

  /// Une pénalité se soustrait du total.
  bool get isDebit => this == BonusEntryKind.penalty;

  /// Code du barème renvoyé par l'API.
  static BonusEntryKind fromApi(String? type, {bool isPenalty = false}) {
    if (isPenalty) return BonusEntryKind.penalty;

    return switch (type) {
      'prime_tour' => BonusEntryKind.tour,
      'prime_secours' => BonusEntryKind.rescue,
      'prime_assiduite' => BonusEntryKind.assiduity,
      'bonus_regularite' => BonusEntryKind.regularity,
      _ => BonusEntryKind.tour,
    };
  }
}

/// État de validation d'une prime par la régulation.
enum BonusStatus { pending, validated, paid, cancelled }

extension BonusStatusX on BonusStatus {
  String get label => switch (this) {
    BonusStatus.pending => 'En attente de validation',
    BonusStatus.validated => 'Validée',
    BonusStatus.paid => 'Payée',
    BonusStatus.cancelled => 'Annulée',
  };

  static BonusStatus fromApi(String? value) => switch (value) {
    'validee' => BonusStatus.validated,
    'payee' => BonusStatus.paid,
    'annulee' => BonusStatus.cancelled,
    _ => BonusStatus.pending,
  };
}

class BonusEntry {
  const BonusEntry({
    required this.id,
    required this.kind,
    required this.amount,
    required this.date,
    this.detail = '',
    this.status = BonusStatus.pending,
  });

  final String id;
  final BonusEntryKind kind;

  /// Montant en FCFA, toujours positif ; le signe vient de [kind].
  final int amount;
  final DateTime date;

  /// Précision affichée sous le libellé (ex. « Tour 2 — Ligne Kango »).
  final String detail;

  final BonusStatus status;

  /// Contribution signée au total du mois.
  int get signed => kind.isDebit ? -amount : amount;

  factory BonusEntry.fromApi(Map<String, dynamic> json) {
    final montant = (json['montant_fcfa'] as num?)?.toInt() ?? 0;
    final estPenalite = json['est_penalite'] as bool? ?? false;

    return BonusEntry(
      id: '${json['id'] ?? ''}',
      kind: BonusEntryKindX.fromApi(
        json['type'] as String?,
        isPenalty: estPenalite,
      ),
      // Une pénalité peut arriver négative : le signe est porté par [kind].
      amount: montant.abs(),
      date:
          DateTime.tryParse(json['date_acquisition'] as String? ?? '')
              ?.toLocal() ??
          DateTime.now(),
      detail: json['libelle'] as String? ?? '',
      status: BonusStatusX.fromApi(json['statut'] as String?),
    );
  }
}

/// Cagnotte du mois en cours (CDC §3.3).
///
/// Bonus Total = (Tours_Valides × P_tour) + (Secours × P_secours)
///               + Prime_Assiduite − Penalites
class DriverBonus {
  const DriverBonus({
    required this.entries,
    required this.toursValidated,
    required this.toursPlanned,
    required this.rescues,
    required this.punctualityRate,
    this.period = '',
    this.assiduityDays = 0,
    this.creditsFromApi,
    this.penaltiesFromApi,
  });

  const DriverBonus.empty()
    : entries = const [],
      toursValidated = 0,
      toursPlanned = 0,
      rescues = 0,
      punctualityRate = 1,
      period = '',
      assiduityDays = 0,
      creditsFromApi = null,
      penaltiesFromApi = null;

  final List<BonusEntry> entries;

  /// Tours validés et prévus sur le mois.
  final int toursValidated;
  final int toursPlanned;
  final int rescues;

  /// Part des tours réalisés à l'heure, de 0 à 1.
  final double punctualityRate;

  /// Période au format `AAAA-MM`.
  final String period;

  /// Jours ayant ouvert droit à la prime d'assiduité.
  final int assiduityDays;

  /// Totaux calculés par le backend : ils font foi, le détail affiché
  /// pouvant être tronqué ou paginé.
  final int? creditsFromApi;
  final int? penaltiesFromApi;

  int get credits =>
      creditsFromApi ??
      entries.where((e) => !e.kind.isDebit).fold(0, (sum, e) => sum + e.amount);

  int get penalties =>
      penaltiesFromApi ??
      entries.where((e) => e.kind.isDebit).fold(0, (sum, e) => sum + e.amount);

  /// Total net du mois, selon la formule du CDC §3.3.
  int get total => credits - penalties;

  /// Le bonus mensuel de régularité n'est acquis qu'avec une ponctualité
  /// parfaite et aucun tour manqué.
  bool get regularityEarned =>
      toursPlanned > 0 &&
      toursValidated >= toursPlanned &&
      punctualityRate >= 1;

  /// Lit la réponse de `GET /api/chauffeur/cagnotte`.
  ///
  /// [toursPlanned] et [punctualityRate] ne figurent pas dans cette
  /// réponse : ils viennent de l'affectation du jour, que le service
  /// rapproche ici.
  factory DriverBonus.fromApi(
    Map<String, dynamic> json, {
    int toursPlanned = 0,
    double punctualityRate = 1,
  }) {
    final detail = (json['detail'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(BonusEntry.fromApi)
        .toList();

    return DriverBonus(
      entries: detail,
      toursValidated: (json['tours_valides'] as num?)?.toInt() ?? 0,
      toursPlanned: toursPlanned,
      rescues: (json['secours_realises'] as num?)?.toInt() ?? 0,
      punctualityRate: punctualityRate,
      period: json['periode'] as String? ?? '',
      assiduityDays: (json['jours_assiduite'] as num?)?.toInt() ?? 0,
      creditsFromApi: (json['total_primes_fcfa'] as num?)?.toInt(),
      penaltiesFromApi: (json['total_penalites_fcfa'] as num?)?.toInt(),
    );
  }
}
