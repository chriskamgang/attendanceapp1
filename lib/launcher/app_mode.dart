import 'package:shared_preferences/shared_preferences.dart';

/// Les deux univers que porte l'application.
///
/// Chacun a son backend, sa session et sa pile de navigation ; ils ne
/// partagent que le stockage local — d'où le préfixage des clés côté bus.
enum AppMode {
  /// Pointage par géolocalisation (backend `rh.iues-insambot.com`).
  estuaireRh,

  /// Scolarité et transport de campus : l'espace de l'étudiant et du
  /// chauffeur. Il porte encore le nom `insamBus` côté code — c'est de là
  /// qu'il vient — mais rien ne le nomme ainsi à l'écran.
  insamBus;

  String get label => switch (this) {
        AppMode.estuaireRh => 'ESTUAIRE RH',
        AppMode.insamBus => 'ESTUAIRE RH',
      };

  /// Valeur écrite dans `SharedPreferences`.
  String get storageValue => switch (this) {
        AppMode.estuaireRh => 'estuaire_rh',
        AppMode.insamBus => 'insam_bus',
      };

  static AppMode? fromStorage(String? valeur) => switch (valeur) {
        'estuaire_rh' => AppMode.estuaireRh,
        'insam_bus' => AppMode.insamBus,
        _ => null,
      };
}

/// Mémorise l'univers choisi au lancement.
///
/// Le choix est posé une fois puis rejoué à chaque ouverture ; l'utilisateur
/// peut y revenir depuis les réglages de l'un ou l'autre espace.
class AppModeService {
  static final AppModeService _instance = AppModeService._internal();
  factory AppModeService() => _instance;
  AppModeService._internal();

  /// Clé volontairement hors du préfixe `bus_` : elle appartient au
  /// lanceur, commun aux deux espaces, et doit survivre à la déconnexion
  /// de l'un comme de l'autre.
  static const String _kMode = 'launcher_app_mode';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Univers retenu au dernier lancement, `null` à la première ouverture.
  Future<AppMode?> read() async {
    final prefs = await _store;
    return AppMode.fromStorage(prefs.getString(_kMode));
  }

  Future<void> save(AppMode mode) async {
    final prefs = await _store;
    await prefs.setString(_kMode, mode.storageValue);
  }

  /// Oublie le choix : la prochaine ouverture repassera par le lanceur.
  ///
  /// Les sessions des deux espaces sont laissées intactes — changer
  /// d'univers n'est pas se déconnecter.
  Future<void> clear() async {
    final prefs = await _store;
    await prefs.remove(_kMode);
  }
}

/// Qui vient d'entrer dans l'espace étudiant.
///
/// Le login du personnel porte une case « Je suis chauffeur » : cochée, elle
/// mène au même accueil, mais réglé d'emblée sur le numéro de téléphone —
/// c'est ainsi que le back-office identifie un chauffeur. Sans ce relais,
/// il devrait recocher la case une fois arrivé.
enum PorteEntree { etudiant, chauffeur }

/// Rôle annoncé au passage, lu une seule fois par l'accueil du transport.
///
/// Volontairement hors de `SharedPreferences` : l'information ne vaut que
/// pour la bascule en cours, et la retenir ferait rouvrir l'accueil en mode
/// chauffeur à la session suivante.
class PorteEntreeService {
  PorteEntreeService._();

  static PorteEntree? _attendue;

  static void annoncer(PorteEntree porte) => _attendue = porte;

  /// Renvoie le rôle annoncé et l'oublie aussitôt.
  static PorteEntree? consommer() {
    final porte = _attendue;
    _attendue = null;
    return porte;
  }
}
