import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:safe_device/safe_device.dart';
import 'package:trust_location/trust_location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// Service de détection anti-fraude pour l'application
/// Détecte: VPN, Mock GPS, Root/Jailbreak, Émulateurs, GPS incohérent
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Résultat complet d'une vérification de sécurité
  SecurityCheckResult? _lastCheckResult;

  /// Obtenir le dernier résultat de vérification
  SecurityCheckResult? get lastCheckResult => _lastCheckResult;

  /// Effectue une vérification complète de sécurité
  /// Retourne un [SecurityCheckResult] avec tous les détails
  Future<SecurityCheckResult> performSecurityCheck({
    Position? currentPosition,
    Position? previousPosition,
  }) async {
    debugPrint('🔐 SecurityService: Démarrage vérification sécurité...');

    final result = SecurityCheckResult(
      timestamp: DateTime.now(),
      violations: {},
      deviceInfo: {},
    );

    try {
      // 1. Détection VPN
      result.violations['vpn'] = await _checkVPN();
      debugPrint('   ✓ VPN check: ${result.violations['vpn']}');

      // 2. Détection Mock Location (Fake GPS)
      result.violations['mock'] = await _checkMockLocation();
      debugPrint('   ✓ Mock GPS check: ${result.violations['mock']}');

      // 3. Détection Root/Jailbreak
      result.violations['root'] = await _checkRootJailbreak();
      debugPrint('   ✓ Root/Jailbreak check: ${result.violations['root']}');

      // 4. Détection Émulateur
      result.violations['emulator'] = await _checkEmulator();
      debugPrint('   ✓ Emulator check: ${result.violations['emulator']}');

      // 5. Vérification GPS cohérent
      if (currentPosition != null && previousPosition != null) {
        result.violations['gps_inconsistent'] =
            _checkGPSConsistency(currentPosition, previousPosition);
        debugPrint('   ✓ GPS consistency check: ${result.violations['gps_inconsistent']}');
      } else {
        result.violations['gps_inconsistent'] = false;
      }

      // 6. Collecter informations appareil
      result.deviceInfo = await _collectDeviceInfo();

      // Calculer si des violations ont été détectées
      result.hasViolations = result.violations.values.any((v) => v == true);

      debugPrint('🔐 Vérification terminée. Violations: ${result.hasViolations}');

    } catch (e) {
      debugPrint('❌ Erreur lors de la vérification sécurité: $e');
      result.error = e.toString();
    }

    _lastCheckResult = result;
    return result;
  }

  /// 1. Détection VPN
  Future<bool> _checkVPN() async {
    try {
      // Méthode 1: Vérifier l'interface réseau (Android/iOS)
      if (Platform.isAndroid || Platform.isIOS) {
        final wifiName = await _networkInfo.getWifiName();
        final wifiIP = await _networkInfo.getWifiIP();

        // Si pas de WiFi détecté mais connecté, possiblement VPN
        if (wifiName == null && wifiIP != null) {
          debugPrint('   ⚠️ VPN détecté: Pas de WiFi mais IP présente');
          return true;
        }

        // Vérifier plages IP VPN communes
        if (wifiIP != null) {
          if (_isVPNIPRange(wifiIP)) {
            debugPrint('   ⚠️ VPN détecté: Plage IP suspecte ($wifiIP)');
            return true;
          }
        }
      }

      // Méthode 2: SafeDevice check
      final isOnExternalStorage = await SafeDevice.isOnExternalStorage;
      if (isOnExternalStorage) {
        debugPrint('   ⚠️ App sur stockage externe (suspect)');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('   ❌ Erreur détection VPN: $e');
      return false;
    }
  }

  /// Vérifie si l'IP est dans une plage VPN commune
  bool _isVPNIPRange(String ip) {
    // Plages IP VPN courantes: 10.x.x.x, 172.16-31.x.x
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    final firstOctet = int.tryParse(parts[0]) ?? 0;
    final secondOctet = int.tryParse(parts[1]) ?? 0;

    // 10.0.0.0/8 (souvent utilisé par VPN)
    if (firstOctet == 10) return true;

    // 172.16.0.0/12 (plage privée utilisée par VPN)
    if (firstOctet == 172 && secondOctet >= 16 && secondOctet <= 31) {
      return true;
    }

    return false;
  }

  /// 2. Détection Mock Location (Fake GPS)
  Future<bool> _checkMockLocation() async {
    try {
      // Utiliser trust_location package
      TrustLocation.start(5); // Intervalle 5 secondes

      // Attendre un peu pour obtenir le résultat
      await Future.delayed(const Duration(seconds: 2));

      final isMockLocation = await TrustLocation.isMockLocation ?? false;

      if (isMockLocation) {
        debugPrint('   ⚠️ Mock Location détecté!');
      }

      return isMockLocation;
    } catch (e) {
      debugPrint('   ❌ Erreur détection Mock Location: $e');
      return false;
    }
  }

  /// 3. Détection Root/Jailbreak
  Future<bool> _checkRootJailbreak() async {
    try {
      // Utiliser flutter_jailbreak_detection
      final jailbroken = await FlutterJailbreakDetection.jailbroken;

      if (jailbroken) {
        debugPrint('   ⚠️ Device Jailbreaké/Rooté détecté!');
      }

      // Double vérification avec safe_device
      final isRealDevice = await SafeDevice.isRealDevice;
      if (!isRealDevice) {
        debugPrint('   ⚠️ Device non authentique (possiblement modifié)');
        return true;
      }

      return jailbroken;
    } catch (e) {
      debugPrint('   ❌ Erreur détection Root/Jailbreak: $e');
      return false;
    }
  }

  /// 4. Détection Émulateur
  Future<bool> _checkEmulator() async {
    try {
      // Méthode 1: SafeDevice
      final isRealDevice = await SafeDevice.isRealDevice;
      if (!isRealDevice) {
        debugPrint('   ⚠️ Émulateur détecté (SafeDevice)');
        return true;
      }

      // Méthode 2: Vérifier device info
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;

        // Patterns d'émulateurs Android
        final suspiciousPatterns = [
          'google_sdk',
          'emulator',
          'android sdk',
          'goldfish',
          'generic',
          'vbox',
          'genymotion',
        ];

        final model = androidInfo.model.toLowerCase();
        final brand = androidInfo.brand.toLowerCase();
        final product = androidInfo.product.toLowerCase();
        final hardware = androidInfo.hardware.toLowerCase();

        for (final pattern in suspiciousPatterns) {
          if (model.contains(pattern) ||
              brand.contains(pattern) ||
              product.contains(pattern) ||
              hardware.contains(pattern)) {
            debugPrint('   ⚠️ Émulateur détecté: Pattern "$pattern" trouvé');
            return true;
          }
        }

        // Vérifier si c'est un device physique réel
        if (!androidInfo.isPhysicalDevice) {
          debugPrint('   ⚠️ Émulateur détecté: isPhysicalDevice = false');
          return true;
        }
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;

        // Sur iOS, vérifier si c'est un simulateur
        if (!iosInfo.isPhysicalDevice) {
          debugPrint('   ⚠️ Simulateur iOS détecté');
          return true;
        }

        // Vérifier model suspect
        if (iosInfo.model.toLowerCase().contains('simulator')) {
          debugPrint('   ⚠️ Simulateur iOS détecté (model)');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('   ❌ Erreur détection Émulateur: $e');
      return false;
    }
  }

  /// 5. Vérification GPS cohérent
  bool _checkGPSConsistency(Position current, Position previous) {
    // Calculer la distance entre les deux positions
    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );

    // Calculer le temps écoulé
    final timeDiff = current.timestamp != null && previous.timestamp != null
        ? current.timestamp!.difference(previous.timestamp!).inSeconds
        : 0;

    if (timeDiff <= 0) return false;

    // Calculer la vitesse (m/s)
    final speed = distance / timeDiff;

    // Vitesse max réaliste: 50 m/s (~180 km/h)
    // Si supérieur, probablement GPS modifié
    if (speed > 50) {
      debugPrint('   ⚠️ GPS incohérent: Vitesse impossible (${speed.toStringAsFixed(2)} m/s)');
      return true;
    }

    // Vérifier changement brusque d'altitude (>100m/s)
    if (current.altitude != null && previous.altitude != null) {
      final altitudeDiff = (current.altitude! - previous.altitude!).abs();
      final altitudeSpeed = altitudeDiff / timeDiff;

      if (altitudeSpeed > 100) {
        debugPrint('   ⚠️ GPS incohérent: Changement altitude impossible');
        return true;
      }
    }

    // Vérifier précision GPS (accuracy)
    if (current.accuracy > 100) {
      debugPrint('   ⚠️ GPS incohérent: Précision trop faible (${current.accuracy}m)');
      return true;
    }

    return false;
  }

  /// Collecter informations complètes de l'appareil
  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    final info = <String, dynamic>{};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        info['platform'] = 'Android';
        info['model'] = androidInfo.model;
        info['manufacturer'] = androidInfo.manufacturer;
        info['brand'] = androidInfo.brand;
        info['device'] = androidInfo.device;
        info['product'] = androidInfo.product;
        info['hardware'] = androidInfo.hardware;
        info['os_version'] = 'Android ${androidInfo.version.release}';
        info['sdk_int'] = androidInfo.version.sdkInt;
        info['is_physical_device'] = androidInfo.isPhysicalDevice;
        info['board'] = androidInfo.board;
        info['display'] = androidInfo.display;
        info['fingerprint'] = androidInfo.fingerprint;
        info['id'] = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        info['platform'] = 'iOS';
        info['model'] = iosInfo.model;
        info['name'] = iosInfo.name;
        info['system_name'] = iosInfo.systemName;
        info['os_version'] = iosInfo.systemVersion;
        info['is_physical_device'] = iosInfo.isPhysicalDevice;
        info['identifier_for_vendor'] = iosInfo.identifierForVendor;
        info['localized_model'] = iosInfo.localizedModel;
        info['utsname_machine'] = iosInfo.utsname.machine;
      }

      // Informations réseau
      try {
        final wifiName = await _networkInfo.getWifiName();
        final wifiIP = await _networkInfo.getWifiIP();
        info['wifi_name'] = wifiName;
        info['wifi_ip'] = wifiIP;
      } catch (e) {
        debugPrint('   ⚠️ Impossible de récupérer info réseau: $e');
      }

    } catch (e) {
      debugPrint('   ❌ Erreur collecte device info: $e');
      info['error'] = e.toString();
    }

    return info;
  }

  /// Nettoyer les ressources
  void dispose() {
    try {
      TrustLocation.stop();
    } catch (e) {
      debugPrint('   ⚠️ Erreur lors du nettoyage: $e');
    }
  }
}

/// Résultat d'une vérification de sécurité
class SecurityCheckResult {
  final DateTime timestamp;
  Map<String, bool> violations;
  Map<String, dynamic> deviceInfo;
  bool hasViolations;
  String? error;

  SecurityCheckResult({
    required this.timestamp,
    required this.violations,
    required this.deviceInfo,
    this.hasViolations = false,
    this.error,
  });

  /// Convertir en JSON pour envoi API
  Map<String, dynamic> toJson() {
    return {
      'violation_type': violations,
      'device_info': deviceInfo,
      'occurred_at': timestamp.toUtc().toIso8601String(),
    };
  }

  /// Types de violations formatés pour affichage
  String getViolationTypesFormatted() {
    final types = <String>[];
    if (violations['vpn'] == true) types.add('VPN');
    if (violations['mock'] == true) types.add('Fake GPS');
    if (violations['root'] == true) types.add('Root/Jailbreak');
    if (violations['emulator'] == true) types.add('Émulateur');
    if (violations['gps_inconsistent'] == true) types.add('GPS Incohérent');

    return types.isEmpty ? 'Aucune' : types.join(', ');
  }

  /// Sévérité calculée (côté client, pour info)
  String getSeverity() {
    int score = 0;
    if (violations['vpn'] == true) score += 3;
    if (violations['mock'] == true) score += 4;
    if (violations['root'] == true) score += 3;
    if (violations['emulator'] == true) score += 2;
    if (violations['gps_inconsistent'] == true) score += 2;

    if (score >= 6) return 'critical';
    if (score >= 4) return 'high';
    if (score >= 2) return 'medium';
    return 'low';
  }

  @override
  String toString() {
    return 'SecurityCheckResult('
        'timestamp: $timestamp, '
        'hasViolations: $hasViolations, '
        'violations: ${getViolationTypesFormatted()}, '
        'severity: ${getSeverity()}'
        ')';
  }
}
