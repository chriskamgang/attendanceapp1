import 'package:get/get.dart';

import '../models/cours_evaluable.dart';
import '../models/seance_cours.dart';
import 'api_client.dart';

/// La scolarité de l'étudiant : son emploi du temps, ses cours et l'avis
/// qu'il en donne.
///
/// Ces routes vivent sous `/api`, aux côtés d'Estuaire RH, et non sous
/// `/api/bus` : elles précèdent le transport et servent aussi l'enseignant.
/// Le chemin absolu passé au client dit ce voisinage — voir `ApiClient._uri`.
class ScolariteService extends GetxService {
  ScolariteService({required this.api});

  final ApiClient api;

  static const String _emploiDuTemps = '/api/emploi-du-temps/mon-emploi';

  /// Celle-ci vit bien sous `/api/bus` : elle sert la complétion de profil
  /// du transport, avant même que l'étudiant ait une scolarité.
  static const String _catalogue = 'scolarite';
  static const String _evaluations = '/api/evaluations-cours';

  /// La semaine, jour par jour, dans l'ordre de [joursSemaine].
  ///
  /// Les jours sans cours sont absents plutôt que vides : c'est à l'écran
  /// de décider s'il les montre.
  Future<Map<String, List<SeanceCours>>> emploiDuTemps() async {
    final reponse = await api.get(_emploiDuTemps);
    final donnees = reponse['data'];

    if (donnees is! Map) return const {};

    final semaine = <String, List<SeanceCours>>{};

    for (final jour in joursSemaine) {
      final seances = donnees[jour];
      if (seances is! List || seances.isEmpty) continue;

      semaine[jour] = seances
          .whereType<Map<String, dynamic>>()
          .map(SeanceCours.fromJson)
          .toList();
    }

    return semaine;
  }

  /// Niveaux et spécialités proposés à la complétion de profil.
  ///
  /// Les valeurs viennent des unités d'enseignement elles-mêmes : c'est ce
  /// couple que compare l'emploi du temps, et lui seul garantit qu'un choix
  /// donnera une semaine non vide.
  Future<({List<String> niveaux, List<String> specialites})>
  catalogueScolarite() async {
    final reponse = await api.get(_catalogue);

    List<String> liste(Object? brut) =>
        brut is List ? brut.whereType<String>().toList() : const [];

    return (
      niveaux: liste(reponse['niveaux']),
      specialites: liste(reponse['specialites']),
    );
  }

  /// Les cours que l'étudiant peut noter, avec son avis s'il en a déjà un.
  Future<List<CoursEvaluable>> coursEvaluables() async {
    final reponse = await api.get(_evaluations);
    final donnees = reponse['data'];

    if (donnees is! List) return const [];

    return donnees
        .whereType<Map<String, dynamic>>()
        .map(CoursEvaluable.fromJson)
        .toList();
  }

  /// Dépose ou révise l'avis de l'étudiant sur un cours.
  ///
  /// Le serveur remplace l'avis précédent s'il en existait un : il n'y a
  /// donc rien à distinguer ici entre une première note et une correction.
  Future<MonEvaluation> evaluer({
    required int uniteEnseignementId,
    required int note,
    String? commentaire,
  }) async {
    final reponse = await api.post('$_evaluations/$uniteEnseignementId', {
      'note': note,
      if (commentaire != null && commentaire.trim().isNotEmpty)
        'commentaire': commentaire.trim(),
    });

    final donnees = reponse['data'];

    return donnees is Map<String, dynamic>
        ? MonEvaluation.fromJson(donnees)
        : MonEvaluation(note: note, commentaire: commentaire);
  }
}
