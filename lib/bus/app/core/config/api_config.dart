/// Adresse du backend Laravel d'INSAM BUS.
///
/// Cible le serveur de développement local, le temps de l'intégration dans
/// l'application Estuaire RH ; `API_URL` permet de viser une autre adresse
/// sans recompiler (voir [_override]).
///
/// Cette configuration ne concerne que l'espace INSAM BUS. L'espace Estuaire
/// RH garde la sienne, restée en production — voir `lib/utils/constants.dart`.
abstract class ApiConfig {
  ApiConfig._();

  /// Surcharge au lancement, pour viser un autre serveur sans recompiler :
  /// `flutter run --dart-define=API_URL=https://insam-bus.insamtechs.com`
  ///
  /// C'est aussi la voie à emprunter si l'adresse du poste de développement
  /// change : le téléphone n'a pas de `localhost` commun avec la machine, il
  /// doit viser son adresse sur le réseau local.
  static const String _override = String.fromEnvironment('API_URL');

  /// Serveur de développement, lancé par `./server.sh` depuis `SystemRH`
  /// (port 8000, écoute sur 0.0.0.0).
  ///
  /// Les deux espaces partagent désormais ce serveur : le backend d'INSAM
  /// BUS a été fusionné dans celui d'Estuaire RH, et répond sous le préfixe
  /// `/api/bus`. L'ancien port 8001 n'écoute plus.
  ///
  /// L'adresse est celle du poste sur le réseau local, et non `localhost` :
  /// depuis un téléphone, `localhost` désignerait le téléphone lui-même.
  /// Elle change avec le réseau — d'où [_override] pour ne pas recompiler.
  static const String _dev = 'http://192.168.169.157:8000';

  /// Serveur de production, à rétablir comme défaut une fois l'intégration
  /// validée.
  // ignore: unused_field
  static const String _prod = 'https://insam-bus.insamtechs.com';

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;

    return _dev;
  }

  /// Racine des routes du transport.
  ///
  /// La fusion des deux backends a monté l'API d'INSAM BUS sous `/api/bus`,
  /// aux côtés de celle d'Estuaire RH restée sur `/api` : le préfixe est
  /// posé ici plutôt que dans chaque appel, les services continuant de
  /// demander `etudiant/mon-bus` sans rien savoir de ce voisinage.
  static String get apiUrl => '$baseUrl/api/bus';

  /// Au-delà, la requête est abandonnée : l'écran reprend la main plutôt
  /// que de rester bloqué sur son indicateur de chargement.
  static const Duration timeout = Duration(seconds: 20);
}
