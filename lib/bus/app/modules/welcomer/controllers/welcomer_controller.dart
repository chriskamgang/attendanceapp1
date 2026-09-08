import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../launcher/app_mode.dart';
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

  /// Case « Je suis chauffeur » : bascule le champ et la destination.
  ///
  /// Elle est déjà cochée pour qui est arrivé par la carte « Chauffeur » du
  /// login du personnel : il a dit qui il était, le lui redemander ici
  /// n'apporterait rien.
  final RxBool estChauffeur = false.obs;

  @override
  void onInit() {
    super.onInit();
    estChauffeur.value =
        PorteEntreeService.consommer() == PorteEntree.chauffeur;
  }

  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  /// Un numéro camerounais, avec ou sans indicatif, espaces tolérés.
  static final RegExp _phonePattern = RegExp(r'^\+?\d{8,15}$');

  String get label =>
      estChauffeur.value ? 'Numéro de téléphone' : 'Adresse email';

  String get hint =>
      estChauffeur.value ? '+237 6 XX XX XX XX' : 'prenom.nom@insam.edu';

  IconData get icon =>
      estChauffeur.value ? Icons.phone_rounded : Icons.alternate_email_rounded;

  TextInputType get keyboardType =>
      estChauffeur.value ? TextInputType.phone : TextInputType.emailAddress;

  String get intro => estChauffeur.value
      ? 'Ton compte a été ouvert par la régulation. Entre le numéro qui y '
            'est enregistré, ton mot de passe suit.'
      : 'Entre ton adresse : ton emploi du temps, tes cours et la navette '
            'du campus t’attendent derrière ton code à 4 chiffres.';

  /// Bascule entre les deux modes de connexion.
  ///
  /// La saisie est vidée : une adresse email n'a aucun sens dans un champ
  /// qui attend désormais un numéro.
  void toggleChauffeur(bool? valeur) {
    final actif = valeur ?? false;
    if (actif == estChauffeur.value) return;

    estChauffeur.value = actif;
    identifiant.clear();
    identifiantError.value = '';
  }

  /// Poursuit la connexion selon le mode choisi.
  Future<void> continuer() async {
    final valeur = identifiant.text.trim();

    if (estChauffeur.value) {
      _continuerChauffeur(valeur);
      return;
    }

    await _continuerEtudiant(valeur);
  }

  /// Chauffeur : rien à demander au serveur, l'écran suivant réclame le
  /// mot de passe et ouvre la session d'un seul appel.
  void _continuerChauffeur(String numero) {
    final compact = numero.replaceAll(' ', '');

    if (compact.isEmpty) {
      identifiantError.value = 'Entre ton numéro de téléphone';
      return;
    }
    if (!_phonePattern.hasMatch(compact)) {
      identifiantError.value = 'Ce numéro est invalide';
      return;
    }

    identifiantError.value = '';
    Get.toNamed(Routes.DRIVERLOGIN, arguments: {'telephone': compact});
  }

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
