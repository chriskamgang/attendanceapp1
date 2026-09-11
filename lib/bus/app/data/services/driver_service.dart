import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/breakdown_report.dart';
import '../models/driver_bonus.dart';
import '../models/driver_tour.dart';
import '../models/tour_stage.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'boarding_service.dart';
import 'location_service.dart';
import 'osm_service.dart';

/// Alimente l'espace chauffeur : cycle de pointage, effectifs, cagnotte,
/// pannes et missions de secours (CDC §3.2, §3.3, §3.4).
///
/// Tout passe par le backend : le pointage engage la paie du chauffeur et
/// la position affichée aux étudiants, rien n'est décidé localement. Le
/// contrôle de zone lui-même est tranché côté serveur — l'application ne
/// fait qu'annoncer la distance restante pour éviter un appui perdu.
class DriverService extends GetxService {
  DriverService({
    required this.api,
    required this.location,
    required this.boarding,
  });

  final ApiClient api;
  final LocationService location;
  final BoardingService boarding;

  final OsmService _osm = Get.find<OsmService>();

  /// Rayon indicatif tant que le backend n'a pas donné celui de l'arrêt.
  static const double geofenceRadiusMeters = 150;

  /// Cadence du battement de présence, tour ouvert ou non.
  ///
  /// Quinze secondes suivent un bus urbain d'assez près sans vider la
  /// batterie ; le serveur tolère une minute de silence avant de retirer
  /// le bus de la carte.
  static const Duration _presenceInterval = Duration(seconds: 15);

  final Rxn<DriverTour> tour = Rxn<DriverTour>();

  /// Tours déjà clos aujourd'hui, du plus récent au plus ancien.
  final RxList<DriverTour> completedTours = <DriverTour>[].obs;

  final Rx<DriverBonus> bonus = const DriverBonus.empty().obs;

  /// Pannes déclarées par ce chauffeur.
  final RxList<BreakdownReport> breakdowns = <BreakdownReport>[].obs;

  /// Missions de secours proposées par la régulation.
  final RxList<RescueMission> missions = <RescueMission>[].obs;

  final RxBool loading = false.obs;

  /// Dernier message d'erreur remonté par le backend, à afficher tel quel.
  final RxString error = ''.obs;

  /// Affectation du jour : ligne, bus et tours prévus.
  final RxString lineName = ''.obs;
  final RxString busPlate = ''.obs;
  final RxInt busCapacity = 0.obs;
  final RxInt toursPlanned = 0.obs;
  final RxInt toursDone = 0.obs;

  /// Vrai quand aucune affectation n'existe pour aujourd'hui : le chauffeur
  /// n'a alors rien à pointer, et l'écran doit le dire plutôt que d'offrir
  /// un bouton qui échouera.
  final RxBool hasAssignment = false.obs;

  /// Position réelle du bus — celle de l'appareil du chauffeur.
  Rxn<GeoPoint> get busPosition => location.current;

  /// Cap du bus en degrés depuis le nord, GPS et boussole confondus : c'est
  /// lui qui fait pivoter le marqueur sur la carte.
  RxnDouble get bearing => location.bearing;

  /// Vitesse instantanée en km/h, telle que relevée par le GPS.
  RxnInt get speedKmh => location.speedKmh;

  /// Vrai quand le flux de positions est ouvert : la carte s'en sert pour
  /// distinguer « GPS pas encore prêt » de « position en cours d'acquisition ».
  RxBool get tracking => location.tracking;

  /// Motif d'indisponibilité du GPS, vide si tout va bien.
  ///
  /// Ne vaut que tant qu'aucun point n'a été obtenu : une fois le bus situé,
  /// une erreur passagère ne doit pas effacer la carte sous les yeux du
  /// chauffeur.
  String get locationError =>
      busPosition.value == null ? location.error.value : '';

  /// Redemande la permission et relance le suivi, après un refus levé dans
  /// les réglages du téléphone.
  Future<void> retryLocation() async {
    _log('nouvelle tentative d’accès au GPS');

    if (await location.ensureReady()) {
      await location.startTracking();
      unawaited(_pushPresence());
    }
  }

  final RxList<GeoPoint> routePoints = <GeoPoint>[].obs;
  final Rxn<GeoPoint> stopPosition = Rxn<GeoPoint>();
  final Rxn<GeoPoint> campusPosition = Rxn<GeoPoint>();

  /// Rayon de validation de l'étape courante, tel que défini par le lieu.
  final RxDouble targetRadius = geofenceRadiusMeters.obs;

  /// Distance courante à la cible de l'étape, en mètres ; `null` tant
  /// qu'un des deux points manque — mieux vaut ne rien annoncer qu'un
  /// chiffre de repli que le chauffeur prendrait pour une mesure.
  final RxnDouble distance = RxnDouble();

  /// Distance affichable, repli compris, pour les vues qui exigent un
  /// nombre.
  double get distanceToTargetOrFar => distance.value ?? double.infinity;

  Timer? _presenceTicker;
  StreamSubscription<GeoPoint?>? _positionWatch;

  /// Vrai quand le dernier battement a été accepté par le serveur.
  final RxBool online = false.obs;

  /// Vrai quand la position est réellement diffusée aux étudiants, ce qui
  /// suppose une affectation du jour : en ligne sans bus, personne ne voit
  /// le chauffeur sur la carte.
  final RxBool broadcasting = false.obs;

  /// Vrai quand le chauffeur s'est lui-même mis hors ligne.
  ///
  /// Le distinguer d'une simple absence de battement est indispensable :
  /// sans ce drapeau, le premier rafraîchissement le remettrait en ligne
  /// à son insu, et sa pause n'en serait pas une.
  final RxBool offlineByChoice = false.obs;

  int get toursDoneToday => toursDone.value;

  /// Nombre de tours prévus aujourd'hui, tel qu'affecté par la régulation.
  int get toursPlannedToday => toursPlanned.value;

  int get pendingMissionCount =>
      missions.where((m) => m.stage == MissionStage.assigned).length;

  /// Vrai si le chauffeur est dans la zone de validation de l'étape.
  ///
  /// Indicatif seulement : le backend reste juge, et refusera l'étape s'il
  /// en décide autrement.
  bool get isInZone {
    final d = distance.value;
    return d != null && d <= targetRadius.value;
  }

  /// Le bouton de l'étape courante est-il actionnable ?
  bool get canAdvance {
    final current = tour.value;
    if (current == null) return false;
    if (loading.value) return false;

    // Le départ reste bloqué tant que l'écart de comptage n'est pas motivé.
    if (current.stage == TourStage.headcountDone && current.departureBlocked) {
      return false;
    }

    if (!current.stage.requiresGeofence) return true;

    // Sans position ni cible connue, on laisse tenter : le backend
    // tranchera, et le chauffeur aura un message clair plutôt qu'un
    // bouton mort qui ne se déverrouillerait jamais.
    if (busPosition.value == null || distance.value == null) return true;

    return isInZone;
  }

  /// Message affiché quand le bouton est verrouillé.
  String get lockReason {
    final current = tour.value;
    if (current == null) return '';

    if (current.stage == TourStage.headcountDone && current.departureBlocked) {
      final n = current.withoutTicket;
      return '$n passager${n > 1 ? 's' : ''} sans ticket : justifie l’écart '
          'avant de partir.';
    }

    if (canAdvance) return '';

    if (!location.available.value && location.error.value.isNotEmpty) {
      return location.error.value;
    }

    final target = current.stage.targetsTerminus
        ? (current.terminusName.isEmpty ? 'campus' : current.terminusName)
        : current.pickupName.isEmpty
        ? 'point de ramassage'
        : current.pickupName;

    final metres = distance.value;

    if (metres == null) {
      return busPosition.value == null
          ? 'Position en cours d’acquisition…'
          : 'Position du $target inconnue : le serveur validera l’étape.';
    }

    return 'Approche-toi du $target pour valider (${metres.round()} m)';
  }

  @override
  void onInit() {
    super.onInit();

    // La distance se recalcule à chaque relevé, sans attendre un tick.
    _positionWatch = busPosition.listen((_) => _updateDistance());

    refreshAll();
  }

  /// Recharge l'état complet de la journée.
  Future<void> refreshAll() async {
    loading.value = true;
    error.value = '';

    // La position conditionne le pointage et alimente le suivi des
    // étudiants : on la demande dès l'ouverture, et le chauffeur passe en
    // ligne dans la foulée — sans attendre qu'un tour soit démarré.
    unawaited(
      location.ensureReady().then((ok) {
        if (ok) location.startTracking();
      }),
    );

    _startPresence();

    try {
      await _loadServiceOfDay();
      await Future.wait([_loadBonus(), _loadMissions()]);
    } on ApiException catch (e) {
      error.value = e.message;
    } finally {
      loading.value = false;
    }
  }

  /// Lit l'affectation du jour et le tour éventuellement ouvert.
  Future<void> _loadServiceOfDay() async {
    final reponse = await api.get('chauffeur/service-du-jour');

    final affectation = reponse['affectation'] as Map<String, dynamic>?;

    if (affectation == null) {
      hasAssignment.value = false;
      tour.value = null;
      lineName.value = '';
      busPlate.value = '';
      toursPlanned.value = 0;
      toursDone.value = 0;
      boarding.detach();
      return;
    }

    hasAssignment.value = true;

    final ligne = affectation['ligne'] as Map<String, dynamic>?;
    final bus = affectation['bus'] as Map<String, dynamic>?;

    lineName.value = ligne?['nom'] as String? ?? '';
    busPlate.value = bus?['immatriculation'] as String? ?? '';
    busCapacity.value = (bus?['capacite'] as num?)?.toInt() ?? 0;
    toursPlanned.value = (reponse['tours_prevus'] as num?)?.toInt() ?? 0;
    toursDone.value = (reponse['tours_realises'] as num?)?.toInt() ?? 0;

    final enCours = reponse['tournee_en_cours'] as Map<String, dynamic>?;

    if (enCours == null) {
      // Aucun tour ouvert : le prochain reste à démarrer.
      tour.value = DriverTour(
        id: null,
        index: toursDone.value + 1,
        lineName: lineName.value,
        pickupName: '',
        stage: TourStage.offline,
        expectedMinutes:
            (ligne?['duree_trajet_minutes'] as num?)?.toInt() ?? 25,
        busPlate: busPlate.value,
        busCapacity: busCapacity.value,
      );
      boarding.detach();
    } else {
      _adoptTour(
        DriverTour.fromApi(
          enCours,
          lineName: lineName.value,
          expectedMinutes:
              (ligne?['duree_trajet_minutes'] as num?)?.toInt() ?? 25,
        ),
      );
    }

    await _loadRoute();
  }

  /// Prend en compte un tour renvoyé par le backend.
  void _adoptTour(DriverTour incoming) {
    tour.value = incoming;
    _adoptPickupFromTour(incoming);

    final id = incoming.id;

    if (id != null && !incoming.isDone) {
      // La billettique se rattache au tour ouvert : sans cela, aucun scan
      // n'a de destination.
      unawaited(boarding.attach('$id'));
    } else {
      boarding.detach();
    }

    if (incoming.isDone && !completedTours.any((t) => t.id == incoming.id)) {
      completedTours.insert(0, incoming);
    }

    _updateDistance();
  }

  /// Adopte les coordonnées d'arrêt portées par le tour lui-même.
  ///
  /// C'est la même vérité que le backend applique pour le contrôle de
  /// zone : s'en servir évite d'attendre le catalogue des lieux, et donc
  /// d'afficher une distance de repli le temps qu'il arrive.
  void _adoptPickupFromTour(DriverTour tour) {
    final lat = tour.pickupLat;
    final lng = tour.pickupLng;

    if (lat != null && lng != null) {
      stopPosition.value = GeoPoint(lat, lng);

      final radius = tour.pickupRadius;
      if (radius != null && tour.pickupName.isNotEmpty) {
        _radiusByName[tour.pickupName.toLowerCase()] = radius;
      }
    }

    // Le terminus commande la clôture du tour, et donc la prime : sa
    // position vaut d'être connue dès l'ouverture.
    final finLat = tour.terminusLat;
    final finLng = tour.terminusLng;

    if (finLat != null && finLng != null) {
      campusPosition.value = GeoPoint(finLat, finLng);
      _campusName = tour.terminusName;

      final radius = tour.terminusRadius;
      if (radius != null && tour.terminusName.isNotEmpty) {
        _radiusByName[tour.terminusName.toLowerCase()] = radius;
      }
    }
  }

  /// Situe l'arrêt et le terminus, et trace la ligne entre les deux.
  Future<void> _loadRoute() async {
    final pickup = tour.value?.pickupName ?? '';
    if (pickup.isEmpty) return;

    // Le catalogue du réseau porte les coordonnées exactes des lieux, avec
    // leur rayon de validation : c'est la même vérité que le backend
    // applique, contrairement à un géocodage approximatif.
    try {
      final reponse = await api.get('lieux');
      final lieux = (reponse['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

      Map<String, dynamic>? parNom(String nom) {
        for (final lieu in lieux) {
          if ((lieu['nom'] as String?)?.toLowerCase() == nom.toLowerCase()) {
            return lieu;
          }
        }
        return null;
      }

      GeoPoint? point(Map<String, dynamic>? lieu) {
        final lat = (lieu?['latitude'] as num?)?.toDouble();
        final lng = (lieu?['longitude'] as num?)?.toDouble();
        return (lat == null || lng == null) ? null : GeoPoint(lat, lng);
      }

      final arret = parNom(pickup);
      stopPosition.value = point(arret);

      // Le terminus n'est pas nommé par la ressource du tour : le premier
      // campus du catalogue en tient lieu pour l'affichage de la carte.
      final campus = lieux.firstWhereOrNull((lieu) => lieu['type'] == 'campus');
      campusPosition.value = point(campus);

      _radiusByName[pickup.toLowerCase()] =
          (arret?['rayon_validation_metres'] as num?)?.toDouble() ??
          geofenceRadiusMeters;

      final campusNom = (campus?['nom'] as String?)?.toLowerCase();
      if (campusNom != null) {
        _radiusByName[campusNom] =
            (campus?['rayon_validation_metres'] as num?)?.toDouble() ??
            geofenceRadiusMeters;
      }
      _campusName = campus?['nom'] as String? ?? '';
    } on ApiException {
      // Sans le catalogue, la carte reste vide mais le pointage demeure
      // possible : c'est le backend qui juge de la zone.
      return;
    }

    final from = stopPosition.value;
    final to = campusPosition.value;
    if (from == null || to == null) return;

    final path = await _osm.route(from, to);
    routePoints.assignAll(
      path != null && path.points.isNotEmpty ? path.points : [from, to],
    );

    _updateDistance();
  }

  final Map<String, double> _radiusByName = {};
  String _campusName = '';

  /// Cible géographique de l'étape en cours : l'arrêt tant que le bus n'a
  /// pas embarqué, le campus une fois en transit.
  GeoPoint? get _targetPoint {
    final current = tour.value;
    if (current == null) return null;
    return current.stage.targetsTerminus
        ? campusPosition.value
        : stopPosition.value;
  }

  void _updateDistance() {
    final current = tour.value;
    final from = busPosition.value;
    final to = _targetPoint;

    if (current != null) {
      final nom = current.stage.targetsTerminus
          ? _campusName.toLowerCase()
          : current.pickupName.toLowerCase();
      targetRadius.value = _radiusByName[nom] ?? geofenceRadiusMeters;
    }

    if (from == null || to == null) {
      distance.value = null;
      return;
    }
    distance.value = LocationService.distanceBetween(from, to);
  }

  // --- Présence en ligne (CDC §3.1 — suivi en direct) -------------------
  //
  // Le chauffeur diffuse sa position dès l'ouverture de l'application, sans
  // attendre d'avoir démarré un tour : les étudiants voient ainsi le bus
  // stationné au dépôt aussi bien que le bus en circulation. Le backend
  // déduit lui-même le bus et le tour de l'affectation du jour.

  void _startPresence() {
    if (_presenceTicker != null) return;

    _log(
      'présence ouverte, battement toutes les '
      '${_presenceInterval.inSeconds} s',
    );

    _presenceTicker = Timer.periodic(
      _presenceInterval,
      (_) => unawaited(_pushPresence()),
    );

    // Le premier battement part sans attendre le tick : le bus doit
    // apparaître sur la carte dès l'ouverture, pas quinze secondes après.
    unawaited(_pushPresence());
  }

  void _stopPresence() {
    _presenceTicker?.cancel();
    _presenceTicker = null;
  }

  /// Annonce la position courante au backend, qui la diffuse aux étudiants.
  ///
  /// La position est facultative : le premier battement part souvent avant
  /// que le GPS n'ait fixé de point, et vaut alors simple signe de vie.
  Future<void> _pushPresence() async {
    final point = busPosition.value;

    try {
      final reponse = await api.post('chauffeur/presence', {
        if (point != null) 'latitude': point.lat,
        if (point != null) 'longitude': point.lng,
        if (location.speedKmh.value != null)
          'vitesse_kmh': location.speedKmh.value,
        if (location.headingDegrees.value != null)
          'cap_degres': location.headingDegrees.value,
      });

      final etaitEnLigne = online.value;
      final diffusaitAvant = broadcasting.value;

      online.value = reponse['en_ligne'] == true;

      // Sans affectation du jour, le chauffeur est connecté mais invisible :
      // l'écran doit pouvoir le dire plutôt que de laisser croire à une
      // diffusion qui n'a pas lieu.
      broadcasting.value = reponse['diffuse'] == true;

      _log(
        'battement ${point == null ? 'sans position' : '${point.lat.toStringAsFixed(5)},'
                  '${point.lng.toStringAsFixed(5)}'} · '
        'cap ${location.bearing.value?.round() ?? '—'}° · '
        'en ligne=${online.value} · diffusé=${broadcasting.value}',
      );

      if (etaitEnLigne != online.value ||
          diffusaitAvant != broadcasting.value) {
        _log(
          'état de présence changé : en ligne=${online.value}, '
          'diffusé=${broadcasting.value}',
        );
      }
    } on ApiException catch (e) {
      // Un battement perdu ne coupe pas la diffusion : le délai de grâce du
      // serveur couvre plusieurs échecs, et le suivant repartira.
      online.value = false;
      _log('battement refusé : ${e.message}');
    }
  }

  /// Retire le bus de la carte des étudiants.
  ///
  /// Appelée à la déconnexion, et par le bouton de pause de la carte. Une
  /// application simplement fermée n'appelle rien : le délai de grâce du
  /// serveur s'en charge.
  ///
  /// [parChoix] marque une pause volontaire du chauffeur, que les
  /// rafraîchissements suivants respecteront ; la déconnexion, elle, n'a
  /// pas à laisser de trace puisque la session disparaît.
  Future<void> goOffline({bool parChoix = false}) async {
    _stopPresence();

    if (parChoix) {
      offlineByChoice.value = true;

      // Le GPS n'a plus rien à alimenter : le couper préserve la batterie
      // du chauffeur, qui roule souvent la journée entière.
      await location.stopTracking();
    }

    try {
      await api.delete('chauffeur/presence');
    } on ApiException catch (e) {
      // Le serveur oubliera de lui-même la présence passé le délai.
      _log('fermeture de présence refusée : ${e.message}');
    }

    online.value = false;
    broadcasting.value = false;
    _log(
      'présence fermée${parChoix ? ' à la demande du chauffeur' : ''}, '
      'le bus quitte la carte des étudiants',
    );
  }

  /// Remet le bus sur la carte des étudiants après une pause.
  Future<void> goOnline() async {
    offlineByChoice.value = false;
    _log('reprise de la diffusion demandée');

    if (await location.ensureReady()) {
      await location.startTracking();
    }

    _startPresence();
  }

  /// Bascule la diffusion, pour le bouton de la carte.
  Future<void> togglePresence() =>
      offlineByChoice.value ? goOnline() : goOffline(parChoix: true);

  void _log(String message) {
    if (kDebugMode) debugPrint('[chauffeur] $message');
  }

  /// Coordonnées à joindre à un pointage.
  ///
  /// Le backend les exige : sans position, l'étape ne part pas.
  Future<Map<String, dynamic>?> _coords() async {
    final point = busPosition.value ?? await location.refresh();

    if (point == null) {
      error.value = location.error.value.isNotEmpty
          ? location.error.value
          : 'Position indisponible : impossible de valider cette étape.';
      return null;
    }

    return {'latitude': point.lat, 'longitude': point.lng};
  }

  // --- Cycle de pointage (CDC §3.2) ------------------------------------

  /// 1. Démarrage service : ouvre un tour et diffuse la position.
  ///
  /// Le suivi continu démarre ici même : c'est à partir de cet instant que
  /// la position part aux étudiants à chaque déplacement, et non plus au
  /// seul rythme du battement de présence.
  Future<bool> startService() async {
    _log('démarrage du service demandé');

    final ok = await _step(() async {
      final coords = await _coords();
      if (coords == null) return null;

      return api.post('chauffeur/tournees/demarrer', coords);
    });

    if (ok) {
      // Démarrer un tour lève la pause : on ne roule pas en service tout
      // en restant invisible des étudiants.
      offlineByChoice.value = false;

      await location.startTracking();
      _startPresence();

      // Le premier battement part sans attendre le tick : le bus doit
      // apparaître en ligne dès la bascule sur la carte.
      unawaited(_pushPresence());
      _log('service démarré, diffusion en continu ouverte');
    } else {
      _log('démarrage refusé : ${error.value}');
    }

    return ok;
  }

  /// 2. Arrivée au point de ramassage.
  Future<bool> markArrivedAtPickup() async {
    final id = tour.value?.id;
    if (id == null) return false;

    return _step(() async {
      final coords = await _coords();
      if (coords == null) return null;

      return api.post('chauffeur/tournees/$id/arrivee-point', coords);
    });
  }

  /// 3. Saisie de l'effectif embarqué.
  Future<bool> submitHeadcount(int count) async {
    final id = tour.value?.id;
    if (id == null || count < 0) return false;

    return _step(() async {
      final coords = await _coords();
      if (coords == null) return null;

      return api.post('chauffeur/tournees/$id/effectif', {
        ...coords,
        'effectif': count,
      });
    });
  }

  /// Corrige l'effectif tant que le bus n'a pas quitté l'arrêt.
  ///
  /// Le backend n'accepte qu'une saisie par tour : la correction passe donc
  /// par le même appel, qu'il refusera si l'étape est déjà pointée.
  Future<bool> updateHeadcount(int count) => submitHeadcount(count);

  /// 4. Départ vers le campus : le bus passe « En transit ».
  Future<bool> departToCampus() async {
    final id = tour.value?.id;
    if (id == null) return false;

    return _step(() async {
      final coords = await _coords();
      if (coords == null) return null;

      return api.post('chauffeur/tournees/$id/depart', coords);
    });
  }

  /// 5. Arrivée au campus : le tour est validé et la prime créditée.
  Future<bool> finishTour() async {
    final id = tour.value?.id;
    if (id == null) return false;

    final ok = await _step(() async {
      final coords = await _coords();
      if (coords == null) return null;

      return api.post('chauffeur/tournees/$id/terminer', coords);
    });

    if (ok) {
      // La prime vient d'être créditée : la cagnotte affichée doit suivre.
      await Future.wait([_loadBonus(), _refreshCounters()]);
    }

    return ok;
  }

  /// Ouvre le tour suivant de la journée.
  ///
  /// Rien n'est créé ici : le tour naîtra du prochain démarrage de service.
  Future<void> startNextTour() async {
    await _refreshCounters();

    tour.value = DriverTour(
      id: null,
      index: toursDone.value + 1,
      lineName: lineName.value,
      pickupName: tour.value?.pickupName ?? '',
      stage: TourStage.offline,
      expectedMinutes: tour.value?.expectedMinutes ?? 25,
      busPlate: busPlate.value,
      busCapacity: busCapacity.value,
    );

    boarding.detach();
  }

  /// Exécute une étape de pointage et adopte le tour renvoyé.
  ///
  /// Toute la gestion d'erreur est centralisée ici : un refus du backend
  /// (hors zone, séquence rompue, écart non justifié) laisse l'état local
  /// intact et remonte son message tel quel.
  Future<bool> _step(Future<Map<String, dynamic>?> Function() call) async {
    loading.value = true;
    error.value = '';

    try {
      final reponse = await call();
      if (reponse == null) return false;

      final data = reponse['tournee'] as Map<String, dynamic>?;
      if (data != null) {
        _adoptTour(
          DriverTour.fromApi(
            data,
            lineName: lineName.value,
            pickupName: tour.value?.pickupName ?? '',
            expectedMinutes: tour.value?.expectedMinutes ?? 25,
          ),
        );

        // Le premier tour découvre son arrêt : la carte suit.
        if (stopPosition.value == null) await _loadRoute();
      }

      return true;
    } on ApiException catch (e) {
      error.value = e.message;
      return false;
    } finally {
      loading.value = false;
    }
  }

  /// Rafraîchit les compteurs de la journée sans toucher au tour courant.
  Future<void> _refreshCounters() async {
    try {
      final reponse = await api.get('chauffeur/service-du-jour');
      toursDone.value = (reponse['tours_realises'] as num?)?.toInt() ?? 0;
      toursPlanned.value = (reponse['tours_prevus'] as num?)?.toInt() ?? 0;
    } on ApiException {
      // Les compteurs se remettront d'aplomb au prochain rafraîchissement.
    }
  }

  /// Rejoue le comptage depuis la billettique, après un scan ou une
  /// justification d'écart : le blocage du départ en dépend.
  Future<void> syncBoardingCount() async {
    await boarding.refreshCount();

    final current = tour.value;
    if (current == null) return;

    final count = boarding.count.value;
    tour.value = current.copyWith(
      scanned: count.validated,
      withoutTicket: count.withoutTicket,
      gapJustified: count.justified,
    );
  }

  // --- Cagnotte (CDC §3.3) ---------------------------------------------

  Future<void> _loadBonus() async {
    try {
      final reponse = await api.get('chauffeur/cagnotte');

      bonus.value = DriverBonus.fromApi(
        reponse,
        toursPlanned: toursPlanned.value,
        punctualityRate: 1,
      );
    } on ApiException catch (e) {
      error.value = e.message;
    }
  }

  Future<void> refreshBonus() => _loadBonus();

  // --- Pannes et missions de secours (CDC §3.3) -------------------------

  Future<void> _loadMissions() async {
    try {
      final reponse = await api.get('chauffeur/missions');

      missions.assignAll(
        (reponse['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RescueMission.fromApi),
      );
    } on ApiException catch (e) {
      error.value = e.message;
    }
  }

  /// Signale un retard aux étudiants desservis (US-04).
  ///
  /// Le chauffeur est le seul à savoir s'il est pris dans un embouteillage
  /// ou retenu au dépôt : c'est lui qui déclenche l'alerte, avec son motif.
  Future<bool> declareDelay({required int minutes, String reason = ''}) async {
    final id = tour.value?.id;
    if (id == null) {
      error.value = 'Aucun tour en cours : il n’y a pas de retard à signaler.';
      return false;
    }

    loading.value = true;
    error.value = '';

    try {
      await api.post('chauffeur/tournees/$id/retard', {
        'minutes': minutes,
        if (reason.isNotEmpty) 'motif': reason,
      });
      return true;
    } on ApiException catch (e) {
      error.value = e.message;
      return false;
    } finally {
      loading.value = false;
    }
  }

  /// Déclare une panne : la régulation et les étudiants sont alertés.
  Future<bool> declareBreakdown({
    required BreakdownKind kind,
    required int studentsOnBoard,
    String note = '',
  }) async {
    loading.value = true;
    error.value = '';

    try {
      final coords = await _coords();
      if (coords == null) return false;

      final reponse = await api.post('chauffeur/pannes', {
        ...coords,
        if (tour.value?.id != null) 'tournee_id': tour.value!.id,
        'type_panne': kind.apiValue,
        'passagers_immobilises': studentsOnBoard,
        if (note.isNotEmpty) 'description': note,
      });

      final panne = reponse['panne'] as Map<String, dynamic>?;
      if (panne != null) {
        breakdowns.insert(0, BreakdownReport.fromApi(panne));
      }

      return true;
    } on ApiException catch (e) {
      error.value = e.message;
      return false;
    } finally {
      loading.value = false;
    }
  }

  Future<bool> acceptMission(String id) =>
      _mission('chauffeur/missions/$id/accepter');

  Future<bool> startMission(String id) =>
      _mission('chauffeur/missions/$id/demarrer');

  /// Clôture la mission ; la prime dépend de la prise en charge effective.
  Future<bool> finishMission(
    String id, {
    required int rescued,
    bool breakdownConfirmed = true,
  }) async {
    final ok = await _mission('chauffeur/missions/$id/terminer', {
      'passagers_recuperes': rescued,
      'panne_confirmee': breakdownConfirmed,
    });

    if (ok) await _loadBonus();
    return ok;
  }

  Future<bool> _mission(String path, [Map<String, dynamic>? body]) async {
    loading.value = true;
    error.value = '';

    try {
      final reponse = await api.post(path, body);

      final mission = reponse['mission'] as Map<String, dynamic>?;
      if (mission != null) {
        final maj = RescueMission.fromApi(mission);
        final index = missions.indexWhere((m) => m.id == maj.id);
        if (index >= 0) {
          missions[index] = maj;
        } else {
          missions.insert(0, maj);
        }
      }

      return true;
    } on ApiException catch (e) {
      error.value = e.message;
      return false;
    } finally {
      loading.value = false;
    }
  }

  /// Refuse une mission : elle disparaît de la liste du chauffeur.
  ///
  /// Le backend ne propose pas de refus explicite — la régulation
  /// réaffecte d'elle-même une mission non acceptée.
  void declineMission(String id) => missions.removeWhere((m) => m.id == id);

  @override
  void onClose() {
    _stopPresence();
    _positionWatch?.cancel();
    location.stopTracking();
    super.onClose();
  }
}
