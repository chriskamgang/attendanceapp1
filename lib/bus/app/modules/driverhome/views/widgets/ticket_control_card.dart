import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_button.dart';
import '../../../../data/services/boarding_service.dart';
import '../../../../data/services/driver_service.dart';
import 'gap_sheet.dart';
import 'scanner_sheet.dart';

/// Contrôle des titres : pass scannés, effectif compté, et l'écart entre
/// les deux — les passagers montés sans ticket (CDC §3.2).
class TicketControlCard extends StatelessWidget {
  const TicketControlCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<BoardingService>()) return const SizedBox.shrink();

    final boarding = Get.find<BoardingService>();
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final comptage = boarding.count.value;
      final ecart = comptage.withoutTicket;
      final bloque = comptage.blocksDeparture;

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
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contrôle des titres',
                    style: text.titleMedium?.copyWith(fontSize: 15.5),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: '${comptage.validated}',
                          label: 'pass scannés',
                          color: AppColors.blueSoft,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Stat(
                          value: '${comptage.headcount ?? 0}',
                          label: 'comptés',
                          color: AppColors.background,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Stat(
                          value: '$ecart',
                          label: 'sans ticket',
                          color: ecart > 0
                              ? const Color(0xFFFFE0DB)
                              : AppColors.background,
                          emphasis: ecart > 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  BrutalButton(
                    label: 'Scanner les pass',
                    icon: Icons.qr_code_scanner_rounded,
                    onPressed: () async {
                      await showScannerSheet(context);
                      // Le comptage remonte jusqu'au tour : c'est lui qui
                      // porte le verrou du départ.
                      await Get.find<DriverService>().syncBoardingCount();
                    },
                  ),
                ],
              ),
            ),
            if (ecart > 0) _GapBanner(justified: !bloque),
          ],
        ),
      );
    });
  }
}

/// Bandeau d'alerte sur l'écart, avec l'action qui débloque le départ.
class _GapBanner extends StatelessWidget {
  const _GapBanner({required this.justified});

  final bool justified;

  @override
  Widget build(BuildContext context) {
    final boarding = Get.find<BoardingService>();
    final comptage = boarding.count.value;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: justified ? AppColors.goldSoft : const Color(0xFFFFE0DB),
        border: const Border(
          top: BorderSide(color: AppColors.ink, width: 2.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                justified
                    ? Icons.check_circle_rounded
                    : Icons.warning_rounded,
                size: 20,
                color: justified ? AppColors.ink : const Color(0xFFD8341B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  justified
                      ? 'Écart justifié — tu peux déclarer le départ.'
                      : '${comptage.withoutTicket} passager'
                            '${comptage.withoutTicket > 1 ? 's sans ticket' : ' sans ticket'}. '
                            'Justifie l’écart avant de partir.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          if (!justified) ...[
            const SizedBox(height: 12),
            BrutalButton(
              label: 'Justifier l’écart',
              icon: Icons.edit_note_rounded,
              color: AppColors.ink,
              height: 48,
              fontSize: 14.5,
              onPressed: () async {
                await showGapSheet(context);
                // Sans cette relecture, le départ resterait verrouillé
                // alors que l'écart vient d'être motivé.
                await Get.find<DriverService>().syncBoardingCount();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
    this.emphasis = false,
  });

  final String value;
  final String label;
  final Color color;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Brutal.radiusSmall),
        border: Border.all(
          color: emphasis ? const Color(0xFFD8341B) : AppColors.ink,
          width: emphasis ? 3 : 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
              color: emphasis ? const Color(0xFFD8341B) : AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
