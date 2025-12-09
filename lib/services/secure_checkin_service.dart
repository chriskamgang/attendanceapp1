import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'security_service.dart';
import 'security_api_service.dart';

/// Service de check-in sécurisé qui intègre les vérifications anti-fraude
///
/// Usage:
/// ```dart
/// final secureCheckin = SecureCheckinService();
/// final result = await secureCheckin.performSecureCheckIn(
///   userId: currentUser.id,
///   campusId: selectedCampus.id,
///   currentPosition: position,
/// );
///
/// if (result.success) {
///   // Check-in réussi
/// } else {
///   // Afficher message d'erreur: result.message
/// }
/// ```
class SecureCheckinService {
  final SecurityService _securityService = SecurityService();
  final SecurityApiService _securityApi = SecurityApiService();

  Position? _lastPosition;

  /// Effectue un check-in sécurisé avec toutes les vérifications anti-fraude
  Future<SecureCheckinResult> performSecureCheckIn({
    required int userId,
    required int campusId,
    required Position currentPosition,
    String? authToken,
  }) async {
    debugPrint('🔐 === DÉMARRAGE CHECK-IN SÉCURISÉ ===');

    // 1. Définir le token d'authentification
    if (authToken != null) {
      _securityApi.setAuthToken(authToken);
    }

    try {
      // 2. Vérifier le statut de sécurité du compte (backend)
      debugPrint('   📋 Étape 1/4: Vérification statut compte...');
      final statusCheck = await _securityApi.checkSecurityStatus(userId: userId);

      if (!statusCheck.allowed) {
        debugPrint('   ❌ Compte bloqué: ${statusCheck.reason}');
        return SecureCheckinResult(
          success: false,
          blocked: true,
          blockReason: statusCheck.reason,
          message: statusCheck.userMessage,
        );
      }

      debugPrint('   ✅ Statut compte OK (${statusCheck.violationsCount} violations)');

      // 3. Effectuer vérification de sécurité locale (détection fraude)
      debugPrint('   📋 Étape 2/4: Vérification sécurité locale...');
      final securityCheck = await _securityService.performSecurityCheck(
        currentPosition: currentPosition,
        previousPosition: _lastPosition,
      );

      debugPrint('   ${securityCheck.hasViolations ? "⚠️" : "✅"} Sécurité locale: '
          '${securityCheck.getViolationTypesFormatted()}');

      // 4. Si violations détectées, les signaler au backend
      if (securityCheck.hasViolations) {
        debugPrint('   📋 Étape 3/4: Signalement violations au backend...');
        final reportResult = await _securityApi.reportViolation(
          userId: userId,
          securityResult: securityCheck,
        );

        if (reportResult['success'] == true) {
          debugPrint('   ✅ Violations signalées (ID: ${reportResult['data']['violation_id']})');
        } else {
          debugPrint('   ⚠️ Échec signalement violations: ${reportResult['error']}');
        }

        // BLOQUER LE CHECK-IN en cas de violations
        return SecureCheckinResult(
          success: false,
          blocked: true,
          blockReason: 'security_violations',
          message: _getViolationMessage(securityCheck),
          securityCheck: securityCheck,
        );
      }

      // 5. Tout est OK, procéder au check-in
      debugPrint('   📋 Étape 4/4: Envoi check-in au backend...');

      // ICI: Appeler votre API de check-in habituelle
      // final checkinResponse = await yourApiService.checkIn(...);

      // Pour l'exemple, on simule un succès
      debugPrint('   ✅ Check-in réussi!');

      // Sauvegarder la position pour prochaine vérification GPS
      _lastPosition = currentPosition;

      return SecureCheckinResult(
        success: true,
        blocked: false,
        message: 'Check-in effectué avec succès!',
        securityCheck: securityCheck,
      );

    } catch (e) {
      debugPrint('   ❌ Erreur lors du check-in sécurisé: $e');
      return SecureCheckinResult(
        success: false,
        blocked: false,
        message: 'Erreur technique: ${e.toString()}',
      );
    } finally {
      debugPrint('🔐 === FIN CHECK-IN SÉCURISÉ ===');
    }
  }

  /// Message d'erreur personnalisé selon les violations
  String _getViolationMessage(SecurityCheckResult check) {
    final violations = <String>[];

    if (check.violations['vpn'] == true) {
      violations.add('VPN actif');
    }
    if (check.violations['mock'] == true) {
      violations.add('Fake GPS détecté');
    }
    if (check.violations['root'] == true) {
      violations.add('Appareil rooté/jailbreaké');
    }
    if (check.violations['emulator'] == true) {
      violations.add('Émulateur détecté');
    }
    if (check.violations['gps_inconsistent'] == true) {
      violations.add('Position GPS incohérente');
    }

    if (violations.isEmpty) {
      return 'Violation de sécurité détectée. Veuillez contacter l\'administrateur.';
    }

    return 'Check-in bloqué:\n\n'
        '${violations.map((v) => '• $v').join('\n')}\n\n'
        'Veuillez désactiver ces éléments et réessayer. '
        'En cas de problème, contactez votre administrateur.';
  }

  /// Nettoyer les ressources
  void dispose() {
    _securityService.dispose();
  }
}

/// Résultat d'un check-in sécurisé
class SecureCheckinResult {
  final bool success;
  final bool blocked;
  final String? blockReason;
  final String message;
  final SecurityCheckResult? securityCheck;

  SecureCheckinResult({
    required this.success,
    required this.blocked,
    this.blockReason,
    required this.message,
    this.securityCheck,
  });

  /// Est-ce que le compte est suspendu?
  bool get isAccountSuspended => blockReason == 'account_suspended';

  /// Est-ce que c'est un blocage temporaire (trop de violations)?
  bool get isTemporaryBlock => blockReason == 'too_many_violations';

  /// Est-ce que c'est un blocage dû à des violations détectées maintenant?
  bool get isSecurityBlock => blockReason == 'security_violations';

  @override
  String toString() {
    return 'SecureCheckinResult('
        'success: $success, '
        'blocked: $blocked, '
        'blockReason: $blockReason, '
        'message: $message'
        ')';
  }
}
