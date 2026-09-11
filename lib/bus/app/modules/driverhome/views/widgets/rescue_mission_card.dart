import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_motion.dart';
import '../../../../data/models/breakdown_report.dart';

/// Mission de secours proposée par la régulation (CDC §3.3).
///
/// Le bloc bat doucement : il doit être vu, mais sans alarme sonore ni
/// couleur d'urgence, le chauffeur pouvant être au volant.
class RescueMissionCard extends StatelessWidget {
  const RescueMissionCard({
    super.key,
    required this.mission,
    required this.onAccept,
    required this.onDecline,
  });

  final RescueMission mission;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BrutalPulse(
      scale: 1.012,
      duration: const Duration(milliseconds: 1800),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.goldSoft,
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
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: const BoxDecoration(
                color: AppColors.gold,
                border: Border(
                  bottom: BorderSide(color: AppColors.white, width: 2.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sos_rounded, size: 19),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'MISSION DE SECOURS',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    '+${mission.reward} F',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.location,
                    style: text.titleMedium?.copyWith(fontSize: 16.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${mission.strandedDriverName} — ${mission.lineName}',
                    style: text.bodyMedium?.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(
                        icon: mission.kind.icon,
                        label: mission.kind.label,
                      ),
                      _Chip(
                        icon: Icons.groups_rounded,
                        label: '${mission.studentsToCollect} étudiants',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _SheetAction(
                          label: 'Accepter',
                          color: AppColors.blue,
                          textColor: AppColors.white,
                          onTap: onAccept,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _SheetAction(
                        label: 'Refuser',
                        color: AppColors.white,
                        textColor: AppColors.ink,
                        onTap: onDecline,
                        expanded: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.blueDark),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.blueDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton compact du même langage que BrutalButton, sans sa hauteur fixe.
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.expanded = true,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(color: AppColors.ink, width: 2.5),
          boxShadow: Brutal.shadow(const Offset(3, 3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
