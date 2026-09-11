import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_button.dart';
import '../../../../core/widgets/brutal_motion.dart';
import '../../../../data/models/driver_tour.dart';
import '../../../../data/models/tour_stage.dart';
import '../../controllers/driverhome_controller.dart';
import '../widgets/ticket_control_card.dart';

/// Effectifs : saisie du nombre d'étudiants montés à bord (CDC §3.2).
///
/// Le chiffre sert au comptage anti-fraude et à la mesure d'affluence ;
/// il est saisi à l'arrêt, une fois l'embarquement terminé.
class HeadcountTab extends GetView<DriverhomeController> {
  const HeadcountTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: const [
        BrutalStagger(
          children: [
            _Title(),
            SizedBox(height: 18),
            _Counter(),
            SizedBox(height: 16),
            // Billettique : scan des pass et justification de l'écart, sans
            // laquelle le départ reste bloqué (CDC §3.2 et §3.4).
            _TicketControl(),
            _TodayRecap(),
          ],
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPTAGE À BORD',
          style: text.bodyMedium?.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text('Effectifs.', style: text.displayMedium?.copyWith(fontSize: 30)),
      ],
    );
  }
}

/// Compteur : deux gros boutons et un champ, utilisables debout dans le bus.
class _Counter extends GetView<DriverhomeController> {
  const _Counter();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final tour = controller.driver.tour.value;
      if (tour == null) return const SizedBox.shrink();

      // La saisie n'est ouverte qu'à l'arrêt : avant, personne n'est monté ;
      // après le départ, l'effectif est figé pour le contrôle anti-fraude.
      final open =
          tour.stage == TourStage.atPickup ||
          tour.stage == TourStage.headcountDone;

      if (!open) return _ClosedCard(tour: tour);

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
          boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tour ${tour.index} — ${tour.pickupName}',
              style: text.titleMedium?.copyWith(fontSize: 15.5),
            ),
            const SizedBox(height: 4),
            Text(
              'Combien d’étudiants sont montés ?',
              style: text.bodyMedium?.copyWith(fontSize: 13.5),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  onTap: () => controller.bumpHeadcount(-1),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: controller.headcount,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      textAlign: TextAlign.center,
                      style: text.displayLarge?.copyWith(fontSize: 46),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: text.displayLarge?.copyWith(
                          fontSize: 46,
                          color: AppColors.inkMuted.withValues(alpha: 0.35),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: AppColors.blueSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            Brutal.radiusSmall,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.ink,
                            width: 2.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            Brutal.radiusSmall,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.ink,
                            width: 2.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            Brutal.radiusSmall,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.blue,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  onTap: () => controller.bumpHeadcount(1),
                ),
              ],
            ),
            const SizedBox(height: 18),
            BrutalButton(
              label: tour.stage == TourStage.atPickup
                  ? 'Enregistrer l’effectif'
                  : 'Corriger l’effectif',
              icon: Icons.check_rounded,
              onPressed: controller.confirmHeadcount,
            ),
            if (tour.stage == TourStage.headcountDone) ...[
              const SizedBox(height: 12),
              Text(
                'Effectif enregistré : ${tour.headcount} étudiants. '
                'Il reste modifiable tant que le bus n’a pas quitté l’arrêt.',
                style: text.bodyMedium?.copyWith(fontSize: 13),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// Message affiché quand la saisie n'est pas ouverte à cette étape.
class _ClosedCard extends StatelessWidget {
  const _ClosedCard({required this.tour});

  final DriverTour tour;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final before = tour.stage.step < TourStage.atPickup.step;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
        boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                  border: Border.all(color: AppColors.ink, width: 2.5),
                ),
                child: Icon(
                  before ? Icons.hourglass_empty_rounded : Icons.lock_rounded,
                  size: 22,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  before
                      ? 'Saisie disponible à l’arrêt'
                      : 'Effectif figé : ${tour.headcount} étudiants',
                  style: text.titleMedium?.copyWith(fontSize: 15.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            before
                ? 'Valide d’abord « Arrivé au point » depuis l’onglet '
                      'Tournée, puis compte les étudiants montés à bord.'
                : 'Le bus a quitté l’arrêt : l’effectif ne peut plus être '
                      'modifié, il sert au contrôle anti-fraude.',
            style: text.bodyMedium?.copyWith(fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(color: AppColors.ink, width: 2.5),
          boxShadow: Brutal.shadow(const Offset(3, 3)),
        ),
        child: Icon(icon, size: 28, color: AppColors.white),
      ),
    );
  }
}

/// Récapitulatif des effectifs déjà transportés dans la journée.
/// Contrôle des titres, visible tant que le tour n'est pas clos.
class _TicketControl extends GetView<DriverhomeController> {
  const _TicketControl();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tour = controller.driver.tour.value;

      if (tour == null || !tour.isOpen) return const SizedBox.shrink();

      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: TicketControlCard(),
      );
    });
  }
}

class _TodayRecap extends GetView<DriverhomeController> {
  const _TodayRecap();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final tours = controller.driver.completedTours;
      final total = tours.fold<int>(0, (sum, t) => sum + t.headcount);

      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.blueSoft,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: 2.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Transportés aujourd’hui',
                    style: text.titleMedium?.copyWith(fontSize: 15),
                  ),
                ),
                Text(
                  '$total',
                  style: text.displayMedium?.copyWith(
                    fontSize: 24,
                    color: AppColors.blueDark,
                  ),
                ),
              ],
            ),
            if (tours.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Aucun tour clos pour l’instant.',
                style: text.bodyMedium?.copyWith(fontSize: 13),
              ),
            ] else ...[
              const SizedBox(height: 12),
              for (final t in tours)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.ink, width: 2),
                        ),
                        child: Text(
                          'Tour ${t.index}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.blueDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${t.headcount} étudiants',
                          style: text.bodyMedium?.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (t.isSuspiciouslyFast)
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 17,
                          color: AppColors.ink,
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );
    });
  }
}
