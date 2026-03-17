class UeSchedule {
  final int id;
  final String jourSemaine;
  final String heureDebut;
  final String heureFin;
  final String? salle;
  final double dureeHeures;
  final Map<String, dynamic>? ue;
  final Map<String, dynamic>? campus;

  UeSchedule({
    required this.id,
    required this.jourSemaine,
    required this.heureDebut,
    required this.heureFin,
    this.salle,
    this.dureeHeures = 0,
    this.ue,
    this.campus,
  });

  factory UeSchedule.fromJson(Map<String, dynamic> json) {
    return UeSchedule(
      id: json['id'],
      jourSemaine: json['jour_semaine'] ?? '',
      heureDebut: json['heure_debut'] ?? '',
      heureFin: json['heure_fin'] ?? '',
      salle: json['salle'],
      dureeHeures: _parseDouble(json['duree_heures'] ?? 0),
      ue: json['ue'] as Map<String, dynamic>?,
      campus: json['campus'] as Map<String, dynamic>?,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String get ueCode => ue?['code_ue'] ?? '';
  String get ueNom => ue?['nom_matiere'] ?? '';
  String get campusName => campus?['name'] ?? '';
  int? get campusId => campus?['id'];

  String get formattedCreneau => '$heureDebut - $heureFin';

  String get displayLabel {
    String label = '$ueCode - $ueNom ($heureDebut-$heureFin';
    if (salle != null && salle!.isNotEmpty) {
      label += ', salle $salle';
    }
    label += ')';
    return label;
  }

  static String jourSemaineLabel(String jour) {
    const labels = {
      'lundi': 'Lundi',
      'mardi': 'Mardi',
      'mercredi': 'Mercredi',
      'jeudi': 'Jeudi',
      'vendredi': 'Vendredi',
      'samedi': 'Samedi',
      'dimanche': 'Dimanche',
    };
    return labels[jour] ?? jour;
  }
}
