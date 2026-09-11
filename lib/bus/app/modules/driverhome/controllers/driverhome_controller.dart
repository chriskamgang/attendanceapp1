import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/breakdown_report.dart';
import '../../../data/models/tour_stage.dart';
import '../../../data/services/driver_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/osm_service.dart';
import '../../../data/services/api_exception.dart';
import '../../../data/services/session_service.dart';
import '../../../routes/app_pages.dart';

/// Coque de l'espace chauffeur : porte les cinq onglets de la barre basse.
class DriverhomeController extends GetxController {
  final SessionService session = Get.find<SessionService>();
  final DriverService driver = Get.find<DriverService>();

  /// Boîte d'alertes commune aux deux espaces : le chauffeur y reçoit ses
  /// missions de secours et les pannes qui le concernent.
  final NotificationService notifications = Get.find<NotificationService>();

  int get unreadCount => notifications.unreadCount;

  final RxInt tab = 0.obs;

  /// Saisie de l'effectif, partagée entre l'onglet Tournée et Effectifs.
  final TextEditingController headcount = TextEditingController();

  AppUser? get user => session.user.value;

  String get greetingName {
    final name = user?.firstName ?? '';
    return name.isEmpty ? 'Chauffeur' : name;
  }

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  /// Index de l'onglet Carte dans la barre basse.
  static const int mapTab = 1;

  GoogleMapController? _map;
  StreamSubscription<dynamic>? _busWatch;

  /// Zoom de suivi : assez près pour lire la rue où roule le bus.
  static const double followZoom = 16.5;

  /// La caméra suit le bus tant que le chauffeur ne l'a pas déplacée
  /// lui-même ; elle reprend le suivi au bouton de recentrage.
  final RxBool followBus = true.obs;

  /// Vrai dès que la carte native a peint sa première frame ; le voile de
  /// chargement s'efface alors.
  final RxBool mapReady = false.obs;

  /// Vrai pendant un mouvement de caméra que nous avons nous-mêmes lancé.
  ///
  /// Google Maps ne distingue pas le geste du chauffeur du recentrage
  /// automatique : les deux passent par `onCameraMoveStarted`. Sans ce
  /// drapeau, notre propre recentrage couperait le suivi qu'il vient de
  /// servir, et la carte semblerait se figer.
  bool _cameraPilotee = false;

  /// Zoom courant, tel que le chauffeur l'a laissé.
  ///
  /// Le suivi ne l'impose plus à chaque relevé : forcer un zoom quinze
  /// fois par minute rendait impossible de prendre du recul sur la carte.
  double? _zoomChoisi;

  /// Oublie la carte démontée.
  ///
  /// Appelée quand le chauffeur quitte l'onglet : le widget libère
  /// lui-même le contrôleur natif, et garder la référence exposerait à
  /// piloter une carte qui n'existe plus.
  void detachMap() {
    _busWatch?.cancel();
    _busWatch = null;
    _map = null;
    mapReady.value = false;
  }

  /// Remet la carte à l'état « pas encore peinte ».
  ///
  /// L'onglet est démonté quand le chauffeur le quitte : à son retour, une
  /// carte neuve repeint ses tuiles, et le voile doit la couvrir de
  /// nouveau plutôt que de laisser voir le gris.
  void resetMap() {
    mapReady.value = false;
    _cameraPilotee = false;
  }

  void onMapCreated(GoogleMapController map) {
    _map = map;
    _log('carte créée');

    _busWatch?.cancel();
    _busWatch = driver.busPosition.listen((point) {
      if (point == null || !followBus.value) return;
      _suivre(point);
    });

    final point = driver.busPosition.value;
    if (point != null) _suivre(point);
  }

  /// Signale que les tuiles sont peintes.
  ///
  /// Google Maps n'a pas d'événement « chargé » ; le premier arrêt de
  /// caméra est le signal le plus proche, et il suffit à masquer l'écran
  /// gris du démarrage.
  void onMapRendered() {
    // La fin d'un mouvement rend la main : le prochain geste sera bien
    // celui du chauffeur.
    _cameraPilotee = false;

    if (mapReady.value) return;

    mapReady.value = true;
    _log('carte affichée');
  }

  /// Retient le zoom que le chauffeur vient de choisir.
  void onCameraMove(CameraPosition position) {
    if (!_cameraPilotee) _zoomChoisi = position.zoom;
  }

  /// Fait glisser la carte sous le bus, sans toucher au zoom ni à
  /// l'orientation.
  ///
  /// Un simple recentrage suffit au suivi : imposer aussi le cap ferait
  /// pivoter la carte à chaque relevé, ce qui rend tout geste heurté et
  /// donne l'impression d'un écran qui rame.
  void _suivre(GeoPoint point) {
    _cameraPilotee = true;
    _map?.animateCamera(CameraUpdate.newLatLng(LatLng(point.lat, point.lng)));
  }

  /// Coupe le suivi automatique : le chauffeur explore la carte à la main.
  void releaseCamera() {
    // Un mouvement que nous avons lancé n'est pas un geste du chauffeur.
    if (_cameraPilotee || !followBus.value) return;

    followBus.value = false;
    _log('suivi caméra relâché');
  }

  /// Reprend le suivi, recentre et remet le cap du bus vers le haut.
  void recenterOnBus() {
    followBus.value = true;
    _log('suivi caméra repris');

    final point = driver.busPosition.value;
    if (point == null) return;

    // Ici seulement on impose zoom et cap : c'est une demande explicite,
    // pas un recalage de fond.
    _cameraPilotee = true;
    _map?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(point.lat, point.lng),
          zoom: _zoomChoisi ?? followZoom,
          bearing: driver.bearing.value ?? 0,
        ),
      ),
    );
  }

  /// Met le chauffeur en pause, ou le remet sur la carte des étudiants.
  ///
  /// La pause n'annule pas le tour en cours : elle coupe la diffusion, le
  /// temps d'un arrêt ou d'un trajet à vide. Le pointage, lui, reste
  /// possible — le backend juge sur les coordonnées jointes à l'étape.
  Future<void> togglePresence() async {
    final enPause = driver.offlineByChoice.value;

    await driver.togglePresence();

    if (enPause) {
      _toast(
        'De retour en ligne',
        'Ta position repart aux étudiants.',
        AppColors.blue,
        AppColors.white,
      );
    } else {
      _toast(
        'Hors ligne',
        'Ta position ne part plus ; ton bus disparaît de leur carte.',
        AppColors.gold,
        AppColors.ink,
      );
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[chauffeur] $message');
  }

  void changeTab(int index) => tab.value = index;

  Future<void> reload() async {
    await Future.wait([driver.refreshAll(), notifications.refresh()]);
  }

  void openNotifications() => Get.toNamed(Routes.NOTIFICATIONS);

  /// Fait avancer le cycle de pointage d'une étape (CDC §3.2).
  ///
  /// La saisie de l'effectif n'est pas une action directe : elle bascule
  /// sur l'onglet dédié, où le chiffre est confirmé. Chaque autre étape
  /// part au backend, seul juge de sa validité.
  Future<void> advance() async {
    final current = driver.tour.value;
    if (current == null) return;

    switch (current.stage) {
      case TourStage.offline:
        final demarre = await _run(
          driver.startService,
          'Service démarré',
          'Ta position part aux étudiants.',
        );

        // Le service démarré, la carte devient l'écran de travail : le
        // chauffeur y voit son bus en ligne et la route à suivre, plutôt
        // que de rester devant la liste des étapes.
        if (demarre) {
          _log('service démarré, bascule sur la carte');
          followBus.value = true;
          changeTab(mapTab);
        }
      case TourStage.serviceStarted:
        await _run(
          driver.markArrivedAtPickup,
          'Arrivée pointée',
          'Les étudiants peuvent embarquer.',
        );
      case TourStage.atPickup:
        changeTab(2);
      case TourStage.headcountDone:
        await _run(
          driver.departToCampus,
          'Départ enregistré',
          'Le bus est en transit, les étudiants sont prévenus.',
        );
      case TourStage.toCampus:
        final ok = await _run(
          driver.finishTour,
          'Tour validé',
          'Prime créditée sur ta cagnotte du mois.',
        );
        if (ok) changeTab(0);
      case TourStage.finished:
        await driver.startNextTour();
    }
  }

  /// Exécute une étape et rend compte de son issue.
  ///
  /// Le message d'échec vient du backend : « hors zone », « écart non
  /// justifié » ou « séquence rompue » se disent mieux avec ses mots.
  Future<bool> _run(
    Future<bool> Function() action,
    String title,
    String message,
  ) async {
    final ok = await action();

    if (ok) {
      _toast(title, message, AppColors.blue, AppColors.white);
    } else {
      _toast(
        'Étape refusée',
        driver.error.value.isEmpty
            ? 'Réessaie dans un instant.'
            : driver.error.value,
        AppColors.gold,
        AppColors.ink,
      );
    }

    return ok;
  }

  void _toast(String title, String message, Color background, Color text) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: background,
      colorText: text,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    );
  }

  /// Confirme l'effectif saisi et referme l'étape 3.
  Future<void> confirmHeadcount() async {
    final value = int.tryParse(headcount.text.trim());
    if (value == null || value < 0) {
      _toast(
        'Effectif invalide',
        'Entre le nombre d’étudiants montés à bord.',
        AppColors.gold,
        AppColors.ink,
      );
      return;
    }

    final capacity = driver.busCapacity.value;
    if (capacity > 0 && value > capacity) {
      _toast(
        'Effectif trop élevé',
        'Le bus ne compte que $capacity places.',
        AppColors.gold,
        AppColors.ink,
      );
      return;
    }

    final ok = await _run(
      () => driver.submitHeadcount(value),
      'Effectif enregistré',
      '$value étudiant${value > 1 ? 's' : ''} à bord.',
    );

    if (!ok) return;

    headcount.clear();

    // Le comptage billettique décide du blocage du départ : on le relit
    // avant de rendre la main à l'onglet Tournée.
    await driver.syncBoardingCount();
    changeTab(0);
  }

  /// Incrémente ou décrémente le compteur d'un cran.
  void bumpHeadcount(int delta) {
    final current = int.tryParse(headcount.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 99);
    headcount.text = '$next';
  }

  /// Signale un retard aux étudiants desservis (US-04).
  Future<void> declareDelay({required int minutes, String reason = ''}) async {
    final ok = await driver.declareDelay(minutes: minutes, reason: reason);

    if (ok) {
      _toast(
        'Retard signalé',
        'Les étudiants de ton arrêt sont prévenus.',
        AppColors.gold,
        AppColors.ink,
      );
    } else {
      _toast(
        'Signalement refusé',
        driver.error.value.isEmpty
            ? 'Réessaie dans un instant.'
            : driver.error.value,
        AppColors.gold,
        AppColors.ink,
      );
    }
  }

  /// Déclare une panne depuis la feuille dédiée.
  Future<void> declareBreakdown({
    required BreakdownKind kind,
    required int studentsOnBoard,
    String note = '',
  }) async {
    final ok = await driver.declareBreakdown(
      kind: kind,
      studentsOnBoard: studentsOnBoard,
      note: note,
    );

    if (ok) {
      _toast(
        'Panne signalée',
        'La régulation est prévenue, un secours va être affecté.',
        AppColors.gold,
        AppColors.ink,
      );
    } else {
      _toast(
        'Déclaration refusée',
        driver.error.value.isEmpty
            ? 'Réessaie dans un instant.'
            : driver.error.value,
        AppColors.gold,
        AppColors.ink,
      );
    }
  }

  Future<void> acceptMission(String id) async {
    final ok = await driver.acceptMission(id);

    if (ok) {
      _toast(
        'Mission acceptée',
        'Rends-toi sur place : la prime sera créditée à la prise en charge.',
        AppColors.blue,
        AppColors.white,
      );
    } else {
      _toast(
        'Mission indisponible',
        driver.error.value.isEmpty
            ? 'Cette mission n’est plus à prendre.'
            : driver.error.value,
        AppColors.gold,
        AppColors.ink,
      );
    }
  }

  /// Déclare le départ vers le bus en panne.
  Future<void> startMission(String id) async {
    final ok = await driver.startMission(id);

    if (ok) {
      _toast(
        'En route',
        'La régulation suit ton approche.',
        AppColors.blue,
        AppColors.white,
      );
    } else {
      _toast(
        'Action refusée',
        driver.error.value.isEmpty
            ? 'Réessaie dans un instant.'
            : driver.error.value,
        AppColors.gold,
        AppColors.ink,
      );
    }
  }

  /// Clôture une mission de secours et déclenche la prime (CDC §3.4).
  Future<void> finishMission(String id, int rescued) async {
    final ok = await driver.finishMission(id, rescued: rescued);

    if (ok) {
      _toast(
        'Mission terminée',
        '$rescued passager${rescued > 1 ? 's' : ''} pris en charge.',
        AppColors.blue,
        AppColors.white,
      );
    } else {
      _toast(
        'Clôture refusée',
        driver.error.value.isEmpty
            ? 'Réessaie dans un instant.'
            : driver.error.value,
        AppColors.gold,
        AppColors.ink,
      );
    }
  }

  void declineMission(String id) => driver.declineMission(id);

  Future<void> signOut() async {
    if (signingOut.value) return;
    signingOut.value = true;

    try {
      await session.signOut();
      Get.offAllNamed(Routes.WELCOMER);
    } finally {
      // Le contrôleur peut avoir été démonté par le changement de route.
      if (!isClosed) signingOut.value = false;
    }
  }

  /// Vrai pendant la déconnexion : l'écran remplace le libellé par un
  /// indicateur et refuse un second appui.
  ///
  /// Elle est plus lente ici que côté étudiant : le bus quitte d'abord la
  /// carte, puis l'appareil se détache du push, avant l'appel au serveur.
  final RxBool signingOut = false.obs;

  /// Vrai pendant l'appel de suppression, pour bloquer un second appui.
  final RxBool deleting = false.obs;

  /// Supprime le compte, puis renvoie a l'accueil de connexion.
  ///
  /// Un chauffeur dont la cagnotte n'est pas soldee essuie un refus du
  /// serveur : la session reste ouverte et le message dit pourquoi.
  Future<void> deleteAccount() async {
    if (deleting.value) return;
    deleting.value = true;

    try {
      await session.deleteAccount();
      Get.offAllNamed(Routes.WELCOMER);
    } on ApiException catch (e) {
      Get.snackbar(
        'Suppression impossible',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    } finally {
      deleting.value = false;
    }
  }

  @override
  void onClose() {
    _busWatch?.cancel();
    // Le contrôleur natif appartient au widget `GoogleMap`, qui le libère
    // à son démontage : le libérer ici aussi reviendrait à le fermer deux
    // fois.
    _map = null;
    headcount.dispose();
    super.onClose();
  }
}
