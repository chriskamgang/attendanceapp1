import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brutal_state.dart';
import '../../../core/widgets/brutal_top_nav.dart';
import '../bindings/scolarite_binding.dart';
import '../controllers/scolarite_controller.dart';
import 'widgets/carte_cours.dart';
import 'widgets/jour_emploi_du_temps.dart';

/// La scolarité de l'étudiant : sa semaine, et l'avis qu'il porte sur ses
/// cours.
///
/// Posée comme onglet de l'accueil, elle ne pose ni `Scaffold` ni
/// `SafeArea` : l'écran hôte les tient déjà, et les redoubler décalerait le
/// contenu sous l'encoche. Le binding est installé ici plutôt que par la
/// route, l'onglet n'en traversant aucune.
class ScolariteView extends StatefulWidget {
  const ScolariteView({super.key});

  @override
  State<ScolariteView> createState() => _ScolariteViewState();
}

class _ScolariteViewState extends State<ScolariteView> {
  late final ScolariteController controller;

  @override
  void initState() {
    super.initState();
    ScolariteBinding().dependencies();
    controller = Get.find<ScolariteController>();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          const _Titre(),
          Obx(
            () => BrutalTopNav(
              currentIndex: controller.onglet.value,
              onTap: (i) => controller.onglet.value = i,
              items: [
                const BrutalTopNavItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Ma semaine',
                ),
                BrutalTopNavItem(
                  icon: Icons.star_rounded,
                  label: 'Mes cours',
                  // La pastille compte ce qui reste à faire : un cours
                  // déjà noté n'a plus à réclamer l'attention.
                  badgeCount: controller.coursNonEvalues,
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(
              () => controller.onglet.value == 0
                  ? const _OngletSemaine()
                  : const _OngletCours(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.blueSoft,
              borderRadius: BorderRadius.circular(Brutal.radiusSmall),
              border: Border.all(color: AppColors.ink, width: Brutal.border),
            ),
            child: const Icon(Icons.school_rounded, size: 21),
          ),
          const SizedBox(width: 12),
          Text('Ma scolarité', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

/// L'emploi du temps, jour par jour.
class _OngletSemaine extends GetView<ScolariteController> {
  const _OngletSemaine();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.chargeSemaine.value) {
        return const BrutalSkeletonList(count: 4, itemHeight: 96);
      }

      if (controller.erreurSemaine.isNotEmpty) {
        return BrutalState.error(
          title: 'Emploi du temps indisponible',
          message: controller.erreurSemaine.value,
          onAction: controller.chargerSemaine,
        );
      }

      final jours = controller.joursAvecCours;

      if (jours.isEmpty) {
        return const BrutalState.empty(
          icon: Icons.event_available_rounded,
          title: 'Aucun cours programmé',
          message:
              'Ta semaine est vide pour le moment. Si tu viens de t’inscrire, '
              'ton emploi du temps arrivera une fois ton niveau et ta '
              'spécialité renseignés.',
        );
      }

      return RefreshIndicator(
        onRefresh: controller.chargerSemaine,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          itemCount: jours.length,
          separatorBuilder: (_, __) => const SizedBox(height: 18),
          itemBuilder: (_, i) => JourEmploiDuTemps(
            jour: jours[i],
            seances: controller.semaine[jours[i]] ?? const [],
          ),
        ),
      );
    });
  }
}

/// Les cours de l'étudiant, à noter ou déjà notés.
class _OngletCours extends GetView<ScolariteController> {
  const _OngletCours();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.chargeCours.value) {
        return const BrutalSkeletonList(count: 4, itemHeight: 88);
      }

      if (controller.erreurCours.isNotEmpty) {
        return BrutalState.error(
          title: 'Cours indisponibles',
          message: controller.erreurCours.value,
          onAction: controller.chargerCours,
        );
      }

      if (controller.cours.isEmpty) {
        return const BrutalState.empty(
          icon: Icons.menu_book_rounded,
          title: 'Aucun cours à noter',
          message:
              'Les cours de ton niveau apparaîtront ici : tu pourras donner '
              'ton avis sur chacun d’eux.',
        );
      }

      return RefreshIndicator(
        onRefresh: controller.chargerCours,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          itemCount: controller.cours.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (_, i) => CarteCours(cours: controller.cours[i]),
        ),
      );
    });
  }
}
