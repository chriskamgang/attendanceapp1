import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'security_service.dart';
import '../utils/constants.dart';

/// Service API pour communiquer avec le backend Laravel concernant la sécurité
class SecurityApiService {
  static final SecurityApiService _instance = SecurityApiService._internal();
  factory SecurityApiService() => _instance;
  SecurityApiService._internal();

  // Utiliser l'URL centralisée depuis les constantes
  static String get baseUrl => ApiConstants.baseUrl;

  String? _authToken;

  /// Définir le token d'authentification
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Headers par défaut avec authentification
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  /// 1. Signaler une violation de sécurité au backend
  Future<Map<String, dynamic>> reportViolation({
    required int userId,
    required SecurityCheckResult securityResult,
  }) async {
    try {
      debugPrint('📤 Envoi violation au backend...');

      final response = await http.post(
        Uri.parse('$baseUrl/security/report-violation'),
        headers: _headers,
        body: jsonEncode({
          'user_id': userId,
          ...securityResult.toJson(),
        }),
      );

      debugPrint('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Violation signalée avec succès: ${data['violation_id']}');
        return {
          'success': true,
          'data': data,
        };
      } else {
        debugPrint('❌ Erreur serveur: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Erreur serveur: ${response.statusCode}',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('❌ Exception lors de l\'envoi de violation: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 2. Vérifier le statut de sécurité avant un check-in
  /// Retourne si l'utilisateur est autorisé à pointer
  Future<SecurityStatusResponse> checkSecurityStatus({
    required int userId,
  }) async {
    try {
      debugPrint('🔐 Vérification statut sécurité pour user $userId...');

      final response = await http.post(
        Uri.parse('$baseUrl/security/check-status'),
        headers: _headers,
        body: jsonEncode({
          'user_id': userId,
        }),
      );

      debugPrint('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Statut OK: autorisé');
        return SecurityStatusResponse(
          allowed: data['allowed'] ?? true,
          reason: data['reason'],
          message: data['message'] ?? '',
          violationsCount: data['violations_count'] ?? 0,
        );
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        debugPrint('⚠️ Compte bloqué: ${data['reason']}');
        return SecurityStatusResponse(
          allowed: false,
          reason: data['reason'] ?? 'unknown',
          message: data['message'] ?? 'Accès refusé',
          violationsCount: 0,
        );
      } else {
        debugPrint('❌ Erreur serveur: ${response.statusCode}');
        return SecurityStatusResponse(
          allowed: true, // En cas d'erreur, on autorise (fail-open)
          reason: 'server_error',
          message: 'Erreur de vérification, accès autorisé temporairement',
          violationsCount: 0,
        );
      }
    } catch (e) {
      debugPrint('❌ Exception vérification statut: $e');
      // En cas d'erreur réseau, on autorise (fail-open)
      return SecurityStatusResponse(
        allowed: true,
        reason: 'network_error',
        message: 'Erreur réseau, accès autorisé temporairement',
        violationsCount: 0,
      );
    }
  }

  /// 3. Obtenir l'historique des violations de l'utilisateur
  Future<Map<String, dynamic>> getViolationsHistory({
    required int userId,
    int limit = 20,
  }) async {
    try {
      debugPrint('📜 Récupération historique violations pour user $userId...');

      final response = await http.get(
        Uri.parse('$baseUrl/security/violations/history?user_id=$userId&limit=$limit'),
        headers: _headers,
      );

      debugPrint('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Historique récupéré: ${data['total']} violations');
        return {
          'success': true,
          'violations': data['violations'] ?? [],
          'total': data['total'] ?? 0,
        };
      } else {
        debugPrint('❌ Erreur serveur: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Erreur serveur: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('❌ Exception récupération historique: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

/// Réponse de la vérification du statut de sécurité
class SecurityStatusResponse {
  final bool allowed;
  final String? reason;
  final String message;
  final int violationsCount;

  SecurityStatusResponse({
    required this.allowed,
    this.reason,
    required this.message,
    required this.violationsCount,
  });

  /// Message utilisateur formaté
  String get userMessage {
    if (allowed) {
      if (violationsCount > 0) {
        return 'Vous avez $violationsCount violation(s) enregistrée(s). '
            'Veuillez respecter les règles d\'utilisation.';
      }
      return 'Statut de sécurité: OK';
    }

    // Messages personnalisés selon la raison
    switch (reason) {
      case 'account_suspended':
        return 'Votre compte a été suspendu suite à des violations de sécurité répétées. '
            'Veuillez contacter votre administrateur.';
      case 'too_many_violations':
        return 'Trop de tentatives de fraude détectées. Votre compte a été temporairement bloqué. '
            'Contactez votre administrateur.';
      default:
        return message;
    }
  }

  /// Icône appropriée selon le statut
  String get icon {
    if (allowed) {
      return violationsCount > 0 ? '⚠️' : '✅';
    }
    return '🚫';
  }

  @override
  String toString() {
    return 'SecurityStatusResponse('
        'allowed: $allowed, '
        'reason: $reason, '
        'message: $message, '
        'violationsCount: $violationsCount'
        ')';
  }
}
