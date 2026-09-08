import 'package:get/get.dart';

import 'api_client.dart';
import 'api_exception.dart';
import 'location_service.dart';
import 'osm_service.dart';

/// Un campus où l'étudiant peut pointer, et sa zone de validité.
class CampusPointage {
  const CampusPointage({
    required this.id,
    required this.nom,
    required this.latitude,
    required this.longitude,
    required this.rayon,
  });

  final int id;
  final String nom;
  final double latitude;
  final double longitude;

  /// Rayon de la zone de pointage, en mètres.
  final int rayon;

  factory CampusPointage.fromJson(Map<String, dynamic> json) =>
      CampusPointage(
        id: json['id'] as int,
        nom: json['name'] as String? ?? 'Campus',
        latitude: double.tryParse('${json['latitude']}') ?? 0,
        longitude: double.tryParse('${json['longitude']}') ?? 0,
        rayon: int.tryParse('${json['radius']}') ?? 100,
      );
}

/// Le pointage de présence de l'étudiant : arrivée sur le campus et départ.
///
/// Les routes vivent sous `/api`, celles d'Estuaire RH : le pointage est le
/// même geste pour l'étudiant et pour l'enseignant, et c'est ce backend-là
/// qui tient les présences. Le chemin absolu passé au client dit ce
/// voisinage — voir `ApiClient._uri`, comme pour `ScolariteService`.
class PresenceService extends GetxService {
  PresenceService({required this.api, required this.location});

  final ApiClient api;
  final LocationService location;

  static const String _campuses = '/api/campuses/my-campuses';
  static const String _statut = '/api/attendance/current-status';
  static const String _checkIn = '/api/attendance/check-in';
  static const String _checkOut = '/api/attendance/check-out';

  /// Vrai quand un pointage est ouvert : le prochain geste est un départ.
  final RxBool presenceOuverte = false.obs;

  /// Campus du pointage en cours, `null` hors présence.
  final RxnInt campusActif = RxnInt();

  /// Campus rattachés à l'étudiant ; le premier sert de cible par défaut.
  final RxList<CampusPointage> campuses = <CampusPointage>[].obs;

  final RxBool chargement = false.obs;

  /// Vrai pendant l'envoi d'un pointage, pour bloquer un double appui.
  final RxBool envoiEnCours = false.obs;

  /// Motif d'indisponibilité affichable ; vide si tout va bien.
  final RxString erreur = ''.obs;

  CampusPointage? get campusCible {
    if (campuses.isEmpty) return null;

    final actif = campusActif.value;
    if (actif == null) return campuses.first;

    return campuses.firstWhereOrNull((c) => c.id == actif) ?? campuses.first;
  }

  @override
  void onInit() {
    super.onInit();
    rafraichir();
  }

  /// Recharge les campus et l'état du pointage.
  ///
  /// Un étudiant sans campus rattaché n'est pas une erreur : la carte se
  /// tait alors, plutôt que d'annoncer une panne.
  Future<void> rafraichir() async {
    chargement.value = true;
    erreur.value = '';

    try {
      await Future.wait([_chargerCampuses(), _chargerStatut()]);
    } on ApiException catch (e) {
      erreur.value = e.message;
    } finally {
      chargement.value = false;
    }
  }

  Future<void> _chargerCampuses() async {
    final reponse = await api.get(_campuses);
    final donnees = reponse['campuses'];

    if (donnees is! List) return;

    campuses.assignAll(
      donnees.whereType<Map<String, dynamic>>().map(CampusPointage.fromJson),
    );
  }

  Future<void> _chargerStatut() async {
    final reponse = await api.get(_statut);

    presenceOuverte.value = reponse['has_active_checkin'] == true;

    final actifs = reponse['active_checkins'];
    campusActif.value = actifs is List && actifs.isNotEmpty
        ? (actifs.first as Map)['campus_id'] as int?
        : null;
  }

  /// Distance au campus cible en mètres, `null` sans position ni campus.
  double? get distanceAuCampus {
    final campus = campusCible;
    final position = location.current.value;
    if (campus == null || position == null) return null;

    return LocationService.distanceBetween(
      position,
      GeoPoint(campus.latitude, campus.longitude),
    );
  }

  /// Vrai quand l'étudiant est dans la zone du campus.
  ///
  /// Une marge s'ajoute au rayon : un relevé de téléphone porte facilement
  /// vingt mètres d'erreur, et bloquer le bouton ferait échouer un étudiant
  /// réellement sur place. Le backend reste seul juge — il refusera un
  /// pointage hors zone que cette marge aurait laissé partir.
  bool get dansLaZone {
    final campus = campusCible;
    final distance = distanceAuCampus;
    if (campus == null || distance == null) return false;

    return distance <= campus.rayon + _margeGps;
  }

  /// Tolérance ajoutée au rayon, en mètres.
  static const double _margeGps = 25;

  /// Pointe l'arrivée ou le départ, selon l'état courant.
  ///
  /// Rend le message à afficher, ou `null` si rien n'a été tenté.
  Future<String?> pointer() async {
    final campus = campusCible;
    if (campus == null || envoiEnCours.value) return null;

    envoiEnCours.value = true;

    try {
      // Une position fraîche plutôt que la dernière connue : le backend
      // recalcule la zone, et un relevé périmé le ferait refuser.
      final position = await location.refresh() ?? location.current.value;

      if (position == null) {
        return 'Position introuvable. Active le GPS et réessaie.';
      }

      final corps = {
        'campus_id': campus.id,
        'latitude': position.lat,
        'longitude': position.lng,
      };

      final reponse = await api.post(
        presenceOuverte.value ? _checkOut : _checkIn,
        corps,
      );

      await _chargerStatut();

      return reponse['message'] as String? ??
          (presenceOuverte.value ? 'Arrivée enregistrée' : 'Départ enregistré');
    } on ApiException catch (e) {
      return e.message;
    } finally {
      envoiEnCours.value = false;
    }
  }
}
