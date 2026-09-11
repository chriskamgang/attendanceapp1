import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/services/storage_service.dart';
import '../../../routes/app_pages.dart';

class OnboardingController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final PageController pageController = PageController();
  final RxInt index = 0.obs;

  /// Rejouée à chaque changement de page pour animer l'entrée du contenu.
  late final AnimationController entry;

  static const int stepCount = 2;

  bool get isLast => index.value == stepCount - 1;

  @override
  void onInit() {
    super.onInit();
    entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
  }

  void onPageChanged(int value) {
    index.value = value;
    entry
      ..reset()
      ..forward();
  }

  void next() {
    if (isLast) {
      finish();
      return;
    }
    pageController.nextPage(
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  void skip() => finish();

  /// Le parcours de découverte ne s'affiche qu'à la première ouverture :
  /// une fois vu, le lancement mène droit à l'accueil de connexion.
  void finish() {
    Get.find<StorageService>().markOnboardingSeen();
    Get.offAllNamed(Routes.WELCOMER);
  }

  @override
  void onClose() {
    entry.dispose();
    pageController.dispose();
    super.onClose();
  }
}
