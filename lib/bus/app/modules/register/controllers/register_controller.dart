import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/services/api_exception.dart';
import '../../../data/services/session_service.dart';
import '../../../modules/pin/controllers/pin_controller.dart';
import '../../../routes/app_pages.dart';

/// Création de compte étudiant : l'adresse email suffit ici, le reste du
/// profil est demandé après la vérification du code (voir
/// `CompleteprofileController`).
///
/// Le backend ne distingue pas inscription et connexion : une adresse
/// inconnue reçoit un code comme une autre, et le compte naît à la
/// vérification. Les chauffeurs, eux, sont créés au back-office.
class RegisterController extends GetxController {
  final SessionService _session = Get.find<SessionService>();

  final TextEditingController email = TextEditingController();
  final RxString emailError = ''.obs;
  final RxBool loading = false.obs;

  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  Future<void> submit() async {
    final value = email.text.trim();

    if (value.isEmpty) {
      emailError.value = 'Entre ton adresse email';
      return;
    }
    if (!_emailPattern.hasMatch(value)) {
      emailError.value = 'Cette adresse email est invalide';
      return;
    }

    emailError.value = '';
    loading.value = true;

    try {
      switch (await _session.lookup(value)) {
        // Adresse libre : l'étudiant choisit son code, ce qui l'inscrit.
        case SignInRoute.signUp:
          Get.toNamed(
            Routes.PIN,
            arguments: {'mode': PinMode.inscription, 'email': value},
          );
        // Compte déjà ouvert : il se connecte plutôt que de s'inscrire.
        case SignInRoute.pin:
          Get.toNamed(
            Routes.PIN,
            arguments: {'mode': PinMode.connexion, 'email': value},
          );
        case SignInRoute.password:
          emailError.value =
              'Cette adresse est déjà celle d’un compte chauffeur.';
      }
    } on ApiException catch (e) {
      emailError.value = e.errorFor('email') ?? e.message;
    } finally {
      loading.value = false;
    }
  }

  Future<void> registerWithGoogle() async {
    Get.snackbar(
      'Bientôt disponible',
      'La création de compte Google n’est pas encore ouverte.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }

  void goToLogin() => Get.back();

  @override
  void onClose() {
    email.dispose();
    super.onClose();
  }
}
