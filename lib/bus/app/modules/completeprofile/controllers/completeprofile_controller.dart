import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/pickup_point.dart';
import '../../../data/services/api_exception.dart';
import '../../../data/services/scolarite_service.dart';
import '../../../data/services/session_service.dart';
import '../../../routes/app_pages.dart';

/// Complétion du profil étudiant, en trois étapes.
///
/// Elle suit toute première connexion — par email comme par Google — tant
/// que les informations obligatoires manquent. Les chauffeurs, créés au
/// back-office, n'y passent jamais.
class CompleteprofileController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final SessionService session = Get.find<SessionService>();

  final PageController pageController = PageController();
  final RxInt step = 0.obs;

  static const int stepCount = 4;

  // Étape 1 — identité
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final RxString firstNameError = ''.obs;
  final RxString lastNameError = ''.obs;
  final RxString phoneError = ''.obs;

  // Étape 2 — matricule
  final TextEditingController matricule = TextEditingController();
  final RxString matriculeError = ''.obs;

  /// Coché quand l'étudiant ne retrouve pas son matricule : le champ est
  /// alors ignoré et pourra être renseigné plus tard depuis le profil.
  final RxBool matriculeForgotten = false.obs;

  // Étape 3 — scolarité
  //
  // Le couple (niveau, spécialité) rattache l'étudiant à son emploi du
  // temps : sans lui, sa semaine et ses cours resteraient vides sans que
  // rien ne le lui dise.
  final RxnString niveau = RxnString();
  final RxnString specialite = RxnString();
  final RxList<String> niveaux = <String>[].obs;
  final RxList<String> specialites = <String>[].obs;
  final RxString scolariteError = ''.obs;
  final RxBool chargeScolarite = false.obs;

  // Étape 4 — point de ramassage
  final Rxn<PickupPoint> pickup = Rxn<PickupPoint>();

  final RxBool saving = false.obs;

  /// Rejouée à chaque étape pour animer l'entrée du contenu.
  late final AnimationController entry;

  bool get isLast => step.value == stepCount - 1;

  @override
  void onInit() {
    super.onInit();
    entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..forward();
    _chargerPoints();
    chargerScolarite();
  }

  /// Charge niveaux et spécialités proposés à l'étudiant.
  ///
  /// L'échec n'est pas bloquant : l'étape reste franchissable, quitte à ce
  /// que l'emploi du temps arrive plus tard — mieux vaut un profil
  /// incomplet qu'une inscription impossible.
  Future<void> chargerScolarite() async {
    chargeScolarite.value = true;
    scolariteError.value = '';

    try {
      final catalogue = await Get.find<ScolariteService>()
          .catalogueScolarite();
      niveaux.value = catalogue.niveaux;
      specialites.value = catalogue.specialites;
    } on ApiException catch (e) {
      scolariteError.value = e.message;
    } catch (_) {
      scolariteError.value = 'La liste des filières n’a pas pu être chargée.';
    } finally {
      chargeScolarite.value = false;
    }
  }

  void selectNiveau(String value) => niveau.value = value;

  void selectSpecialite(String value) => specialite.value = value;

  /// Charge les points de ramassage servis par le backend.
  ///
  /// [force] rappelle l'API même si la liste est déjà en mémoire : c'est
  /// ce qu'attend l'étudiant qui tire l'écran pour l'actualiser.
  Future<void> _chargerPoints({bool force = false}) async {
    try {
      await session.loadPickupPoints(force: force);
    } on ApiException catch (e) {
      pickupError.value = e.message;
    }
  }

  /// Message affiché à la place de la liste quand elle n'a pas pu venir.
  final RxString pickupError = ''.obs;

  /// Recharge la liste : après un échec réseau, ou sur un geste de
  /// l'étudiant qui tire l'écran vers le bas.
  Future<void> retryPickups() async {
    pickupError.value = '';
    await _chargerPoints(force: true);
  }

  void toggleMatriculeForgotten(bool value) {
    matriculeForgotten.value = value;
    if (value) {
      matricule.clear();
      matriculeError.value = '';
    }
  }

  void selectPickup(PickupPoint value) => pickup.value = value;

  bool _validateIdentity() {
    firstNameError.value = firstName.text.trim().length < 2
        ? 'Entre ton prénom'
        : '';
    lastNameError.value = lastName.text.trim().length < 2
        ? 'Entre ton nom'
        : '';
    phoneError.value = phone.text.trim().length < 8
        ? 'Numéro de téléphone invalide'
        : '';

    return firstNameError.value.isEmpty &&
        lastNameError.value.isEmpty &&
        phoneError.value.isEmpty;
  }

  bool _validateMatricule() {
    // Le champ n'est exigé que si la case « j'ai oublié » est décochée.
    if (matriculeForgotten.value) {
      matriculeError.value = '';
      return true;
    }
    matriculeError.value = matricule.text.trim().isEmpty
        ? 'Entre ton matricule INSAM'
        : '';
    return matriculeError.value.isEmpty;
  }

  bool _validateCurrentStep() => switch (step.value) {
    0 => _validateIdentity(),
    1 => _validateMatricule(),
    // La scolarité n'est exigée que si le serveur a su proposer des
    // valeurs : une liste vide ne doit pas enfermer l'étudiant sur une
    // étape qu'il ne peut pas remplir.
    2 => _validateScolarite(),
    _ => pickup.value != null,
  };

  bool _validateScolarite() {
    if (niveaux.isEmpty && specialites.isEmpty) return true;

    final manque =
        (niveaux.isNotEmpty && niveau.value == null) ||
        (specialites.isNotEmpty && specialite.value == null);

    scolariteError.value = manque ? 'Choisis ton niveau et ta filière' : '';
    return !manque;
  }

  void onPageChanged(int value) {
    step.value = value;
    entry
      ..reset()
      ..forward();
  }

  Future<void> next() async {
    if (!_validateCurrentStep()) return;

    if (isLast) {
      await submit();
      return;
    }
    pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void previous() {
    if (step.value == 0) return;
    pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> submit() async {
    final point = pickup.value;
    if (point == null || saving.value) return;

    saving.value = true;
    try {
      await session.saveProfile(
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        phone: phone.text.trim(),
        matricule: matricule.text.trim(),
        matriculeSkipped: matriculeForgotten.value,
        pickup: point,
        niveau: niveau.value,
        specialite: specialite.value,
      );

      Get.offAllNamed(Routes.HOME);
    } on ApiException catch (e) {
      _reporterErreurs(e);
    } finally {
      saving.value = false;
    }
  }

  /// Renvoie l'utilisateur sur l'étape fautive, champ surligné.
  ///
  /// Le backend valide ce que l'application ne peut pas vérifier seule :
  /// unicité du téléphone et du matricule, appartenance de l'arrêt à sa
  /// ligne.
  void _reporterErreurs(ApiException e) {
    phoneError.value = e.errorFor('telephone') ?? '';
    matriculeError.value = e.errorFor('matricule_insam') ?? '';

    if (phoneError.value.isNotEmpty) {
      _allerA(0);
      return;
    }
    if (matriculeError.value.isNotEmpty) {
      _allerA(1);
      return;
    }

    Get.snackbar(
      'Enregistrement impossible',
      e.message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.gold,
      colorText: AppColors.ink,
      margin: const EdgeInsets.all(16),
    );
  }

  void _allerA(int index) {
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void onClose() {
    entry.dispose();
    pageController.dispose();
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    matricule.dispose();
    super.onClose();
  }
}
