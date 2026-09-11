import 'dart:async';

import 'package:get/get.dart';

import '../models/app_notification.dart';
import '../models/bus_tracking.dart';
import '../models/online_bus.dart';
import '../models/pass_qr.dart';
import '../models/student_pass.dart';
import '../models/trip_entry.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'notification_service.dart';
import 'osm_service.dart';
import 'realtime_service.dart';

/// Alimente l'espace étudiant : suivi du bus, pass, trajets, alertes.
///
/// Chaque section porte son propre indicateur de chargement et son propre
/// message d'erreur : un incident sur les trajets ne doit pas vider
/// l'accueil.
class StudentService extends GetxService {
  StudentService({
    required this.api,
    OsmService? osm,
    NotificationService? notifications,
    this.realtime,
  }) : _osm = osm ?? Get.find<OsmService>(),
       _notifications = notifications ?? Get.find<NotificationService>();

  final ApiClient api;
  final OsmService _osm;

  /// Diffusion temps réel de la position, quand le serveur la propose.
  ///
  /// Elle vient en complément du sondage, jamais à sa place : sans elle
  /// l'écran reste alimenté, simplement moins vite.
  final RealtimeService? realtime;

  /// Boîte partagée avec l'espace chauffeur : l'espace étudiant n'en tient
  /// pas une copie, il l'expose.
  final NotificationService _notifications;

  /// Rythme d'actualisation du suivi tant que l'écran est ouvert.
  static const Duration _periodeSuivi = Duration(seconds: 15);

  /// Rythme allégé quand la position arrive en direct : le sondage ne sert
  /// plus qu'à rattraper ce que la diffusion aurait manqué.
  static const Duration _periodeSuiviDirect = Duration(seconds: 45);

  // --- Suivi du bus -----------------------------------------------------

  final Rxn<BusTracking> tracking = Rxn<BusTracking>();
  final RxBool loadingTracking = false.obs;

  /// Message renvoyé par le backend quand aucun bus ne circule.
  final RxString trackingMessage = ''.obs;
  final RxString trackingError = ''.obs;

  // --- Flotte en ligne --------------------------------------------------

  /// Bus actuellement en ligne, stationnés comme en circulation.
  ///
  /// Alimentés par `bus-en-ligne` puis tenus à jour par le canal « flotte » :
  /// l'étudiant voit tout bus dont le chauffeur a ouvert son application,
  /// sans attendre qu'un tour soit démarré.
  final RxList<OnlineBus> onlineBuses = <OnlineBus>[].obs;

  /// Tracé routier du parcours, calculé par OSRM.
  ///
  /// Sans lui, la carte relierait les arrêts en ligne droite ; le tracé
  /// suit les routes réelles.
  final RxList<GeoPoint> routePolyline = <GeoPoint>[].obs;

  // --- Pass -------------------------------------------------------------

  /// Pass dont l'étudiant dispose : il peut en détenir plusieurs de
  /// natures différentes, qui coexistent sans se confondre.
  final RxList<StudentPass> passes = <StudentPass>[].obs;

  /// Total des trajets utilisables, tous pass confondus.
  final RxInt totalTrips = 0.obs;

  final Rxn<StudentPass> pass = Rxn<StudentPass>();
  final RxList<PassTarif> tarifs = <PassTarif>[].obs;
  final RxList<StudentPass> passHistory = <StudentPass>[].obs;
  final RxBool loadingPass = false.obs;
  final RxString passError = ''.obs;

  // --- QR du pass -------------------------------------------------------

  /// Jeton présenté au chauffeur. Il expire vite : l'écran du pass le
  /// renouvelle tant qu'il est ouvert, et l'oublie en le quittant.
  final Rxn<PassQr> qr = Rxn<PassQr>();

  /// Un QR par pass utilisable : l'étudiant montre celui qu'il choisit.
  final RxList<PassQr> qrCodes = <PassQr>[].obs;
  final RxString qrError = ''.obs;

  Timer? _qrTicker;

  // --- Trajets ----------------------------------------------------------

  final RxList<TripEntry> trips = <TripEntry>[].obs;
  final RxBool loadingTrips = false.obs;
  final RxString tripsError = ''.obs;

  // --- Alertes ----------------------------------------------------------
  //
  // Les alertes vivent dans NotificationService, commun aux deux espaces ;
  // les accesseurs qui suivent gardent l'API attendue par les écrans.

  RxList<AppNotification> get notifications => _notifications.items;
  RxBool get loadingNotifications => _notifications.loading;
  RxString get notificationsError => _notifications.error;

  int get unreadCount => _notifications.unreadCount;

  Timer? _ticker;

  /// Signature du parcours déjà tracé, pour ne pas rappeler OSRM à chaque
  /// rafraîchissement du suivi.
  String _traceCharge = '';

  /// Canal du bus actuellement suivi, vide hors tournée. Distinct de celui
  /// de la flotte, qui reste écouté en permanence.
  String _canalSuivi = '';

  @override
  void onInit() {
    super.onInit();
    refreshAll();
    _demarrerSuivi();
  }

  /// Recharge toutes les sections en parallèle.
  ///
  /// Les erreurs sont retenues par section : l'une qui échoue n'empêche
  /// pas les autres d'aboutir.
  Future<void> refreshAll() async {
    await Future.wait([
      refreshTracking(),
      refreshFleet(),
      refreshPass(),
      refreshTrips(),
      refreshNotifications(),
    ]);
  }

  // --- Suivi ------------------------------------------------------------

  Future<void> refreshTracking() async {
    loadingTracking.value = true;
    trackingError.value = '';

    try {
      final reponse = await api.get('etudiant/mon-bus');

      if (reponse['tournee'] == null) {
        tracking.value = null;
        trackingMessage.value =
            reponse['message'] as String? ??
            'Aucun bus n’est actuellement en circulation.';
        routePolyline.clear();
        _traceCharge = '';

        // Le canal du bus suivi n'a plus d'objet, mais la flotte reste
        // écoutée : les autres bus en ligne doivent rester sur la carte.
        if (_canalSuivi.isNotEmpty) {
          realtime?.unwatch(_canalSuivi);
          _canalSuivi = '';
        }

        return;
      }

      trackingMessage.value = '';
      final suivi = BusTracking.fromJson(reponse);
      tracking.value = suivi;

      _ecouterEnDirect(suivi);

      await _chargerTrace(suivi);
    } on ApiException catch (e) {
      trackingError.value = e.message;
    } finally {
      loadingTracking.value = false;
    }
  }

  // --- Flotte en ligne --------------------------------------------------

  /// Lit les bus actuellement en ligne et branche le direct de la flotte.
  ///
  /// La route est publique : elle répond même quand l'étudiant n'a ni pass
  /// ni bus affecté, ce qui laisse la carte peuplée en toute circonstance.
  Future<void> refreshFleet() async {
    try {
      final reponse = await api.get('bus-en-ligne');

      final bus = (reponse['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OnlineBus.fromJson)
          .whereType<OnlineBus>()
          .toList(growable: false);

      onlineBuses.assignAll(bus);
      _ecouterLaFlotte();
    } on ApiException {
      // La flotte est un complément : son absence ne doit pas vider la
      // carte de ce que « mon-bus » a déjà donné.
    }
  }

  /// Suit les mouvements de tous les bus en ligne.
  ///
  /// Le canal « flotte » porte un battement par bus : position, état et
  /// passage hors ligne. Il complète le canal du bus suivi, plus détaillé,
  /// sans s'y substituer.
  void _ecouterLaFlotte() {
    final realtime = this.realtime;
    if (realtime == null) return;

    realtime.onPresence = _adopterPresence;
    realtime.watch('flotte');
  }

  /// Prend en compte un battement reçu en direct.
  void _adopterPresence(Map<String, dynamic> donnees) {
    final busId = donnees['bus_id']?.toString();
    if (busId == null || busId.isEmpty) return;

    // Chauffeur déconnecté : le bus quitte la carte sur-le-champ, plutôt
    // que de rester figé à sa dernière position jusqu'à expiration du
    // délai de grâce.
    if (donnees['en_ligne'] == false) {
      onlineBuses.removeWhere((b) => b.busId == busId);
      return;
    }

    final entrant = OnlineBus.fromJson(donnees);
    if (entrant == null) return;

    final index = onlineBuses.indexWhere((b) => b.busId == busId);

    if (index == -1) {
      // Un chauffeur vient de prendre son service : il apparaît sans
      // attendre le prochain sondage.
      onlineBuses.add(entrant);
      return;
    }

    // Le battement ne porte pas les lieux desservis : on conserve ceux du
    // dernier sondage plutôt que de les effacer.
    onlineBuses[index] = onlineBuses[index].copyWith(
      position: entrant.position,
      state: entrant.state,
      tourneeId: entrant.tourneeId,
      speedKmh: entrant.speedKmh,
      headingDegrees: entrant.headingDegrees,
    );
  }

  /// Calcule le tracé routier reliant les arrêts du parcours.
  ///
  /// OSRM n'accepte qu'un couple origine-destination : le tracé est
  /// assemblé segment par segment.
  Future<void> _chargerTrace(BusTracking suivi) async {
    final arrets = suivi.routeStops
        .where((a) => a.latitude != null && a.longitude != null)
        .toList();

    if (arrets.length < 2) {
      routePolyline.clear();
      return;
    }

    final signature = arrets.map((a) => a.id).join('-');
    if (signature == _traceCharge && routePolyline.isNotEmpty) return;

    final points = <GeoPoint>[];

    for (var i = 0; i < arrets.length - 1; i++) {
      final depart = GeoPoint(arrets[i].latitude!, arrets[i].longitude!);
      final arrivee = GeoPoint(
        arrets[i + 1].latitude!,
        arrets[i + 1].longitude!,
      );

      final segment = await _osm.route(depart, arrivee);

      if (segment != null && segment.points.isNotEmpty) {
        // Le premier point d'un segment répète le dernier du précédent.
        points.addAll(i == 0 ? segment.points : segment.points.skip(1));
      } else {
        // Sans réponse d'OSRM, la ligne droite situe au moins le trajet.
        if (i == 0) points.add(depart);
        points.add(arrivee);
      }
    }

    routePolyline.assignAll(points);
    _traceCharge = signature;
  }

  /// S'abonne au canal du bus suivi, et y branche les positions reçues.
  ///
  /// La position poussée met à jour la carte sans attendre le prochain
  /// sondage ; celui-ci continue en fond, plus espacé, pour rattraper ce
  /// que la diffusion aurait manqué.
  void _ecouterEnDirect(BusTracking suivi) {
    final realtime = this.realtime;

    if (realtime == null || suivi.realtimeChannel.isEmpty) return;

    // Changement de bus : le canal du précédent n'a plus d'intérêt.
    if (_canalSuivi.isNotEmpty && _canalSuivi != suivi.realtimeChannel) {
      realtime.unwatch(_canalSuivi);
    }

    _canalSuivi = suivi.realtimeChannel;

    realtime.onPosition = (latitude, longitude, vitesse) {
      final courant = tracking.value;
      if (courant == null) return;

      tracking.value = courant.copyWith(
        busPosition: LatLngPoint(latitude, longitude),
      );
    };

    realtime.watch(suivi.realtimeChannel);
  }

  /// Rafraîchit le suivi tant que l'application est ouverte.
  void _demarrerSuivi() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_periodeSuivi, (_) => _sonder());

    // Le direct rend le sondage rapproché inutile : on l'espace dès que la
    // liaison tient, et on le resserre si elle tombe.
    final realtime = this.realtime;

    if (realtime == null) return;

    ever<bool>(realtime.connected, (enDirect) {
      _ticker?.cancel();
      _ticker = Timer.periodic(
        enDirect ? _periodeSuiviDirect : _periodeSuivi,
        (_) => _sonder(),
      );
    });
  }

  /// Un tour de sondage : le bus suivi, puis la flotte.
  ///
  /// Le direct porte déjà les mouvements ; ce sondage rattrape les bus
  /// apparus ou disparus pendant une coupure de la liaison.
  Future<void> _sonder() async {
    await refreshTracking();
    await refreshFleet();
  }

  // --- Pass -------------------------------------------------------------

  Future<void> refreshPass() async {
    loadingPass.value = true;
    passError.value = '';

    try {
      final resultats = await Future.wait([
        api.get('etudiant/abonnements/actif'),
        api.get('tarifs'),
        api.get('etudiant/abonnements'),
      ]);

      passes.assignAll(
        (resultats[0]['pass'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(StudentPass.fromJson),
      );
      totalTrips.value = (resultats[0]['total_trajets'] as num?)?.toInt() ?? 0;

      // `pass` reste le pass mis en avant : le premier de la liste.
      pass.value = passes.firstOrNull;

      tarifs.assignAll(
        (resultats[1]['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PassTarif.fromJson),
      );

      // L'index est paginé : les abonnements sont sous `data`.
      passHistory.assignAll(
        (resultats[2]['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(StudentPass.fromJson),
      );
    } on ApiException catch (e) {
      passError.value = e.message;
    } finally {
      loadingPass.value = false;
    }

    await reconcilePendingPayment();
  }

  /// Souscrit une formule ; le paiement Mobile Money suit côté backend.
  Future<StudentPass> buyPass(PassTarif tarif) async {
    final reponse = await api.post('etudiant/abonnements', {
      'tarif_id': int.tryParse(tarif.id),
    });

    final donnees =
        (reponse['abonnement'] as Map<String, dynamic>?) ?? reponse;
    final souscrit = StudentPass.fromJson(donnees);

    await refreshPass();
    return souscrit;
  }

  /// Déclenche le paiement Mobile Money : KPay pousse une demande USSD sur
  /// le téléphone de l'étudiant, qui la valide par son code secret.
  ///
  /// L'opérateur est déduit du numéro par le backend s'il n'est pas fourni.
  Future<void> payPass(
    StudentPass abonnement,
    String telephone, {
    String? provider,
  }) async {
    await api.post('etudiant/abonnements/${abonnement.id}/payer', {
      'telephone': telephone,
      if (provider != null && provider.isNotEmpty) 'provider': provider,
    });

    await refreshPass();
  }

  /// Statut du paiement, tel que KPay le connaît à l'instant.
  ///
  /// Le backend interroge KPay et active l'abonnement dès que le paiement
  /// est confirmé : cette consultation ne fait pas qu'informer l'écran,
  /// elle est ce qui débloque le pass quand le webhook n'a pas abouti.
  Future<String> paymentStatus(StudentPass abonnement) async {
    final reponse = await api.get(
      'etudiant/abonnements/${abonnement.id}/statut-paiement',
    );

    final abo = reponse['abonnement'] as Map<String, dynamic>?;

    if (abo != null) {
      final aJour = StudentPass.fromJson(abo);
      final i = passes.indexWhere((p) => p.id == aJour.id);

      if (i >= 0) {
        passes[i] = aJour;
      }

      if (pass.value?.id == aJour.id || pass.value == null) {
        pass.value = aJour;
      }
    }

    return reponse['statut'] as String? ?? 'PENDING';
  }

  /// Rattrape un paiement resté en suspens.
  ///
  /// L'étudiant a pu fermer l'écran avant la fin, ou valider sa demande
  /// trop tard pour le suivi : au retour sur le pass, on redemande une
  /// fois le statut plutôt que de le laisser croire qu'il n'a rien payé.
  Future<void> reconcilePendingPayment() async {
    // Un pass actif peut lui aussi attendre un règlement : ce sont alors
    // les trajets d'une recharge qui ne sont pas encore acquis.
    final enAttente = passes.where((p) => p.needsPayment).toList();

    for (final attente in enAttente) {
      try {
        await paymentStatus(attente);
      } on ApiException {
        // Aucun paiement n'a jamais été initié pour cet abonnement (404),
        // ou le réseau manque : l'écran reste sur ce qu'il sait déjà.
      }
    }
  }

  // --- QR du pass -------------------------------------------------------

  /// Demande un jeton et le renouvelle jusqu'à ce que l'écran se ferme.
  Future<void> startQr() async {
    await refreshQr();

    _qrTicker?.cancel();

    // Le jeton est réclamé un peu avant son expiration : le QR affiché
    // reste toujours valide sous l'objectif du chauffeur.
    final periode = qr.value == null
        ? const Duration(seconds: 25)
        : Duration(seconds: (qr.value!.validitySeconds - 5).clamp(5, 60));

    _qrTicker = Timer.periodic(periode, (_) => refreshQr());
  }

  void stopQr() {
    _qrTicker?.cancel();
    _qrTicker = null;
    qr.value = null;
    qrCodes.clear();
  }

  Future<void> refreshQr() async {
    try {
      final reponse = await api.get('etudiant/pass/qr');

      qrCodes.assignAll(PassQr.listFromJson(reponse));
      qr.value = qrCodes.firstOrNull ?? PassQr.fromJson(reponse);
      qrError.value = '';
    } on ApiException catch (e) {
      qr.value = null;
      qrCodes.clear();
      qrError.value = e.message;
      _qrTicker?.cancel();

      // Le refus vient du pass lui-même — épuisé par un dernier scan, ou
      // arrivé à échéance. La carte au-dessus doit dire la même chose que
      // le QR : on la remet à jour plutôt que de la laisser périmée.
      if (e.statusCode == 422) unawaited(refreshPass());
    }
  }

  // --- Trajets ----------------------------------------------------------

  Future<void> refreshTrips() async {
    loadingTrips.value = true;
    tripsError.value = '';

    try {
      final reponse = await api.get('etudiant/mes-trajets');

      trips.assignAll(
        (reponse['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TripEntry.fromJson),
      );
    } on ApiException catch (e) {
      tripsError.value = e.message;
    } finally {
      loadingTrips.value = false;
    }
  }

  // --- Alertes ----------------------------------------------------------

  Future<void> refreshNotifications() => _notifications.refresh();

  Future<void> markNotificationRead(String id) => _notifications.markRead(id);

  Future<void> markAllRead() => _notifications.markAllRead();

  Future<bool> deleteNotification(String id) => _notifications.remove(id);

  Future<bool> deleteAllNotifications() => _notifications.removeAll();

  @override
  void onClose() {
    _ticker?.cancel();
    _qrTicker?.cancel();
    realtime?.stop();
    super.onClose();
  }
}
