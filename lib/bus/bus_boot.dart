import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/core/theme/app_theme.dart';
import 'app/data/models/app_notification.dart';
import 'app/data/services/api_client.dart';
import 'app/data/services/notification_service.dart';
import 'app/data/services/osm_service.dart';
import 'app/data/services/push_service.dart';
import 'app/data/services/session_service.dart';
import 'app/data/services/storage_service.dart';
import 'app/routes/app_pages.dart';

/// Amorçage de l'espace INSAM BUS.
///
/// Le module vient d'une application autonome ; son `main()` d'origine est
/// devenu [demarrer], appelé seulement quand l'utilisateur entre dans cet
/// espace. Les services ne sont donc pas construits pour rien lorsque
/// l'application ouvre sur Estuaire RH.
abstract class BusBoot {
  BusBoot._();

  /// Vrai une fois les services posés dans GetX.
  ///
  /// Revenir dans l'espace bus après en être sorti ne doit pas les
  /// reconstruire : la session restaurée et le jeton push resteraient
  /// alors sur les instances précédentes.
  static bool _pret = false;

  static bool get pret => _pret;

  /// Écran d'arrivée, décidé au démarrage des services.
  ///
  /// La session est restaurée pendant que l'espace se met en place : à
  /// l'ouverture de la première page, la destination est déjà connue et
  /// aucun écran d'attente n'a besoin de la calculer.
  static String _routeInitiale = Routes.WELCOMER;

  /// Écran d'ouverture de l'espace.
  ///
  /// Recalculé à chaque lecture une fois les services en place : `demarrer`
  /// ne tourne qu'une fois, mais l'espace peut être remonté plusieurs fois
  /// — après un retour au pointage puis un nouveau passage — et la session
  /// a pu se fermer entre-temps.
  static String get routeInitiale {
    if (_pret) _rafraichirRouteInitiale();
    return _routeInitiale;
  }

  /// Relit la session déjà restaurée, sans rappeler le serveur.
  static void _rafraichirRouteInitiale() {
    final utilisateur = Get.isRegistered<SessionService>()
        ? Get.find<SessionService>().user.value
        : null;

    _routeInitiale = utilisateur == null
        ? Routes.WELCOMER
        : AppRoutes.homeFor(utilisateur);
  }

  /// Installe les services partagés de l'espace bus.
  ///
  /// Idempotent : un second appel est sans effet.
  static Future<void> demarrer() async {
    if (_pret) return;

    // Le stockage s'ouvre en asynchrone : il doit être prêt avant que le
    // splash ne cherche à restaurer une session.
    final storage = await StorageService().init();
    Get.put<StorageService>(storage, permanent: true);

    final api = Get.put<ApiClient>(ApiClient(), permanent: true);

    // La session vit au-delà des écrans : elle porte l'utilisateur connecté
    // et son rôle pour toute la durée de l'application.
    Get.put(SessionService(api: api, storage: storage), permanent: true);

    // OSM porte le géocodage et les itinéraires ; StudentService en dépend.
    Get.put(OsmService(), permanent: true);

    // La boîte de notifications est commune aux deux espaces : elle est
    // alimentée par l'API et complétée par les messages push.
    final notifications = Get.put(
      NotificationService(api: api),
      permanent: true,
    );

    await _demarrerPush(
      api: api,
      notifications: notifications,
      storage: storage,
    );

    await _choisirRouteInitiale();

    _pret = true;
  }

  /// Reprend la session enregistrée et en déduit l'écran d'arrivée.
  ///
  /// Un échec de restauration n'est pas une panne : le jeton a pu expirer,
  /// et l'accueil de connexion est alors la bonne destination.
  static Future<void> _choisirRouteInitiale() async {
    try {
      final session = Get.find<SessionService>();

      if (await session.restore()) {
        final utilisateur = session.user.value;
        if (utilisateur != null) {
          _routeInitiale = AppRoutes.homeFor(utilisateur);
          return;
        }
      }
    } catch (_) {
      // Stockage illisible ou serveur muet : on repart de l'accueil.
    }

    _routeInitiale = Routes.WELCOMER;
  }

  /// Met en route les notifications push, sans bloquer le démarrage.
  ///
  /// Un appareil sans services Google, un émulateur mal provisionné ou un
  /// réseau coupé ne doivent pas empêcher l'application de s'ouvrir : le
  /// reste de l'application fonctionne, seules les bannières manquent.
  ///
  /// Firebase est initialisé une seule fois pour toute l'application, à
  /// partir de `google-services.json` — Estuaire RH s'appuie sur la même
  /// instance par défaut. Tant que ce fichier vise le projet du pointage,
  /// le backend bus ne pourra pas joindre l'appareil : l'enregistrement du
  /// jeton échouera sans conséquence, et se rejouera de lui-même une fois
  /// le fichier remplacé par celui du projet commun.
  static Future<void> _demarrerPush({
    required ApiClient api,
    required NotificationService notifications,
    required StorageService storage,
  }) async {
    try {
      // `Firebase.initializeApp` peut avoir déjà tourné pour Estuaire RH :
      // la seconde initialisation de l'instance par défaut est refusée,
      // l'application existante fait alors l'affaire.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      FirebaseMessaging.onBackgroundMessage(handlerArrierePlan);

      final push = PushService(
        api: api,
        notifications: notifications,
        storage: storage,
      );
      Get.put<PushService>(push, permanent: true);
      await push.init();

      // Bannière touchée : l'application s'ouvre sur la boîte d'alertes,
      // et la notification concernée passe en lue.
      ever<AppNotification?>(push.opened, (alerte) {
        if (alerte == null) return;

        if (alerte.id.isNotEmpty) notifications.markRead(alerte.id);

        notifications.refresh();

        if (Get.currentRoute != Routes.NOTIFICATIONS) {
          Get.toNamed(Routes.NOTIFICATIONS);
        }

        push.opened.value = null;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[push] initialisation impossible : $e');
    }
  }
}

/// L'espace INSAM BUS, monté comme application racine.
///
/// GetX porte ici sa propre navigation : l'espace occupe tout l'écran tant
/// que l'utilisateur y reste, et le lanceur le remplace lorsqu'il en sort.
class InsamBusApp extends StatelessWidget {
  const InsamBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Estuaire RH',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Light theme uniquement : on ignore le réglage système.
      themeMode: ThemeMode.light,
      initialRoute: BusBoot.routeInitiale,
      getPages: AppPages.routes,
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}
