import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Verifie si le dispositif supporte la biometrie
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Demande l'authentification biometrique (Face ID / empreinte)
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Veuillez vous authentifier pour acceder a l\'application',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permet aussi PIN/pattern en fallback
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
