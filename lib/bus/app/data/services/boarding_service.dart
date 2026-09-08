import 'package:get/get.dart';

import '../models/boarding_count.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Billettique côté chauffeur : scan des pass à la montée et confrontation
/// du comptage à l'effectif déclaré (CDC §3.2).
///
/// Contrairement au reste de l'espace chauffeur, ce service parle vraiment
/// au backend : un ticket consommé engage le pass d'un étudiant, il ne peut
/// pas être simulé.
class BoardingService extends GetxService {
  BoardingService({required this.api});

  final ApiClient api;

  /// Identifiant du tour en cours côté backend ; sans lui, aucun scan n'a
  /// de destination.
  final RxnString tourneeId = RxnString();

  final Rx<BoardingCount> count = const BoardingCount().obs;

  /// Étudiants scannés sur le tour, du plus récent au plus ancien.
  final RxList<Map<String, dynamic>> boarded = <Map<String, dynamic>>[].obs;

  final RxList<GapReason> reasons = <GapReason>[].obs;

  final RxBool scanning = false.obs;
  final RxString error = ''.obs;

  /// Rattache le service au tour ouvert et charge son comptage.
  Future<void> attach(String id) async {
    if (tourneeId.value == id) return;

    tourneeId.value = id;
    boarded.clear();
    count.value = const BoardingCount();

    await Future.wait([refreshCount(), loadReasons()]);
  }

  void detach() {
    tourneeId.value = null;
    boarded.clear();
    count.value = const BoardingCount();
  }

  /// Valide un QR scanné : le backend consomme un trajet du pass.
  ///
  /// Rend le résultat en cas de succès, `null` si le titre est refusé —
  /// le motif du refus est alors dans [error].
  Future<ScanResult?> scan(String token) async {
    final id = tourneeId.value;
    if (id == null) {
      error.value = 'Aucun tour en cours : démarrez votre service.';
      return null;
    }

    scanning.value = true;
    error.value = '';

    try {
      final reponse = await api.post('chauffeur/tournees/$id/scanner', {
        'jeton': token,
      });

      final resultat = ScanResult.fromJson(reponse);
      count.value = resultat.count;

      // Un rescan ne crée pas de seconde ligne dans la liste.
      if (!resultat.alreadyBoarded) {
        boarded.insert(0, {
          'nom_complet': resultat.studentName,
          'matricule': resultat.matricule,
          'embarque_le': DateTime.now().toIso8601String(),
        });
      }

      return resultat;
    } on ApiException catch (e) {
      error.value = e.message;
      return null;
    } finally {
      scanning.value = false;
    }
  }

  Future<void> refreshCount() async {
    final id = tourneeId.value;
    if (id == null) return;

    try {
      final reponse = await api.get('chauffeur/tournees/$id/comptage');

      count.value = BoardingCount.fromJson(
        reponse['comptage'] as Map<String, dynamic>? ?? const {},
      );

      boarded.assignAll(
        (reponse['embarquements'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>(),
      );
      error.value = '';
    } on ApiException catch (e) {
      error.value = e.message;
    }
  }

  Future<void> loadReasons() async {
    if (reasons.isNotEmpty) return;

    try {
      final reponse = await api.get('chauffeur/motifs-ecart');

      reasons.assignAll(
        (reponse['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(GapReason.fromJson),
      );
    } on ApiException {
      // Sans le catalogue, la feuille de justification reste fermée :
      // ce n'est pas une raison d'interrompre le tour.
    }
  }

  /// Motive l'écart de comptage ; sans cela, le départ reste bloqué.
  Future<bool> justifyGap(String reason, {String? comment}) async {
    final id = tourneeId.value;
    if (id == null) return false;

    try {
      final reponse = await api.post(
        'chauffeur/tournees/$id/justifier-ecart',
        {
          'motif': reason,
          if (comment != null && comment.isNotEmpty) 'commentaire': comment,
        },
      );

      count.value = BoardingCount.fromJson(
        reponse['comptage'] as Map<String, dynamic>? ?? const {},
      );
      error.value = '';
      return true;
    } on ApiException catch (e) {
      error.value = e.message;
      return false;
    }
  }
}
