/// Une séance de l'emploi du temps : un cours, un créneau, une salle.
class SeanceCours {
  const SeanceCours({
    required this.id,
    required this.jour,
    required this.heureDebut,
    required this.heureFin,
    required this.nomMatiere,
    required this.codeUe,
    this.salle,
    this.campus,
    this.dureeHeures,
  });

  final int id;
  final String jour;
  final String heureDebut;
  final String heureFin;
  final String nomMatiere;
  final String codeUe;
  final String? salle;
  final String? campus;
  final num? dureeHeures;

  /// `08:00 – 11:00`, prêt à afficher.
  String get creneau => '$heureDebut – $heureFin';

  factory SeanceCours.fromJson(Map<String, dynamic> json) {
    final ue = json['ue'];
    final campus = json['campus'];

    return SeanceCours(
      id: json['id'] as int,
      jour: json['jour_semaine'] as String? ?? '',
      heureDebut: json['heure_debut'] as String? ?? '',
      heureFin: json['heure_fin'] as String? ?? '',
      nomMatiere: ue is Map ? (ue['nom_matiere'] as String? ?? 'Cours') : 'Cours',
      codeUe: ue is Map ? (ue['code_ue'] as String? ?? '') : '',
      salle: json['salle'] as String?,
      campus: campus is Map ? campus['name'] as String? : null,
      dureeHeures: json['duree_heures'] as num?,
    );
  }
}

/// Les sept jours, dans l'ordre où ils se lisent.
///
/// Le backend renvoie ses séances groupées par jour, sans garantie d'ordre :
/// c'est cette liste qui fixe la lecture de la semaine.
const List<String> joursSemaine = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
