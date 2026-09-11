import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/services/api_exception.dart';
import '../../../data/services/session_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../routes/app_pages.dart';

/// Ce que l'écran demande à l'étudiant.
enum PinMode {
  /// Inscription : l'étudiant choisit son code, saisi deux fois.
  inscription,

  /// Connexion : il saisit le code de son compte.
  connexion,
}

/// Écran du code à quatre chiffres.
///
/// Il sert les deux bouts du parcours : choisir le code, ce qui vaut
/// inscription, et le redemander à chaque connexion.
class PinController extends GetxController {
  final SessionService _session = Get.find<SessionService>();
  final StorageService _storage = Get.find<StorageService>();

  static const int pinLength = 4;

  final List<TextEditingController> digits = List.generate(
    pinLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> nodes = List.generate(pinLength, (_) => FocusNode());

  final RxString error = ''.obs;
  final RxBool loading = false.obs;

  /// Case qui a le focus : elle seule montre le curseur, les autres
  /// resteraient des repères clignotants sans rapport avec la frappe.
  final RxInt active = 0.obs;

  /// Deuxième saisie, en mode [PinMode.choisir] : l'écran demande d'abord
  /// le code, puis sa confirmation.
  final RxBool confirming = false.obs;
  String _premiereSaisie = '';

  late final PinMode mode;

  /// Adresse concernée, pour la connexion comme pour l'affichage.
  late final String email;

  String get pin => digits.map((d) => d.text).join();

  bool get isComplete => pin.length == pinLength;

  String get titre => switch (mode) {
    PinMode.inscription =>
      confirming.value ? 'Confirme ton\ncode.' : 'Choisis ton\ncode.',
    PinMode.connexion => 'Ton code.',
  };

  String get consigne => switch (mode) {
    PinMode.inscription => confirming.value
        ? 'Saisis-le une seconde fois pour être sûr de t’en souvenir.'
        : 'Quatre chiffres, à retenir : ils ouvriront l’application à '
              'chaque fois.',
    PinMode.connexion => 'Saisis ton code à 4 chiffres pour ouvrir ta session.',
  };

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments as Map<String, dynamic>? ?? const {};
    mode = args['mode'] as PinMode? ?? PinMode.connexion;
    email = args['email'] as String? ?? _storage.pendingEmail ?? '';

    for (var i = 0; i < pinLength; i++) {
      nodes[i].addListener(() {
        if (nodes[i].hasFocus) active.value = i;
      });
    }
  }

  @override
  void onReady() {
    super.onReady();

    // Le clavier s'ouvre de lui-même : l'écran n'a qu'une saisie, la faire
    // viser au doigt d'abord n'apporterait rien.
    nodes.first.requestFocus();
  }

  /// Avance d'une case à l'autre au fil de la frappe.
  void onDigitChanged(int index, String value) {
    error.value = '';

    if (value.isNotEmpty && index < pinLength - 1) {
      nodes[index + 1].requestFocus();
    }

    // Case vidée : le retour arrière ramène à la précédente, sans quoi la
    // correction obligerait à viser la case au doigt.
    if (value.isEmpty && index > 0) {
      nodes[index - 1].requestFocus();
    }

    if (isComplete) valider();
  }

  void _vider() {
    for (final d in digits) {
      d.clear();
    }
    active.value = 0;
    nodes.first.requestFocus();
  }

  Future<void> valider() async {
    if (!isComplete || loading.value) return;

    switch (mode) {
      case PinMode.inscription:
        await _inscrire();
      case PinMode.connexion:
        await _connecter();
    }
  }

  /// Première saisie mise de côté, seconde saisie comparée puis envoyée.
  Future<void> _inscrire() async {
    if (!confirming.value) {
      _premiereSaisie = pin;
      confirming.value = true;
      _vider();
      return;
    }

    if (pin != _premiereSaisie) {
      error.value = 'Les deux codes ne correspondent pas';
      confirming.value = false;
      _premiereSaisie = '';
      _vider();
      return;
    }

    loading.value = true;

    try {
      final user = await _session.signUpWithPin(email: email, pin: pin);

      Get.offAllNamed(
        user.profileComplete ? Routes.HOME : Routes.COMPLETEPROFILE,
      );
    } on ApiException catch (e) {
      error.value = e.errorFor('pin') ?? e.errorFor('email') ?? e.message;
      confirming.value = false;
      _premiereSaisie = '';
      _vider();
    } finally {
      loading.value = false;
    }
  }

  Future<void> _connecter() async {
    loading.value = true;

    try {
      final user = await _session.signInWithPin(email: email, pin: pin);

      Get.offAllNamed(
        user.profileComplete ? Routes.HOME : Routes.COMPLETEPROFILE,
      );
    } on ApiException catch (e) {
      error.value = e.errorFor('pin') ?? e.errorFor('email') ?? e.message;
      _vider();
    } finally {
      loading.value = false;
    }
  }

  /// Code oublié : plus aucun code ne circule par email, la régulation
  /// est seule à pouvoir en reposer un.
  void codeOublie() {
    Get.snackbar(
      'Code oublié',
      'Rapproche-toi de la régulation pour faire réinitialiser ton code.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void onClose() {
    for (final d in digits) {
      d.dispose();
    }
    for (final n in nodes) {
      n.dispose();
    }
    super.onClose();
  }
}
