import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/app_user.dart';
import '../models/pickup_point.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'driver_service.dart';
import 'notification_service.dart';
import 'push_service.dart';
import 'storage_service.dart';

/// Porte l'état d'authentification pour toute l'application.
///
/// L'étudiant se connecte sans mot de passe : il reçoit un code à six
/// chiffres par email, que le backend échange contre un jeton de session.
/// Écran vers lequel diriger l'étudiant après la saisie de son adresse.
enum SignInRoute {
  /// Compte connu, PIN déjà posé : il le saisit.
  pin,

  /// Adresse inconnue : l'étudiant choisit son PIN, ce qui l'inscrit.
  signUp,

  /// Compte à mot de passe (chauffeur, back-office).
  password,
}

class SessionService extends GetxService {
  SessionService({required this.api, required this.storage});

  final ApiClient api;
  final StorageService storage;

  final Rxn<AppUser> user = Rxn<AppUser>();

  /// Lignes et points de ramassage servis par le backend (CDC §3.1).
  final RxList<PickupPoint> pickupPoints = <PickupPoint>[].obs;
  final RxBool loadingPickups = false.obs;

  bool get isLoggedIn => user.value != null;

  @override
  void onInit() {
    super.onInit();

    // Un token refusé en cours de route ferme la session : l'utilisateur
    // se retrouve sur l'accueil de connexion plutôt que devant un écran
    // qui échoue en silence.
    api.onUnauthenticated = _forgetSession;
  }

  /// Restaure la session enregistrée au lancement de l'application.
  ///
  /// Renvoie `true` si un utilisateur est de nouveau connecté.
  Future<bool> restore() async {
    final token = storage.token;
    if (token == null || token.isEmpty) {
      _tracer('aucune session enregistrée');
      return false;
    }

    api.token = token;

    // Le profil local permet d'ouvrir l'application sans attendre le
    // réseau ; l'appel qui suit le remet à jour.
    final cached = storage.user;
    if (cached != null) user.value = AppUser.fromApi(cached);

    try {
      await refreshProfile();
      _tracer('session restaurée pour ${user.value?.email}');
      await _declarerAppareil();
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthenticated) {
        // Le jeton ne vaut plus rien — compte supprimé, base réinitialisée,
        // déconnexion depuis un autre appareil. On l'efface pour de bon,
        // sinon chaque lancement rejoue le même échec.
        _tracer('jeton refusé par le serveur, session effacée');
        await _forgetSession();
        return false;
      }

      // Serveur injoignable : la session locale tient, l'application
      // s'ouvre sur les dernières données connues.
      _tracer('serveur injoignable, session locale conservée');
      return user.value != null;
    }
  }

  /// Trace le déroulé de la restauration, en débogage seulement.
  ///
  /// Une session qui ne se rouvre pas est difficile à diagnostiquer sans
  /// savoir laquelle des trois causes s'applique.
  void _tracer(String message) {
    if (kDebugMode) debugPrint('[session] $message');
  }

  /// Par où passe la connexion, une fois l'adresse saisie.
  ///
  /// Aucun code ne circule par email : la réponse dit seulement si le
  /// compte se déverrouille par PIN ou par mot de passe, et s'il reste à
  /// créer.
  Future<SignInRoute> lookup(String email) async {
    final reponse = await api.post('aiguillage', {'email': email});

    final route = switch (reponse['canal'] as String?) {
      'pin' => reponse['inscription'] == true
          ? SignInRoute.signUp
          : SignInRoute.pin,
      _ => SignInRoute.password,
    };

    // L'adresse est retenue pour l'écran suivant ; inutile pour un compte
    // à mot de passe, qui se connecte par téléphone.
    if (route != SignInRoute.password) {
      await storage.savePendingEmail(email);
    }

    return route;
  }

  /// Ouvre la session d'un chauffeur : son numéro et son PIN.
  ///
  /// Le backend identifie ces comptes par leur **téléphone**, non par leur
  /// adresse : ils sont créés au back-office, où le numéro fait foi. Le PIN
  /// leur est communiqué par la régulation.
  Future<AppUser> signInDriver({
    required String phone,
    required String pin,
  }) async {
    final reponse = await api.post('connexion', {
      'telephone': phone,
      'pin': pin,
      'appareil': 'mobile',
    });

    return _openSession(reponse);
  }

  /// Ouvre la session d'un étudiant avec son PIN à quatre chiffres.
  ///
  /// C'est la connexion courante : le code par email ne sert plus qu'à
  /// prouver l'adresse, à l'inscription puis après un oubli.
  Future<AppUser> signInWithPin({
    required String email,
    required String pin,
  }) async {
    final reponse = await api.post('connexion-pin', {
      'email': email,
      'pin': pin,
      'appareil': 'mobile',
    });

    return _openSession(reponse);
  }

  /// Change le PIN du compte connecté.
  Future<void> definePin(String pin) async {
    await api.put('pin', {'pin': pin, 'pin_confirmation': pin});
  }

  /// Crée le compte étudiant et ouvre la session.
  ///
  /// L'adresse n'est pas vérifiée : elle sert d'identifiant, et le PIN de
  /// secret.
  Future<AppUser> signUpWithPin({
    required String email,
    required String pin,
  }) async {
    final reponse = await api.post('inscription-pin', {
      'email': email,
      'pin': pin,
      'pin_confirmation': pin,
      'appareil': 'mobile',
    });

    return _openSession(reponse);
  }

  /// Recharge le profil depuis le backend.
  Future<void> refreshProfile() async {
    final reponse = await api.get('profil');

    user.value = AppUser.fromApi(reponse);
    await storage.saveUser(reponse);
  }

  /// Charge les points de ramassage desservis par le réseau.
  ///
  /// Le backend n'expose que les lieux réellement desservis par un
  /// parcours actif ; les campus en sont exclus, l'étudiant n'y montant
  /// pas le matin.
  Future<void> loadPickupPoints({bool force = false}) async {
    if (loadingPickups.value) return;
    if (pickupPoints.isNotEmpty && !force) return;

    loadingPickups.value = true;
    try {
      final reponse = await api.get('points-ramassage');
      final lieux = (reponse['data'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

      pickupPoints.assignAll(lieux.map(PickupPoint.fromJson));
    } finally {
      loadingPickups.value = false;
    }
  }

  /// Enregistre le profil complété par l'étudiant.
  Future<void> saveProfile({
    required String firstName,
    required String lastName,
    required String phone,
    required String matricule,
    required bool matriculeSkipped,
    required PickupPoint pickup,
    String? niveau,
    String? specialite,
  }) async {
    final reponse = await api.put('profil', {
      'prenom': firstName,
      'nom': lastName,
      'telephone': phone,
      // C'est ce couple qui rattache l'étudiant à son emploi du temps :
      // sans lui, sa semaine et ses cours restent vides.
      'niveau': niveau,
      'specialite': specialite,
      // Le matricule oublié part à null : l'étudiant le renseignera
      // depuis son profil (US-10).
      'matricule_insam': matriculeSkipped || matricule.isEmpty
          ? null
          : matricule,
      'lieu_ramassage_id': int.tryParse(pickup.id),
    });

    user.value = AppUser.fromApi(reponse);
    await storage.saveUser(reponse);
  }

  /// Change le point de ramassage habituel.
  ///
  /// Distinct de [saveProfile] : l'étudiant qui déménage corrige son arrêt
  /// sans avoir à ressaisir son identité.
  Future<void> changePickupPoint(PickupPoint pickup) async {
    final reponse = await api.put('etudiant/point-ramassage', {
      'lieu_ramassage_id': int.tryParse(pickup.id),
    });

    final utilisateur = reponse['utilisateur'] as Map<String, dynamic>?;

    if (utilisateur != null) {
      user.value = AppUser.fromApi(reponse);
      await storage.saveUser(reponse);
    }
  }

  /// Ferme la session, côté serveur puis côté appareil.
  Future<void> signOut() async {
    // L'appareil se détache tant que le token vaut encore : après la
    // révocation, le backend refuserait la requête et continuerait de
    // pousser les alertes de ce compte sur ce téléphone. Si le réseau
    // manque, PushService met le jeton de côté et rejouera l'appel.
    if (Get.isRegistered<PushService>()) {
      await Get.find<PushService>().unregisterDevice();
    }

    // Le chauffeur quitte la carte des étudiants avant que son token ne
    // soit révoqué : après, le battement se heurterait à un 401 et le bus
    // resterait affiché jusqu'à expiration du délai de grâce côté serveur.
    if (Get.isRegistered<DriverService>()) {
      await Get.find<DriverService>().goOffline();
    }

    try {
      await api.post('deconnexion');
    } on ApiException {
      // Token déjà révoqué ou appareil hors ligne : la session locale
      // doit disparaître dans tous les cas.
    }

    await _forgetSession();
  }

  /// Supprime définitivement le compte, puis ferme la session.
  ///
  /// Exigé par l'App Store dès lors que l'application ouvre des comptes
  /// (5.1.1(v)). Le backend efface réellement les données : rien n'est
  /// récupérable ensuite, et la même adresse peut resservir.
  ///
  /// Un chauffeur dont la cagnotte n'est pas soldée essuie un refus : le
  /// message du serveur l'oriente vers la régulation.
  Future<void> deleteAccount() async {
    // Même ordre que [signOut] : l'appareil se détache et le bus quitte la
    // carte tant que le token vaut encore.
    if (Get.isRegistered<PushService>()) {
      await Get.find<PushService>().unregisterDevice();
    }

    if (Get.isRegistered<DriverService>()) {
      await Get.find<DriverService>().goOffline();
    }

    // Ici, contrairement à la déconnexion, une erreur remonte : effacer la
    // session locale sur un échec laisserait croire à une suppression qui
    // n'a pas eu lieu.
    await api.delete('compte');

    await _forgetSession();
  }

  /// Ouvre la session à partir d'une réponse portant un token.
  Future<AppUser> _openSession(Map<String, dynamic> reponse) async {
    final token = reponse['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException('Réponse inattendue du serveur.');
    }

    api.token = token;

    final signed = AppUser.fromApi(reponse);
    user.value = signed;

    await storage.saveSession(token: token, user: reponse);
    await storage.clearPendingEmail();

    await _declarerAppareil();

    return signed;
  }

  /// Efface toute trace de la session sur l'appareil.
  Future<void> _forgetSession() async {
    api.token = null;
    user.value = null;
    pickupPoints.clear();

    if (Get.isRegistered<NotificationService>()) {
      Get.find<NotificationService>().clear();
    }

    await storage.clearSession();
  }

  /// Remonte le jeton FCM de l'appareil au backend.
  ///
  /// Sans jeton enregistré, le compte reste joignable dans l'application
  /// mais ne reçoit aucune bannière : l'appel suit donc chaque ouverture
  /// de session, y compris celles restaurées au lancement.
  Future<void> _declarerAppareil() async {
    if (!Get.isRegistered<PushService>()) return;

    final push = Get.find<PushService>();

    // Un compte a pu quitter ce téléphone hors ligne : son jeton est
    // détaché avant que le nouveau ne s'enregistre, sinon les deux
    // comptes recevraient les mêmes alertes.
    await push.purgerDetachementEnSouffrance();
    await push.registerDevice();
  }
}
