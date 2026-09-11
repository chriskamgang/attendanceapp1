import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/api_config.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Suivi du bus en temps réel, diffusé par Reverb.
///
/// Le backend pousse chaque relevé GPS sur le canal `bus.{id}` ; l'écoute
/// évite d'attendre le prochain sondage et épargne la batterie.
///
/// Reverb parle le protocole Pusher, dont seuls quelques messages nous sont
/// utiles : souscrire à un canal public, puis lire les événements. Les
/// clients Pusher du marché ne visent que les serveurs hébergés — parler le
/// protocole directement est ici plus court qu'en contourner un.
///
/// Le service se veut discret : si le serveur temps réel est absent ou
/// injoignable, rien ne casse — le polling existant reste la voie de repli.
class RealtimeService extends GetxService {
  RealtimeService({required this.api});

  final ApiClient api;

  /// Vrai tant que la liaison est ouverte et le canal souscrit.
  final RxBool connected = false.obs;

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _ecoute;

  /// Canaux actuellement souscrits.
  ///
  /// L'étudiant en suit deux : « flotte », qui porte tous les bus en ligne,
  /// et celui de son propre bus, plus détaillé. Un seul abonnement ne
  /// suffirait donc pas.
  final Set<String> _canaux = <String>{};

  /// Config du serveur, lue une fois puis conservée.
  Map<String, dynamic>? _config;

  /// Délai avant reconnexion, doublé à chaque échec pour ne pas marteler
  /// un serveur éteint.
  Duration _attente = const Duration(seconds: 3);
  Timer? _reconnexion;

  /// Coupe toute reconnexion après fermeture volontaire.
  bool _ferme = false;

  /// Rappel invoqué à chaque position reçue.
  void Function(double latitude, double longitude, int? vitesse)? onPosition;

  /// Rappel invoqué quand le tour change d'état (départ, arrivée).
  void Function(Map<String, dynamic> tournee)? onTournee;

  /// Rappel invoqué à chaque battement de présence d'un bus de la flotte.
  ///
  /// Porte aussi le passage hors ligne, que la carte doit traiter pour
  /// retirer le bus plutôt que de le laisser figé à sa dernière position.
  void Function(Map<String, dynamic> presence)? onPresence;

  /// Souscrit à un canal, en gardant ceux déjà écoutés.
  Future<void> watch(String canal) async {
    if (canal.isEmpty || _canaux.contains(canal)) return;

    _canaux.add(canal);
    _ferme = false;

    if (_socket == null) {
      await _ouvrir();
      return;
    }

    _envoyer('pusher:subscribe', canal);
  }

  /// Quitte un canal sans toucher aux autres.
  ///
  /// Sert quand l'étudiant change de bus : le canal du précédent n'a plus
  /// d'intérêt, mais celui de la flotte reste utile.
  void unwatch(String canal) {
    if (!_canaux.remove(canal)) return;

    if (_socket != null) _envoyer('pusher:unsubscribe', canal);
  }

  /// Ferme la liaison ; le polling reprend seul la main.
  Future<void> stop() async {
    _ferme = true;
    _reconnexion?.cancel();

    if (_socket != null) {
      for (final canal in _canaux) {
        _envoyer('pusher:unsubscribe', canal);
      }
    }

    _canaux.clear();
    await _fermerSocket();
  }

  // --- Liaison ----------------------------------------------------------

  Future<void> _ouvrir() async {
    final config = await _lireConfig();

    if (config == null || _ferme) return;

    final cle = config['cle'] as String? ?? '';
    if (cle.isEmpty) return;

    final chiffre = config['chiffre'] as bool? ?? false;
    final port = (config['port'] as num?)?.toInt() ?? 8080;

    // Le chemin et les paramètres sont ceux qu'attend un serveur Pusher.
    final uri = Uri(
      scheme: chiffre ? 'wss' : 'ws',
      host: _hote(config['hote'] as String?),
      port: port,
      path: '/app/$cle',
      queryParameters: const {
        'protocol': '7',
        'client': 'insam-bus',
        'version': '1.0',
      },
    );

    try {
      final socket = WebSocketChannel.connect(uri);
      await socket.ready;

      if (_ferme) {
        await socket.sink.close();
        return;
      }

      _socket = socket;
      _ecoute = socket.stream.listen(
        _surMessage,
        onError: (_) => _surRupture(),
        onDone: _surRupture,
        cancelOnError: true,
      );

      // Toutes les souscriptions sont reposées : une reconnexion ne doit
      // pas laisser l'étudiant avec la moitié de sa carte muette.
      for (final canal in _canaux) {
        _envoyer('pusher:subscribe', canal);
      }

      connected.value = true;
      _attente = const Duration(seconds: 3);
    } catch (_) {
      // Serveur éteint, port fermé, TLS invalide : on réessaiera plus tard.
      _surRupture();
    }
  }

  /// Config du serveur temps réel, `null` si indisponible.
  Future<Map<String, dynamic>?> _lireConfig() async {
    if (_config != null) return _config;

    try {
      final reponse = await api.get('temps-reel');

      if (reponse['actif'] != true) return null;

      return _config = reponse;
    } on ApiException {
      // Backend trop ancien ou hors ligne : le polling suffit.
      return null;
    }
  }

  void _envoyer(String evenement, String canal) {
    _socket?.sink.add(
      jsonEncode({
        'event': evenement,
        'data': {'channel': canal},
      }),
    );
  }

  void _surRupture() {
    connected.value = false;
    _fermerSocket();

    if (_ferme || _canaux.isEmpty) return;

    // Reconnexion espacée : un serveur absent ne doit pas être martelé.
    _reconnexion?.cancel();
    _reconnexion = Timer(_attente, _ouvrir);
    _attente = Duration(seconds: (_attente.inSeconds * 2).clamp(3, 60));
  }

  Future<void> _fermerSocket() async {
    await _ecoute?.cancel();
    _ecoute = null;

    try {
      await _socket?.sink.close();
    } catch (_) {
      // La liaison était déjà rompue.
    }

    _socket = null;
    connected.value = false;
  }

  // --- Messages ---------------------------------------------------------

  void _surMessage(dynamic message) {
    final enveloppe = _decoder(message);
    if (enveloppe == null) return;

    final evenement = enveloppe['event'] as String? ?? '';

    // Les messages de service du protocole ne portent aucune donnée métier.
    if (evenement.startsWith('pusher:') ||
        evenement.startsWith('pusher_internal:')) {
      return;
    }

    final donnees = _decoder(enveloppe['data']);
    if (donnees == null) return;

    if (evenement.contains('position')) {
      final lat = (donnees['latitude'] as num?)?.toDouble();
      final lng = (donnees['longitude'] as num?)?.toDouble();

      if (lat != null && lng != null) {
        onPosition?.call(lat, lng, (donnees['vitesse_kmh'] as num?)?.toInt());
      }

      return;
    }

    if (evenement.contains('presence')) {
      onPresence?.call(donnees);
      return;
    }

    if (evenement.contains('tournee')) onTournee?.call(donnees);
  }

  /// Le corps d'un message arrive tantôt en texte JSON, tantôt décodé.
  Map<String, dynamic>? _decoder(dynamic data) {
    if (data is Map<String, dynamic>) return data;

    if (data is String && data.isNotEmpty) {
      try {
        final decode = jsonDecode(data);
        return decode is Map<String, dynamic> ? decode : null;
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  /// Hôte joignable depuis l'appareil.
  ///
  /// Le backend annonce l'hôte sur lequel Reverb écoute, souvent
  /// « localhost » : depuis un téléphone, cela désignerait le téléphone
  /// lui-même. On reprend alors l'hôte par lequel l'API est atteinte.
  String _hote(String? annonce) {
    final apiHote = Uri.parse(ApiConfig.baseUrl).host;

    if (annonce == null || annonce.isEmpty) return apiHote;

    const locales = {'localhost', '127.0.0.1', '0.0.0.0', '::1'};

    return locales.contains(annonce) ? apiHote : annonce;
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
