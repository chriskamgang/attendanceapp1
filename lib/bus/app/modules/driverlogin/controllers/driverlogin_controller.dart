import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../main.dart';

import '../../../data/models/user_role.dart';
import '../../../data/services/api_exception.dart';
import '../../../data/services/session_service.dart';
import '../../../routes/app_pages.dart';

/// Connexion des comptes à mot de passe : chauffeurs et back-office.
///
/// Ces comptes sont créés au back-office, où le **numéro de téléphone**
/// fait foi — c'est donc lui, et non l'adresse email, que le backend
/// attend ici.
class DriverloginController extends GetxController {
  final SessionService _session = Get.find<SessionService>();

  final TextEditingController phone = TextEditingController();
  final TextEditingController pin = TextEditingController();

  final RxString phoneError = ''.obs;
  final RxString pinError = ''.obs;
  final RxBool loading = false.obs;

  /// Le mot de passe est masqué par défaut : le chauffeur se connecte
  /// souvent au volant, sous le regard des étudiants qui montent.
  final RxBool obscure = true.obs;

  /// Vrai quand le numéro vient de l'accueil : il n'y a plus qu'à taper le
  /// mot de passe, et le champ du numéro devient un simple rappel.
  final RxBool numeroConnu = false.obs;

  @override
  void onInit() {
    super.onInit();

    // Le numéro arrive de l'accueil quand la case « Je suis chauffeur »
    // y a été cochée. Le redemander ici serait une saisie pour rien.
    final suggestion = Get.arguments is Map
        ? (Get.arguments as Map)['telephone'] as String?
        : null;

    if (suggestion != null && suggestion.isNotEmpty) {
      phone.text = suggestion;
      numeroConnu.value = true;
    }
  }

  /// Revient à l'accueil pour corriger le numéro.
  void changerNumero() => Get.back();

  void toggleObscure() => obscure.value = !obscure.value;

  Future<void> submit() async {
    final numero = phone.text.trim();
    final secret = pin.text;

    phoneError.value = numero.isEmpty ? 'Entre ton numéro de téléphone' : '';
    pinError.value = secret.length == 4 ? '' : 'Entre ton code à 4 chiffres';

    if (phoneError.value.isNotEmpty || pinError.value.isNotEmpty) return;

    loading.value = true;

    try {
      final user = await _session.signInDriver(phone: numero, pin: secret);

      pin.clear();

      // Un compte étudiant qui passerait par ici garde sa route habituelle :
      // l'aiguillage se fait sur le rôle, jamais sur l'écran d'origine.
      Get.offAllNamed(AppRoutes.homeFor(user));

      if (!user.role.isDriver) {
        Get.snackbar(
          'Connecté',
          'Ce compte n’est pas un compte chauffeur.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
      }
    } on ApiException catch (e) {
      // Le backend renvoie ses refus sur le champ `telephone`, qu'il
      // s'agisse d'un numéro inconnu ou d'un code erroné : il ne dit
      // jamais lequel des deux est faux.
      final refus = e.errorFor('telephone') ?? e.message;

      // Quand le numéro n'est qu'un rappel, son champ n'est plus à
      // l'écran : le message se dirait dans le vide. Il se reporte alors
      // sous le code, la seule saisie encore visible.
      if (numeroConnu.value) {
        phoneError.value = '';
        pinError.value = e.errorFor('pin') ?? refus;
      } else {
        phoneError.value = refus;
        pinError.value = e.errorFor('pin') ?? '';
      }
    } finally {
      loading.value = false;
    }
  }

  /// Revient sur ses pas : l'accueil de connexion, ou le login du
  /// personnel quand cet écran ouvre la pile.
  ///
  /// Le chauffeur y arrive par deux chemins — la carte « Je suis
  /// chauffeur » du login du personnel, ou l'accueil après avoir coché la
  /// case — et seul le second laisse quelque chose derrière lui.
  void goBack() {
    if (Get.previousRoute.isEmpty) {
      RootApp.revenirAEstuaireRh();
      return;
    }
    Get.back();
  }

  @override
  void onClose() {
    phone.dispose();
    pin.dispose();
    super.onClose();
  }
}
