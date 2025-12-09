class UniteEnseignement {
  final int id;
  final String codeUe;
  final String nomMatiere;
  final double volumeHoraireTotal;
  final double heuresEffectuees;
  final double heuresRestantes;
  final double pourcentageProgression;
  final double montantPaye;
  final double montantRestant;
  final double montantMax;
  final double tauxHoraire;
  final String statut;
  final String anneeAcademique;
  final int semestre;
  final DateTime? dateActivation;
  final DateTime? dateAttribution;

  UniteEnseignement({
    required this.id,
    required this.codeUe,
    required this.nomMatiere,
    required this.volumeHoraireTotal,
    this.heuresEffectuees = 0.0,
    this.heuresRestantes = 0.0,
    this.pourcentageProgression = 0.0,
    this.montantPaye = 0.0,
    this.montantRestant = 0.0,
    this.montantMax = 0.0,
    this.tauxHoraire = 0.0,
    this.statut = 'non_activee',
    this.anneeAcademique = '',
    this.semestre = 1,
    this.dateActivation,
    this.dateAttribution,
  });

  factory UniteEnseignement.fromJson(Map<String, dynamic> json) {
    return UniteEnseignement(
      id: json['id'],
      codeUe: json['code_ue'] ?? '',
      nomMatiere: json['nom_matiere'] ?? '',
      volumeHoraireTotal: _parseDouble(json['volume_horaire_total'] ?? json['volume_total'] ?? 0),
      heuresEffectuees: _parseDouble(json['heures_effectuees'] ?? 0),
      heuresRestantes: _parseDouble(json['heures_restantes'] ?? 0),
      pourcentageProgression: _parseDouble(json['pourcentage_progression'] ?? json['pourcentage'] ?? 0),
      montantPaye: _parseDouble(json['montant_paye'] ?? 0),
      montantRestant: _parseDouble(json['montant_restant'] ?? 0),
      montantMax: _parseDouble(json['montant_max'] ?? json['montant_potentiel'] ?? 0),
      tauxHoraire: _parseDouble(json['taux_horaire'] ?? 0),
      statut: json['statut'] ?? 'non_activee',
      anneeAcademique: json['annee_academique'] ?? '',
      semestre: json['semestre'] ?? 1,
      dateActivation: json['date_activation'] != null
          ? DateTime.parse(json['date_activation'])
          : null,
      dateAttribution: json['date_attribution'] != null
          ? DateTime.parse(json['date_attribution'])
          : null,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code_ue': codeUe,
      'nom_matiere': nomMatiere,
      'volume_horaire_total': volumeHoraireTotal,
      'heures_effectuees': heuresEffectuees,
      'heures_restantes': heuresRestantes,
      'pourcentage_progression': pourcentageProgression,
      'montant_paye': montantPaye,
      'montant_restant': montantRestant,
      'montant_max': montantMax,
      'taux_horaire': tauxHoraire,
      'statut': statut,
      'annee_academique': anneeAcademique,
      'semestre': semestre,
      'date_activation': dateActivation?.toIso8601String(),
      'date_attribution': dateAttribution?.toIso8601String(),
    };
  }

  bool isActivee() => statut == 'activee';
  bool isNonActivee() => statut == 'non_activee';
  bool hasHeuresRestantes() => heuresRestantes > 0;

  String getFormattedProgression() {
    return '${heuresEffectuees.toStringAsFixed(1)}h / ${volumeHoraireTotal.toStringAsFixed(1)}h';
  }

  String getFormattedPourcentage() {
    return '${pourcentageProgression.toStringAsFixed(0)}%';
  }
}
