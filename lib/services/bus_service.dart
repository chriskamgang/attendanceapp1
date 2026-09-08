import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'storage_service.dart';

class BusService {
  final StorageService _storageService = StorageService();
  static final http.Client _client = http.Client();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storageService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _get(String endpoint, {Map<String, String>? queryParams}) async {
    String url = '${ApiConstants.baseUrl}$endpoint';
    if (queryParams != null && queryParams.isNotEmpty) {
      url += '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }
    return _client.get(Uri.parse(url), headers: await _getHeaders()).timeout(
      const Duration(seconds: 15),
      onTimeout: () => http.Response('{"message": "Delai depasse"}', 408),
    );
  }

  Future<http.Response> _post(String endpoint, {Map<String, dynamic>? body}) async {
    return _client.post(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: await _getHeaders(),
      body: body != null ? json.encode(body) : null,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => http.Response('{"message": "Delai depasse"}', 408),
    );
  }

  Future<http.Response> _put(String endpoint, {Map<String, dynamic>? body}) async {
    return _client.put(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: await _getHeaders(),
      body: body != null ? json.encode(body) : null,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => http.Response('{"message": "Delai depasse"}', 408),
    );
  }

  Map<String, dynamic> _parse(http.Response response) {
    try {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': false, 'message': 'Reponse invalide'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur de parsing'};
    }
  }

  // ========== AUTH BUS ==========

  Future<Map<String, dynamic>> register(String pin) async {
    try {
      final response = await _post(ApiConstants.busRegister, body: {'pin': pin});
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion: $e'};
    }
  }

  Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await _get(ApiConstants.busStatus);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion: $e'};
    }
  }

  Future<Map<String, dynamic>> disconnect() async {
    try {
      final response = await _post(ApiConstants.busDisconnect);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion: $e'};
    }
  }

  // ========== RESEAU PUBLIC ==========

  Future<Map<String, dynamic>> getPointsRamassage() async {
    try {
      final response = await _get(ApiConstants.busPointsRamassage);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getLieux() async {
    try {
      final response = await _get(ApiConstants.busLieux);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getLignes() async {
    try {
      final response = await _get(ApiConstants.busLignes);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getParcours() async {
    try {
      final response = await _get(ApiConstants.busParcours);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getTarifs() async {
    try {
      final response = await _get(ApiConstants.busTarifs);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getBusEnLigne() async {
    try {
      final response = await _get(ApiConstants.busEnLigne);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== ETUDIANT - SUIVI ==========

  Future<Map<String, dynamic>> getMonBus() async {
    try {
      final response = await _get(ApiConstants.busMonBus);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> updatePointRamassage(int lieuId) async {
    try {
      final response = await _put(ApiConstants.busPointRamassage, body: {'lieu_ramassage_id': lieuId});
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getMesTrajets({int page = 1}) async {
    try {
      final response = await _get(ApiConstants.busMesTrajets, queryParams: {'page': '$page'});
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== ABONNEMENTS ==========

  Future<Map<String, dynamic>> getAbonnements({int page = 1}) async {
    try {
      final response = await _get(ApiConstants.busAbonnements, queryParams: {'page': '$page'});
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> createAbonnement({
    required int tarifId,
    String? dateDebut,
    String? moyenPaiement,
    String? referencePaiement,
  }) async {
    try {
      final body = <String, dynamic>{'tarif_id': tarifId};
      if (dateDebut != null) body['date_debut'] = dateDebut;
      if (moyenPaiement != null) body['moyen_paiement'] = moyenPaiement;
      if (referencePaiement != null) body['reference_paiement'] = referencePaiement;

      final response = await _post(ApiConstants.busAbonnements, body: body);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getAbonnementActif() async {
    try {
      final response = await _get(ApiConstants.busAbonnementActif);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getQrPass() async {
    try {
      final response = await _get(ApiConstants.busQrPass);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> payerAbonnement(int abonnementId, {String? telephone, String? provider}) async {
    try {
      final body = <String, dynamic>{};
      if (telephone != null) body['telephone'] = telephone;
      if (provider != null) body['provider'] = provider;

      final response = await _post('${ApiConstants.busAbonnements}/$abonnementId/payer', body: body);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getStatutPaiement(int abonnementId) async {
    try {
      final response = await _get('${ApiConstants.busAbonnements}/$abonnementId/statut-paiement');
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ========== NOTIFICATIONS BUS ==========

  Future<Map<String, dynamic>> getNotifications({int page = 1}) async {
    try {
      final response = await _get(ApiConstants.busNotifications, queryParams: {'page': '$page'});
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> getUnreadCount() async {
    try {
      final response = await _get(ApiConstants.busNotificationsNonLues);
      return _parse(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }
}
