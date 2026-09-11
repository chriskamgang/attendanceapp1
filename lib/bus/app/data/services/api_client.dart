import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart' hide Response;
import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import 'api_exception.dart';

/// Client HTTP de l'API INSAM BUS.
///
/// Il porte le token de session, encode les corps en JSON et traduit les
/// réponses d'erreur en [ApiException] : les écrans n'ont jamais à lire un
/// code HTTP.
class ApiClient extends GetxService {
  /// Le client HTTP est injectable pour que les tests puissent simuler une
  /// panne réseau — que le harnais de test ne sait pas produire, toute
  /// requête y répondant par un code d'erreur plutôt que par un échec.
  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  /// Jeton Sanctum de la session courante, `null` hors connexion.
  ///
  /// Il n'est posé que par `SessionService`, qui le lit depuis le stockage
  /// au démarrage et l'efface à la déconnexion.
  String? token;

  /// Appelé quand le backend refuse le token : la session doit se fermer.
  ///
  /// Le rappel est posé par `SessionService`, seul responsable de l'état
  /// d'authentification — le client, lui, ne fait que le signaler.
  void Function()? onUnauthenticated;

  /// Appelé après une réponse réussie ayant suivi un échec réseau.
  ///
  /// C'est le seul signal fiable d'un retour de connexion sans surveiller
  /// le réseau en continu : `PushService` s'en sert pour rejouer un
  /// enregistrement de jeton qui n'était pas passé.
  void Function()? onReconnected;

  /// Vrai dès qu'une requête a échoué faute de réseau, jusqu'à la
  /// prochaine réponse aboutie.
  bool _horsLigne = false;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> get(String path) =>
      _send(() => _http.get(_uri(path), headers: _headers));

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) => _send(
    () => _http.post(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body ?? const {}),
    ),
  );

  Future<Map<String, dynamic>> put(
    String path, [
    Map<String, dynamic>? body,
  ]) => _send(
    () => _http.put(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body ?? const {}),
    ),
  );

  Future<Map<String, dynamic>> delete(
    String path, [
    Map<String, dynamic>? body,
  ]) => _send(
    () => _http.delete(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body ?? const {}),
    ),
  );

  /// Construit l'adresse d'un appel.
  ///
  /// Un chemin ordinaire vise le transport (`/api/bus`). Un chemin préfixé
  /// d'un `/` vise la racine du serveur : la scolarité de l'étudiant —
  /// emploi du temps, évaluation des cours — vit sous `/api`, l'espace RH
  /// l'ayant précédée. Les deux partagent le même hôte et le même jeton,
  /// d'où ce passage par le même client plutôt qu'un second, qui aurait
  /// dupliqué la gestion du token et des pannes réseau.
  Uri _uri(String path) => Uri.parse(
    path.startsWith('/') ? '${ApiConfig.baseUrl}$path' : '${ApiConfig.apiUrl}/$path',
  );

  /// Exécute la requête et transforme toute réponse non conforme en
  /// [ApiException].
  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    late final http.Response response;

    try {
      response = await request().timeout(ApiConfig.timeout);
    } on TimeoutException {
      _horsLigne = true;
      throw const ApiException.offline();
    } catch (_) {
      // Socket fermé, DNS introuvable, serveur éteint : même conclusion
      // pour l'utilisateur.
      _horsLigne = true;
      throw const ApiException.offline();
    }

    // Le serveur a répondu — quel que soit son code : la connexion est
    // rétablie.
    if (_horsLigne) {
      _horsLigne = false;
      onReconnected?.call();
    }

    final body = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (response.statusCode == 401) {
      onUnauthenticated?.call();
    }

    throw ApiException(
      _messageDe(body, response.statusCode),
      statusCode: response.statusCode,
      reason: body['raison'] as String?,
      errors: _erreursDe(body),
    );
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return const {};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } on FormatException {
      // Une page d'erreur HTML plutôt que du JSON : le corps ne nous
      // apprend rien de plus que le code de statut.
      return const {};
    }
  }

  String _messageDe(Map<String, dynamic> body, int status) {
    final message = body['message'];
    if (message is String && message.isNotEmpty) return message;

    return switch (status) {
      401 => 'Ta session a expiré. Reconnecte-toi.',
      403 => 'Tu n’as pas accès à cette ressource.',
      404 => 'Ressource introuvable.',
      429 => 'Trop de tentatives. Patiente un instant.',
      >= 500 => 'Le serveur rencontre un problème. Réessaie plus tard.',
      _ => 'Une erreur est survenue.',
    };
  }

  /// Convertit le bloc `errors` de Laravel en messages par champ.
  Map<String, List<String>> _erreursDe(Map<String, dynamic> body) {
    final raw = body['errors'];
    if (raw is! Map) return const {};

    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        (value is List ? value : [value]).map((e) => e.toString()).toList(),
      ),
    );
  }

  @override
  void onClose() {
    _http.close();
    super.onClose();
  }
}
