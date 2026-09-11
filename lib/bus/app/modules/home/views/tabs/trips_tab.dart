import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_motion.dart';
import '../../../../core/widgets/brutal_state.dart';
import '../../../../data/models/trip_entry.dart';
import '../../controllers/home_controller.dart';

/// Historique des trajets effectués (US-08).
class TripsTab extends GetView<HomeController> {
  const TripsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.student.refreshTrips,
      color: AppColors.blue,
      backgroundColor: AppColors.white,
      child: Obx(() {
        final student = controller.student;

        if (student.tripsError.value.isNotEmpty) {
          return _Centre(
            child: BrutalState.error(
              title: 'Historique indisponible',
              message: student.tripsError.value,
              onAction: student.refreshTrips,
            ),
          );
        }

        if (student.loadingTrips.value && student.trips.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: const [BrutalSkeletonList(count: 4)],
          );
        }

        if (student.trips.isEmpty) {
          return _Centre(
            child: const BrutalState.empty(
              icon: Icons.receipt_long_rounded,
              title: 'Aucun trajet pour l’instant',
              message:
                  'Tes trajets apparaîtront ici dès ta première montée '
                  'à bord.',
            ),
          );
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            const _Title(),
            const SizedBox(height: 18),
            _Recap(trips: student.trips),
            const SizedBox(height: 18),
            BrutalStagger(
              children: student.trips
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TripCard(trip: t),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      }),
    );
  }
}

class _Centre extends StatelessWidget {
  const _Centre({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
          child: Center(child: child),
        ),
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
          'HISTORIQUE',
          style: text.bodyMedium?.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text('Trajets.', style: text.displayMedium?.copyWith(fontSize: 30)),
      ],
    );
  }
}

/// Compteur du mois : nombre de trajets et montant dépensé.
class _Recap extends StatelessWidget {
  const _Recap({required this.trips});

  final List<TripEntry> trips;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final maintenant = DateTime.now();
    final duMois = trips
        .where(
          (t) => t.date.year == maintenant.year && t.date.month == maintenant.month,
        )
        .toList();
    final total = duMois.fold<int>(0, (somme, t) => somme + t.fare);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blueSoft,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: 2.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${duMois.length}',
                  style: text.displayMedium?.copyWith(
                    fontSize: 28,
                    color: AppColors.blueDark,
                  ),
                ),
                Text(
                  'trajet${duMois.length > 1 ? 's' : ''} ce mois-ci',
                  style: text.bodyMedium?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          Container(width: 2.5, height: 44, color: AppColors.ink),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$total F',
                    style: text.displayMedium?.copyWith(
                      fontSize: 28,
                      color: AppColors.blueDark,
                    ),
                  ),
                  Text(
                    'dépensés',
                    style: text.bodyMedium?.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final TripEntry trip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: 2.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.blueSoft,
              borderRadius: BorderRadius.circular(Brutal.radiusSmall),
              border: Border.all(color: AppColors.ink, width: 2.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${trip.date.day}'.padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.blueDark,
                  ),
                ),
                Text(
                  _mois(trip.date.month),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.pickupName.isEmpty ? 'Trajet' : trip.pickupName,
                  style: text.titleMedium?.copyWith(fontSize: 15.5),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    _heure(trip.date),
                    if (trip.busLabel.isNotEmpty) trip.busLabel,
                  ].join(' · '),
                  style: text.bodyMedium?.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (!trip.onTime)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.ink,
              ),
            ),
          if (trip.fare > 0)
            Text(
              '${trip.fare} F',
              style: text.titleMedium?.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  static String _heure(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _mois(int m) => const [
    'JAN', 'FÉV', 'MAR', 'AVR', 'MAI', 'JUIN',
    'JUIL', 'AOÛT', 'SEP', 'OCT', 'NOV', 'DÉC',
  ][m - 1];
}
