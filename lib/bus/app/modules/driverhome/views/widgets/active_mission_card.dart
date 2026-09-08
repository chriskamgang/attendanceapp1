import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_button.dart';
import '../../../../core/widgets/brutal_field.dart';
import '../../../../data/models/breakdown_report.dart';
import '../../controllers/driverhome_controller.dart';

/// Mission de secours acceptée, jusqu'à sa clôture (CDC §3.3).
///
/// Une mission acceptée disparaîtrait sinon de l'écran : le chauffeur n'a
/// plus aucun moyen de déclarer la prise en charge, et la prime de
/// 2 000 FCFA ne lui serait jamais versée.
class ActiveMissionCard extends StatelessWidget {
  const ActiveMissionCard({super.key, required this.mission});

  final RescueMission mission;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DriverhomeController>();
    final text = Theme.of(context).textTheme;
    final enRoute = mission.stage == MissionStage.enRoute;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
        boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            color: AppColors.blue,
            child: Row(
              children: [
                const Icon(
                  Icons.support_agent_rounded,
                  size: 19,
                  color: AppColors.white,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    enRoute ? 'SECOURS EN ROUTE' : 'MISSION ACCEPTÉE',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                      color: AppColors.white,
                    ),
                  ),
                ),
                Text(
                  '+${mission.reward} F',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.location,
                  style: text.titleMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '${mission.strandedDriverName} — '
                  '${mission.studentsToCollect} étudiant'
                  '${mission.studentsToCollect > 1 ? 's' : ''} à récupérer',
                  style: text.bodyMedium?.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 14),
                if (!enRoute)
                  BrutalButton(
                    label: 'Je suis en route',
                    icon: Icons.navigation_rounded,
                    height: 50,
                    fontSize: 15,
                    onPressed: () => controller.startMission(mission.id),
                  )
                else
                  BrutalButton(
                    label: 'Passagers récupérés',
                    icon: Icons.flag_rounded,
                    color: AppColors.gold,
                    textColor: AppColors.ink,
                    height: 50,
                    fontSize: 15,
                    onPressed: () => _askRescued(context, controller),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Demande le nombre de passagers réellement pris en charge.
  ///
  /// Le CDC §3.4 conditionne la prime à cette confirmation : le chiffre ne
  /// peut donc pas être supposé.
  Future<void> _askRescued(
    BuildContext context,
    DriverhomeController controller,
  ) async {
    final saisie = TextEditingController(
      text: '${mission.studentsToCollect}',
    );

    final confirme = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
              left: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
              right: BorderSide(
                color: AppColors.ink,
                width: Brutal.borderThick,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clôturer la mission',
                    style: Theme.of(
                      sheetContext,
                    ).textTheme.displayMedium?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'La prime de secours dépend des passagers effectivement '
                    'pris en charge.',
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 16),
                  BrutalField(
                    label: 'Passagers récupérés',
                    controller: saisie,
                    icon: Icons.groups_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 18),
                  BrutalButton(
                    label: 'Confirmer',
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirme != true) return;

    await controller.finishMission(
      mission.id,
      int.tryParse(saisie.text.trim()) ?? 0,
    );
  }
}
