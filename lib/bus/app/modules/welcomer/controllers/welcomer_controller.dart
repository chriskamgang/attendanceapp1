import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/services/api_exception.dart';
import '../../../data/services/session_service.dart';
import '../../../modules/pin/controllers/pin_controller.dart';
import '../../../routes/app_pages.dart';

class WelcomerController extends GetxController {
  final SessionService _session = Get.find<SessionService>();

  /// Un seul champ pour les deux publics : il porte une adresse pour
  /// l'étudiant, un numéro pour le chauffeur.
  ///
  /// Le backend n'identifie pas les deux de la même façon — l'étudiant par
  /// son email, le chauffeur par son téléphone, puisque son compte est
  /// ouvert au back-office où le numéro fait foi. Demander une adresse au
  /// chauffeur pour lui réclamer ensuite un numéro n'aurait servi à rien.
  final TextEditingController identifiant = TextEditingController();

  /// Message d'erreur sous le champ ; vide = pas d'erreur.
  final RxString identifiantError = ''.obs;
  final RxBool loading = false.obs;

  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  String get label => 'Adresse email';

  String get hint => 'prenom.nom@insam.edu';

  IconData get icon => Icons.alternate_email_rounded;

  TextInputType get keyboardType => TextInputType.emailAddress;

  String get intro =>
      'Entre ton adresse : ton emploi du temps, tes cours et la navette du '
      'campus t’attendent derrière ton code à 4 chiffres.';

  /// Poursuit la connexion.
  Future<void> continuer() => _continuerEtudiant(identifiant.text.trim());

  /// Étudiant : l'aiguillage dit s'il saisit son PIN ou s'il en choisit un.
  ///
  /// Un compte à mot de passe qui passerait tout de même par ici — son
  /// adresse est enregistrée au back-office — bascule sur l'écran dédié
  /// plutôt que d'attendre un code qui n'arrivera jamais.
  Future<void> _continuerEtudiant(String adresse) async {

    if (adresse.isEmpty) {
      identifiantError.value = 'Entre ton adresse email';
      return;
    }
    if (!_emailPattern.hasMatch(adresse)) {
      identifiantError.value = 'Cette adresse email est invalide';
      return;
    }

    identifiantError.value = '';
    loading.value = true;

    try {
      final route = await _session.lookup(adresse);

      switch (route) {
        // Compte connu : l'étudiant saisit son code à 4 chiffres.
        case SignInRoute.pin:
          Get.toNamed(
            Routes.PIN,
            arguments: {'mode': PinMode.connexion, 'email': adresse},
          );
        // Adresse inconnue : choisir un code vaut inscription.
        case SignInRoute.signUp:
          Get.toNamed(
            Routes.PIN,
            arguments: {'mode': PinMode.inscription, 'email': adresse},
          );
        case SignInRoute.password:
          Get.toNamed(Routes.DRIVERLOGIN);
      }
    } on ApiException catch (e) {
      identifiantError.value = e.errorFor('email') ?? e.message;
    } finally {
      loading.value = false;
    }
  }

  /// Connexion Google : pas encore branchée sur le backend.
  Future<void> continueWithGoogle() async {
    Get.snackbar(
      'Bientôt disponible',
      'La connexion Google n’est pas encore ouverte. '
          'Utilise ton adresse email.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }

  void goToRegister() => Get.toNamed(Routes.REGISTER);

  @override
  void onClose() {
    identifiant.dispose();
    super.onClose();
  }
}
