/// Un cours de l'étudiant, avec l'avis qu'il en a donné s'il en a donné un.
///
/// Les deux états vivent dans le même objet : l'écran montre la liste
/// complète de ses cours, notés ou non, plutôt que de faire disparaître un
/// avis rendu — l'étudiant le croirait perdu.
class CoursEvaluable {
  const CoursEvaluable({
    required this.id,
    required this.codeUe,
    required this.nomMatiere,
    this.semestre,
    this.monEvaluation,
  });

  final int id;
  final String codeUe;
  final String nomMatiere;
  final int? semestre;

  /// `null` tant que l'étudiant n'a pas donné son avis.
  final MonEvaluation? monEvaluation;

  bool get estEvalue => monEvaluation != null;

  factory CoursEvaluable.fromJson(Map<String, dynamic> json) {
    final avis = json['mon_evaluation'];

    return CoursEvaluable(
      id: json['id'] as int,
      codeUe: json['code_ue'] as String? ?? '',
      nomMatiere: json['nom_matiere'] as String? ?? 'Cours',
      semestre: json['semestre'] as int?,
      monEvaluation: avis is Map<String, dynamic>
          ? MonEvaluation.fromJson(avis)
          : null,
    );
  }

  CoursEvaluable copyWith({MonEvaluation? monEvaluation}) => CoursEvaluable(
    id: id,
    codeUe: codeUe,
    nomMatiere: nomMatiere,
    semestre: semestre,
    monEvaluation: monEvaluation ?? this.monEvaluation,
  );
}

/// L'avis déposé par l'étudiant sur un cours.
class MonEvaluation {
  const MonEvaluation({required this.note, this.commentaire, this.modifieLe});

  /// De 1 à 5 étoiles.
  final int note;
  final String? commentaire;
  final DateTime? modifieLe;

  factory MonEvaluation.fromJson(Map<String, dynamic> json) => MonEvaluation(
    note: json['note'] as int? ?? 0,
    commentaire: json['commentaire'] as String?,
    modifieLe: DateTime.tryParse(json['modifie_le'] as String? ?? ''),
  );
}
