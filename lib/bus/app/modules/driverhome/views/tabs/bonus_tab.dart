import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_motion.dart';
import '../../../../data/models/driver_bonus.dart';
import '../../controllers/driverhome_controller.dart';
import '../widgets/active_mission_card.dart';
import '../widgets/rescue_mission_card.dart';

/// Cagnotte : primes cumulées du mois et récapitulatif détaillé (CDC §3.3).
class BonusTab extends GetView<DriverhomeController> {
  const BonusTab({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.reload,
      color: AppColors.blue,
      backgroundColor: AppColors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: const [
          BrutalStagger(
            children: [
              _Title(),
              SizedBox(height: 18),
              _TotalCard(),
              SizedBox(height: 16),
              _MissionInbox(),
              _RatesCard(),
              SizedBox(height: 16),
              _History(),
            ],
          ),
        ],
      ),
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
          'PRIMES DU MOIS',
          style: text.bodyMedium?.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text('Cagnotte.', style: text.displayMedium?.copyWith(fontSize: 30)),
      ],
    );
  }
}

/// Total net du mois, avec le détail crédits / pénalités.
class _TotalCard extends GetView<DriverhomeController> {
  const _TotalCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final bonus = controller.driver.bonus.value;

      return Container(
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
          boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cumul du mois',
                    style: text.bodyMedium?.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      BrutalCounter(
                        value: bonus.total,
                        style: text.displayLarge?.copyWith(
                          fontSize: 48,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'FCFA',
                          style: text.headlineMedium?.copyWith(
                            fontSize: 18,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          label: 'Tours validés',
                          value:
                              '${bonus.toursValidated}/${bonus.toursPlanned}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStat(
                          label: 'Secours',
                          value: '${bonus.rescues}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStat(
                          label: 'Ponctualité',
                          value:
                              '${(bonus.punctualityRate * 100).round()} %',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bandeau bas : état du bonus mensuel de régularité.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.gold,
                border: Border(
                  top: BorderSide(color: AppColors.ink, width: 2.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    bonus.regularityEarned
                        ? Icons.workspace_premium_rounded
                        : Icons.flag_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      bonus.regularityEarned
                          ? 'Bonus de régularité acquis'
                          : 'Bonus de régularité : aucun tour manqué requis',
                      style: text.titleMedium?.copyWith(fontSize: 13),
                    ),
                  ),
                  Text(
                    '${BonusRates.monthlyRegularity} F',
                    style: text.titleMedium?.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radiusSmall),
        border: Border.all(color: AppColors.ink, width: 2.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Missions de secours en attente, également visibles depuis la cagnotte :
/// c'est là que le chauffeur vient chercher du complément de prime.
class _MissionInbox extends GetView<DriverhomeController> {
  const _MissionInbox();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pending = controller.driver.missions
          .where((m) => !m.accepted)
          .toList();

      // Une mission acceptée reste à l'écran jusqu'à sa clôture : c'est le
      // seul endroit d'où le chauffeur peut déclarer la prise en charge,
      // dont dépend sa prime (CDC §3.4).
      final active = controller.driver.missions
          .where((m) => m.accepted && !m.isClosed)
          .toList();

      if (pending.isEmpty && active.isEmpty) return const SizedBox.shrink();

      return Column(
        children: [
          for (final m in active) ...[
            ActiveMissionCard(mission: m),
            const SizedBox(height: 16),
          ],
          for (final m in pending) ...[
            RescueMissionCard(
              mission: m,
              onAccept: () => controller.acceptMission(m.id),
              onDecline: () => controller.declineMission(m.id),
            ),
            const SizedBox(height: 16),
          ],
        ],
      );
    });
  }
}

/// Barème des primes, pour que la règle du jeu soit lisible en permanence.
class _RatesCard extends StatelessWidget {
  const _RatesCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: 2.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BARÈME',
            style: text.bodyMedium?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          const _RateRow(
            icon: Icons.check_circle_rounded,
            label: 'Par tour validé',
            amount: BonusRates.perTour,
          ),
          const _RateRow(
            icon: Icons.sos_rounded,
            label: 'Par mission de secours',
            amount: BonusRates.perRescue,
          ),
          const _RateRow(
            icon: Icons.event_available_rounded,
            label: 'Assiduité journalière',
            amount: BonusRates.dailyAssiduity,
          ),
          const _RateRow(
            icon: Icons.workspace_premium_rounded,
            label: 'Régularité mensuelle',
            amount: BonusRates.monthlyRegularity,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.icon,
    required this.label,
    required this.amount,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final int amount;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.blue),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            '$amount F',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: AppColors.blueDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Historique détaillé de chaque course validée (CDC §3.3).
class _History extends GetView<DriverhomeController> {
  const _History();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final entries = controller.driver.bonus.value.entries;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RÉCAPITULATIF',
            style: text.bodyMedium?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(Brutal.radius),
                border: Border.all(color: AppColors.ink, width: 2.5),
              ),
              child: Text(
                'Aucune prime pour l’instant.',
                style: text.bodyMedium?.copyWith(fontSize: 13.5),
              ),
            )
          else
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EntryRow(entry: e),
              ),
        ],
      );
    });
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final BonusEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final debit = entry.kind.isDebit;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: debit ? AppColors.goldSoft : AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: 2.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: debit ? AppColors.gold : AppColors.blueSoft,
              borderRadius: BorderRadius.circular(Brutal.radiusSmall),
              border: Border.all(color: AppColors.ink, width: 2.5),
            ),
            child: Icon(_iconFor(entry.kind), size: 19, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.kind.label,
                  style: text.titleMedium?.copyWith(fontSize: 14.5),
                ),
                if (entry.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.detail,
                    style: text.bodyMedium?.copyWith(fontSize: 12.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${debit ? '−' : '+'}${entry.amount} F',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: debit ? AppColors.ink : AppColors.blueDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${entry.date.day.toString().padLeft(2, '0')}/'
                '${entry.date.month.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(BonusEntryKind kind) => switch (kind) {
    BonusEntryKind.tour => Icons.check_circle_rounded,
    BonusEntryKind.rescue => Icons.sos_rounded,
    BonusEntryKind.assiduity => Icons.event_available_rounded,
    BonusEntryKind.regularity => Icons.workspace_premium_rounded,
    BonusEntryKind.penalty => Icons.remove_circle_rounded,
  };
}
