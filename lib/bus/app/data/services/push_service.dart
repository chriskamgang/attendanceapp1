import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../models/app_notification.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// Message reçu alors que l'application était fermée.
///
/// Le handler d'arrière-plan tourne dans un isolate séparé : il n'a accès
/// ni à GetX ni à l'interface. Android affiche déjà la bannière lui-même à
/// partir du bloc `notification` du message ; il n'y a donc rien à faire de
/// plus ici que d'exister, faute de quoi Firebase journalise un avertissement.
@pragma('vm:entry-point')
Future<void> handlerArrierePlan(RemoteMessage message) async {}

/// Notifications push : permission, jeton FCM et réception des messages.
///
/// Le jeton identifie l'appareil auprès du backend ; il est déposé à
/// l'ouverture de session et retiré à la déconnexion, sinon l'appareil
/// continuerait de recevoir les alertes d'un compte auquel il n'est plus
/// connecté.
class PushService extends GetxService {
  PushService({
    required this.api,
    required this.notifications,
    required this.storage,
  });

  final ApiClient api;
  final NotificationService notifications;
  final StorageService storage;

  /// Canal Android déclaré dans le manifeste : les deux valeurs doivent
  /// rester identiques, sinon les alertes d'arrière-plan arrivent muettes.
  static const AndroidNotificationChannel _canal = AndroidNotificationChannel(
    'insam_bus_alertes',
    'Alertes Estuaire RH',
    description: 'Départs de bus, retards et informations de service.',
    importance: Importance.high,
  );

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Jeton de l'appareil, une fois Firebase interrogé.
  final RxnString token = RxnString();

  /// Accord de l'utilisateur pour les notifications système.
  final RxBool authorized = false.obs;

  /// Alerte ouverte depuis la bannière système, à traiter par l'interface.
  final Rxn<AppNotification> opened = Rxn<AppNotification>();

  bool _demarre = false;

  /// Résolu dès que Firebase a rendu un jeton — ou renoncé.
  ///
  /// `getToken()` est un appel réseau : la restauration de session peut
  /// aboutir avant lui. Sans ce relais, l'enregistrement partirait sur un
  /// jeton nul et l'appareil resterait injoignable jusqu'au prochain
  /// démarrage.
  final Completer<void> _jetonPret = Completer<void>();

  /// Empêche deux enregistrements concurrents — la restauration de session
  /// et une rotation de jeton peuvent tomber en même temps.
  Future<void>? _enregistrementEnCours;

  /// Prépare la réception : canal local, permission, écoute des messages.
  ///
  /// Appelée une fois au lancement. L'enregistrement du jeton auprès du
  /// backend, lui, attend une session ouverte — voir [registerDevice].
  Future<PushService> init() async {
    if (_demarre) return this;
    _demarre = true;

    await _preparerAffichageLocal();
    await _demanderPermission();

    // Le réseau revient en cours de session : un enregistrement tombé à
    // l'eau au login est rejoué ici, sans quoi l'appareil resterait muet
    // jusqu'au prochain démarrage.
    api.onReconnected = () {
      purgerDetachementEnSouffrance();
      registerDevice();
    };

    // Une rotation du jeton par Firebase invalide celui connu du backend :
    // il faut le remonter, sinon l'appareil cesse d'être joignable.
    _fcm.onTokenRefresh.listen((jeton) {
      token.value = jeton;
      registerDevice();
    });

    FirebaseMessaging.onMessage.listen(_surMessageAuPremierPlan);
    FirebaseMessaging.onMessageOpenedApp.listen(_surOuverture);

    // Application lancée depuis la bannière alors qu'elle était fermée.
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _surOuverture(initial);

    // Sans autorisation, aucune bannière ne s'affichera : demander un
    // jeton ferait pousser le serveur dans le vide.
    if (authorized.value) {
      try {
        token.value = await _fcm.getToken();
        _tracer('jeton obtenu');
      } catch (e) {
        // Services Google absents ou appareil sans réseau : l'application
        // fonctionne, seules les alertes push manquent.
        _tracer('jeton indisponible : $e');
      }
    } else {
      _tracer('notifications refusées, aucun jeton demandé');
    }

    if (!_jetonPret.isCompleted) _jetonPret.complete();

    // Un détachement resté en souffrance se rejoue dès qu'une session le
    // permet, avant tout nouvel enregistrement.
    await purgerDetachementEnSouffrance();

    return this;
  }

  /// Redemande l'autorisation puis le jeton, après un premier refus.
  ///
  /// Utile depuis les réglages : l'utilisateur qui a refusé au premier
  /// lancement peut revenir sur sa décision sans réinstaller.
  Future<bool> retryPermission() async {
    await _demanderPermission();

    if (!authorized.value) return false;

    try {
      token.value = await _fcm.getToken();
    } catch (e) {
      _tracer('jeton toujours indisponible : $e');
      return false;
    }

    await registerDevice();
    return token.value != null;
  }

  /// Déclare l'appareil auprès du backend. Sans effet hors session.
  ///
  /// L'appel attend que Firebase ait rendu son jeton : la session peut
  /// être restaurée avant que `getToken()` n'ait répondu.
  Future<void> registerDevice({bool force = false}) async {
    // Deux déclencheurs peuvent se croiser — restauration de session et
    // rotation de jeton : le second attend le premier plutôt que de
    // poster deux fois.
    final enCours = _enregistrementEnCours;
    if (enCours != null) return enCours;

    final travail = _enregistrer(force: force);
    _enregistrementEnCours = travail;

    try {
      await travail;
    } finally {
      _enregistrementEnCours = null;
    }
  }

  Future<void> _enregistrer({required bool force}) async {
    await _jetonPret.future;

    final jeton = token.value;
    if (jeton == null || jeton.isEmpty) {
      _tracer('aucun jeton à déclarer');
      return;
    }

    if (api.token == null) {
      _tracer('hors session, enregistrement différé');
      return;
    }

    // Déjà déclaré pour cette session : l'appel serait sans effet côté
    // serveur, on épargne le réseau à chaque ouverture.
    if (!force && storage.declaredDeviceToken == jeton) {
      _tracer('jeton déjà déclaré');
      return;
    }

    try {
      await api.post('appareils', {
        'token_fcm': jeton,
        'plateforme': Platform.isAndroid ? 'android' : 'ios',
      });

      await storage.saveDeclaredDeviceToken(jeton);
      _tracer('appareil enregistré');
    } on ApiException catch (e) {
      // L'échec n'est pas bloquant : l'utilisateur garde ses alertes dans
      // l'écran des notifications, il perd seulement la bannière. La
      // trace locale n'est pas posée, donc la prochaine ouverture — ou
      // le prochain retour de réseau — rejouera l'appel.
      await storage.clearDeclaredDeviceToken();
      _tracer('enregistrement refusé : ${e.message}');
    }
  }

  /// Détache l'appareil, à la déconnexion.
  ///
  /// Appelé pendant que le token de session vaut encore. Si le réseau
  /// manque, le jeton est mis de côté : tant qu'il reste attaché côté
  /// serveur, ce téléphone recevrait les alertes du compte quitté.
  Future<void> unregisterDevice() async {
    final jeton = token.value ?? storage.declaredDeviceToken;
    if (jeton == null || jeton.isEmpty) return;

    if (api.token == null) {
      await storage.saveOrphanDeviceToken(jeton);
      return;
    }

    try {
      await api.delete('appareils', {'token_fcm': jeton});
      await storage.clearOrphanDeviceToken();
      _tracer('appareil détaché');
    } on ApiException catch (e) {
      // 404 : le backend ne connaît déjà plus ce jeton, l'objectif est
      // atteint. Tout autre échec doit être rejoué plus tard.
      if (e.statusCode == 404) {
        await storage.clearOrphanDeviceToken();
        return;
      }

      await storage.saveOrphanDeviceToken(jeton);
      _tracer('détachement différé : ${e.message}');
    }

    await storage.clearDeclaredDeviceToken();
  }

  /// Rejoue un détachement laissé en souffrance par une déconnexion hors
  /// ligne.
  ///
  /// Le compte qui rattrape n'est pas forcément celui qui a quitté :
  /// c'est sans importance, le backend supprime la ligne du jeton, quel
  /// qu'en soit le propriétaire.
  Future<void> purgerDetachementEnSouffrance() async {
    final orphelin = storage.orphanDeviceToken;
    if (orphelin == null || orphelin.isEmpty || api.token == null) return;

    // Le jeton est redevenu celui de la session courante : le détacher
    // couperait les alertes qu'on vient de rétablir.
    if (orphelin == token.value && storage.declaredDeviceToken == orphelin) {
      await storage.clearOrphanDeviceToken();
      return;
    }

    try {
      await api.delete('appareils', {'token_fcm': orphelin});
      await storage.clearOrphanDeviceToken();
      _tracer('détachement en souffrance rattrapé');
    } on ApiException catch (e) {
      if (e.statusCode == 404) await storage.clearOrphanDeviceToken();
      // Toujours hors ligne : la trace reste, on réessaiera.
    }
  }

  /// Demande l'autorisation système (obligatoire sur iOS et Android 13+).
  Future<void> _demanderPermission() async {
    final reglages = await _fcm.requestPermission(alert: true, badge: true, sound: true);

    authorized.value =
        reglages.authorizationStatus == AuthorizationStatus.authorized ||
        reglages.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _preparerAffichageLocal() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (reponse) {
        final charge = reponse.payload;
        if (charge == null || charge.isEmpty) return;

        final data = jsonDecode(charge);
        if (data is Map<String, dynamic>) _ouvrirDepuisData(data);
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_canal);
  }

  /// Message reçu application ouverte.
  ///
  /// Android n'affiche alors aucune bannière : c'est à l'application de la
  /// poser, sans quoi l'alerte passerait inaperçue.
  void _surMessageAuPremierPlan(RemoteMessage message) {
    final entete = message.notification;

    notifications.ajouterDepuisPush(
      AppNotification.fromPush(
        data: message.data,
        title: entete?.title,
        body: entete?.body,
      ),
    );

    if (entete == null) return;

    _local.show(
      // Identifiant propre à cette bannière : deux alertes distinctes ne
      // doivent pas se remplacer l'une l'autre dans le tiroir Android.
      id: message.hashCode,
      title: entete.title,
      body: entete.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _canal.id,
          _canal.name,
          channelDescription: _canal.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _surOuverture(RemoteMessage message) {
    final entete = message.notification;

    opened.value = AppNotification.fromPush(
      data: message.data,
      title: entete?.title,
      body: entete?.body,
    );
  }

  void _ouvrirDepuisData(Map<String, dynamic> data) {
    opened.value = AppNotification.fromPush(data: data);
  }

  void _tracer(String message) {
    if (kDebugMode) debugPrint('[push] $message');
  }
}
