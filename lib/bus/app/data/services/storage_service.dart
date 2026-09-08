import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistance locale : session survivant à la fermeture de l'application.
///
/// Le token vaut identité : il n'est écrit que par [saveSession] et effacé
/// par [clearSession], jamais recopié ailleurs.
class StorageService extends GetxService {
  /// Les clés portent toutes le préfixe `bus_` : l'application héberge
  /// aussi l'espace Estuaire RH, qui écrit dans le même `SharedPreferences`
  /// et y range son propre `auth_token`. Sans ce préfixe, ouvrir une
  /// session d'un côté écraserait celle de l'autre.
  static const String _kToken = 'bus_auth_token';
  static const String _kUser = 'bus_auth_user';
  static const String _kOnboardingSeen = 'bus_onboarding_seen';
  static const String _kPendingEmail = 'bus_pending_email';
  static const String _kDeviceToken = 'bus_fcm_token_declare';
  static const String _kOrphanToken = 'bus_fcm_token_a_detacher';

  late final SharedPreferences _prefs;

  /// À appeler avant tout accès : `SharedPreferences` s'ouvre en asynchrone.
  Future<StorageService> init() async {
    _prefs = await SharedPreferences.getInstance();
    return this;
  }

  // --- Session ---------------------------------------------------------

  String? get token => _prefs.getString(_kToken);

  bool get hasSession => (token ?? '').isNotEmpty;

  /// Profil sérialisé de l'utilisateur, tel que renvoyé par l'API.
  ///
  /// Il permet d'afficher l'accueil sans attendre la réponse réseau ; il
  /// est rafraîchi dès que `/profil` répond.
  Map<String, dynamic>? get user {
    final raw = _prefs.getString(_kUser);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      // Donnée corrompue : mieux vaut repartir d'un profil vide que de
      // faire échouer le démarrage.
      return null;
    }
  }

  Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await _prefs.setString(_kToken, token);
    await _prefs.setString(_kUser, jsonEncode(user));
  }

  /// Met à jour le profil sans toucher au token.
  Future<void> saveUser(Map<String, dynamic> user) =>
      _prefs.setString(_kUser, jsonEncode(user));

  /// Efface la session, sans toucher aux traces de jeton d'appareil :
  /// un détachement resté en souffrance doit survivre à la déconnexion,
  /// c'est tout son intérêt.
  Future<void> clearSession() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
    await _prefs.remove(_kPendingEmail);
    await _prefs.remove(_kDeviceToken);
  }

  // --- Jeton d'appareil (FCM) -------------------------------------------

  /// Jeton effectivement déclaré au backend pour la session courante.
  ///
  /// Il sert à deux choses : ne pas rejouer un enregistrement déjà réussi
  /// à chaque ouverture, et savoir quoi détacher à la déconnexion même si
  /// Firebase ne répond plus.
  String? get declaredDeviceToken => _prefs.getString(_kDeviceToken);

  Future<void> saveDeclaredDeviceToken(String token) =>
      _prefs.setString(_kDeviceToken, token);

  Future<void> clearDeclaredDeviceToken() => _prefs.remove(_kDeviceToken);

  /// Jeton resté attaché à un compte quitté, faute de réseau au moment de
  /// la déconnexion.
  ///
  /// Sans cette trace, le téléphone continuerait de recevoir les alertes
  /// de l'utilisateur précédent : la tentative est rejouée au prochain
  /// démarrage, dès qu'une session le permet.
  String? get orphanDeviceToken => _prefs.getString(_kOrphanToken);

  Future<void> saveOrphanDeviceToken(String token) =>
      _prefs.setString(_kOrphanToken, token);

  Future<void> clearOrphanDeviceToken() => _prefs.remove(_kOrphanToken);

  // --- Parcours de première ouverture -----------------------------------

  bool get onboardingSeen => _prefs.getBool(_kOnboardingSeen) ?? false;

  Future<void> markOnboardingSeen() =>
      _prefs.setBool(_kOnboardingSeen, true);

  // --- Vérification en cours --------------------------------------------

  /// Adresse en attente de code, conservée pour que l'écran de saisie
  /// résiste à une mise en arrière-plan de l'application.
  String? get pendingEmail => _prefs.getString(_kPendingEmail);

  Future<void> savePendingEmail(String email) =>
      _prefs.setString(_kPendingEmail, email);

  Future<void> clearPendingEmail() => _prefs.remove(_kPendingEmail);
}
