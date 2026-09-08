import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/cours_evaluable.dart';
import '../../../data/models/seance_cours.dart';
import '../../../data/services/api_exception.dart';
import '../../../data/services/scolarite_service.dart';

/// La scolarité de l'étudiant : sa semaine et l'avis qu'il porte sur ses
/// cours.
///
/// Les deux sections ont leur propre chargement et leur propre erreur : un
/// emploi du temps indisponible ne doit pas emporter la liste des cours, que
/// le serveur sert par une autre route.
class ScolariteController extends GetxController {
  ScolariteController({ScolariteService? scolarite})
    : _scolarite = scolarite ?? Get.find<ScolariteService>();

  final ScolariteService _scolarite;

  /// Onglet affiché : 0 la semaine, 1 les cours à noter.
  final RxInt onglet = 0.obs;

  // --- Emploi du temps ---------------------------------------------------

  final RxMap<String, List<SeanceCours>> semaine =
      <String, List<SeanceCours>>{}.obs;
  final RxBool chargeSemaine = true.obs;
  final RxString erreurSemaine = ''.obs;

  // --- Cours à évaluer ---------------------------------------------------

  final RxList<CoursEvaluable> cours = <CoursEvaluable>[].obs;
  final RxBool chargeCours = true.obs;
  final RxString erreurCours = ''.obs;

  /// UE dont l'avis part vers le serveur, pour n'immobiliser que sa carte.
  final RxnInt envoiEnCours = RxnInt();

  @override
  void onInit() {
    super.onInit();
    rafraichir();
  }

  /// Recharge les deux sections de front : elles ne dépendent pas l'une de
  /// l'autre, les enchaîner ne ferait qu'allonger l'attente.
  Future<void> rafraichir() =>
      Future.wait([chargerSemaine(), chargerCours()]);

  Future<void> chargerSemaine() async {
    chargeSemaine.value = true;
    erreurSemaine.value = '';

    try {
      semaine.value = await _scolarite.emploiDuTemps();
    } on ApiException catch (e) {
      erreurSemaine.value = e.message;
    } catch (_) {
      erreurSemaine.value = 'Ton emploi du temps n’a pas pu être chargé.';
    } finally {
      chargeSemaine.value = false;
    }
  }

  Future<void> chargerCours() async {
    chargeCours.value = true;
    erreurCours.value = '';

    try {
      cours.value = await _scolarite.coursEvaluables();
    } on ApiException catch (e) {
      erreurCours.value = e.message;
    } catch (_) {
      erreurCours.value = 'Tes cours n’ont pas pu être chargés.';
    } finally {
      chargeCours.value = false;
    }
  }

  /// Envoie l'avis de l'étudiant sur un cours.
  ///
  /// La liste locale est mise à jour avec ce que **le serveur** a retenu,
  /// et non avec ce qui a été saisi : lui seul dit ce qui est enregistré.
  /// Renvoie `true` quand l'avis est passé, pour que l'écran ne referme la
  /// feuille de saisie qu'en cas de succès.
  Future<bool> evaluer({
    required CoursEvaluable coursVise,
    required int note,
    String? commentaire,
  }) async {
    envoiEnCours.value = coursVise.id;

    try {
      final avis = await _scolarite.evaluer(
        uniteEnseignementId: coursVise.id,
        note: note,
        commentaire: commentaire,
      );

      final index = cours.indexWhere((c) => c.id == coursVise.id);
      if (index != -1) {
        cours[index] = cours[index].copyWith(monEvaluation: avis);
      }

      Get.snackbar(
        'Merci',
        'Ton avis sur « ${coursVise.nomMatiere} » est enregistré.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return true;
    } on ApiException catch (e) {
      Get.snackbar(
        'Avis non enregistré',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return false;
    } finally {
      envoiEnCours.value = null;
    }
  }

  /// Les jours porteurs de cours, dans l'ordre de la semaine.
  List<String> get joursAvecCours =>
      joursSemaine.where(semaine.containsKey).toList();

  /// Nombre de cours attendant encore un avis, pour la pastille d'onglet.
  int get coursNonEvalues => cours.where((c) => !c.estEvalue).length;
}
