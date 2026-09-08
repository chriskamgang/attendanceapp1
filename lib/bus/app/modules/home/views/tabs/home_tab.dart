import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_motion.dart';
import '../../../../core/widgets/brutal_state.dart';
import '../../../../data/models/bus_tracking.dart';
import '../../../../data/models/student_pass.dart';
import '../../controllers/home_controller.dart';
import '../widgets/payment_sheet.dart';

/// Accueil : l'ETA du bus d'abord, puis le pass et les raccourcis.
class HomeTab extends GetView<HomeController> {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.reload,
      color: AppColors.blue,
      backgroundColor: AppColors.white,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: const [
          BrutalStagger(
            children: [
              _Greeting(),
              SizedBox(height: 18),
              _EtaCard(),
              SizedBox(height: 16),
              _PassStrip(),
              SizedBox(height: 16),
              _LineCard(),
              SizedBox(height: 16),
              _QuickActions(),
            ],
          ),
        ],
      ),
    );
  }
}

class _Greeting extends GetView<HomeController> {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          controller.greeting.toUpperCase(),
          style: text.bodyMedium?.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${controller.greetingName}.',
          style: text.displayMedium?.copyWith(fontSize: 30),
        ),
      ],
    );
  }
}

/// Pièce maîtresse : combien de temps avant que le bus arrive à l'arrêt.
class _EtaCard extends GetView<HomeController> {
  const _EtaCard();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final student = controller.student;

      // Un échec réseau se dit : sans cela, l'absence de bus et la panne
      // se ressemblent à l'écran.
      if (student.trackingError.value.isNotEmpty) {
        return BrutalState.error(
          title: 'Suivi indisponible',
          message: student.trackingError.value,
          onAction: student.refreshTracking,
        );
      }

      final t = student.tracking.value;

      if (t == null) {
        if (student.loadingTracking.value) {
          return const BrutalLoading(height: 190, label: 'Recherche du bus…');
        }

        return BrutalState.empty(
          icon: Icons.bus_alert_rounded,
          title: 'Aucun bus en circulation',
          message: student.trackingMessage.value.isNotEmpty
              ? student.trackingMessage.value
              : 'Ton bus n’a pas encore démarré sa tournée. '
                    'Tu seras prévenu dès son départ.',
        );
      }

      return _EtaContent(tracking: t);
    });
  }
}

class _EtaContent extends GetView<HomeController> {
  const _EtaContent({required this.tracking});

  final BusTracking tracking;

  @override
  Widget build(BuildContext context) {
    final live = tracking.isLive;
    final text = Theme.of(context).textTheme;
    final eta = tracking.etaMinutes;

    return Container(
      decoration: BoxDecoration(
        color: live ? AppColors.blue : AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
        boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              children: [
                _StatusPill(status: tracking.status),
                const Spacer(),
                Text(
                  tracking.busLabel,
                  style: text.titleMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: live ? AppColors.white : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        live && eta != null && eta > 0
                            ? 'Arrive dans'
                            : tracking.status.label,
                        style: text.bodyMedium?.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: live
                              ? AppColors.white.withValues(alpha: 0.9)
                              : AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (live && eta != null && eta > 0)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            BrutalCounter(
                              value: eta,
                              style: text.displayLarge?.copyWith(
                                fontSize: 56,
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: Text(
                                'min',
                                style: text.headlineMedium?.copyWith(
                                  fontSize: 20,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          live ? 'À ton arrêt' : 'Départ non signalé',
                          style: text.displayMedium?.copyWith(
                            fontSize: 26,
                            color: live ? AppColors.white : AppColors.ink,
                          ),
                        ),
                    ],
                  ),
                ),
                if (live) const _PulsingBus(),
              ],
            ),
          ),
          // Bandeau bas : arrêt et distance restante.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.gold,
              border: Border(top: BorderSide(color: AppColors.white, width: 2.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.place_rounded, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tracking.myStop?.name ??
                        controller.user?.pickup?.name ??
                        'Ton arrêt',
                    style: text.titleMedium?.copyWith(fontSize: 14.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (tracking.distanceMeters != null)
                  Text(
                    _distance(tracking.distanceMeters!),
                    style: text.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _distance(int metres) => metres >= 1000
      ? '${(metres / 1000).toStringAsFixed(1)} km'
      : '$metres m';
}

/// Petite pastille d'état du bus.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final BusStatus status;

  @override
  Widget build(BuildContext context) {
    final live = status.isLive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: live ? AppColors.white : AppColors.blueSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            BrutalPulse(
              scale: 1.35,
              duration: const Duration(milliseconds: 900),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            status.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingBus extends StatelessWidget {
  const _PulsingBus();

  @override
  Widget build(BuildContext context) {
    return BrutalPulse(
      scale: 1.06,
      duration: const Duration(milliseconds: 1600),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(color: AppColors.ink, width: 2.5),
        ),
        child: const Icon(
          Icons.directions_bus_filled_rounded,
          size: 32,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

/// Bandeau du pass en cours, avec le nombre de jours restants.
class _PassStrip extends GetView<HomeController> {
  const _PassStrip();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final student = controller.student;
      final pass = student.pass.value;

      if (student.loadingPass.value && pass == null) {
        return const BrutalLoading(height: 78);
      }

      final actif = pass?.isActive ?? false;
      final expirant = pass?.isExpiringSoon ?? false;

      return GestureDetector(
        // Un pass à régler s'ouvre droit sur son paiement : renvoyer vers
        // l'onglet Pass ferait recommencer la recherche du bouton.
        onTap: () => (pass?.isPending ?? false)
            ? showPaymentSheet(context, pass!)
            : controller.changeTab(2),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: actif
                ? (expirant ? AppColors.goldSoft : AppColors.white)
                : AppColors.goldSoft,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: 2.5),
            boxShadow: Brutal.shadow(const Offset(4, 4)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: actif ? AppColors.blue : AppColors.gold,
                  borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                  border: Border.all(color: AppColors.ink, width: 2.5),
                ),
                child: Icon(
                  Icons.confirmation_number_rounded,
                  size: 24,
                  color: actif ? AppColors.white : AppColors.ink,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titre(
                        pass,
                        student.passes.where((p) => p.usable).length - 1,
                      ),
                      style: text.titleMedium?.copyWith(fontSize: 15.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _sousTitre(
                        pass,
                        student.passes.where((p) => p.usable).length - 1,
                        student.totalTrips.value,
                      ),
                      style: text.bodyMedium?.copyWith(fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              if (pass?.isPending ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.ink, width: 2),
                  ),
                  child: const Text(
                    'PAYER',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: AppColors.white,
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded, size: 24),
            ],
          ),
        ),
      );
    });
  }

  /// Nomme l'état du pass.
  ///
  /// Un pass souscrit mais impayé n'est pas une absence de pass : le dire
  /// « inexistant » contredirait le sous-titre, qui annonce un paiement en
  /// attente.
  static String _titre(StudentPass? pass, int autres) {
    if (pass == null) return 'Aucun pass actif';

    if (pass.isActive) {
      final nom = pass.tarif?.label ?? 'Pass actif';
      return autres > 0 ? '$nom + $autres autre${autres > 1 ? 's' : ''}' : nom;
    }

    if (pass.isPending) return pass.tarif?.label ?? 'Pass à régler';

    return 'Aucun pass actif';
  }

  /// Décrit ce qu'il reste : jours pour un abonnement, trajets pour un
  /// ticket, ou l'invitation à souscrire.
  ///
  /// Avec plusieurs pass, c'est le total qui compte : l'étudiant veut
  /// savoir combien de trajets il a, pas comment ils se répartissent.
  static String _sousTitre(StudentPass? pass, int autres, int total) {
    if (pass == null) return 'Prends un pass avant de monter';
    if (pass.isPending) return 'Paiement en attente';
    if (!pass.isActive) return 'Prends un pass avant de monter';

    if (autres > 0) {
      return '$total trajet${total > 1 ? 's' : ''} sur ${autres + 1} pass';
    }

    if (pass.tarif?.isSubscription ?? false) {
      final j = pass.daysLeft;
      return '$j jour${j > 1 ? 's' : ''} restant${j > 1 ? 's' : ''}';
    }

    final t = pass.tripsLeft;
    return '$t trajet${t > 1 ? 's' : ''} restant${t > 1 ? 's' : ''}';
  }
}

/// Rappel de la ligne et du véhicule assignés.
class _LineCard extends GetView<HomeController> {
  const _LineCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final t = controller.student.tracking.value;
      if (t == null || t.lineName.isEmpty) return const SizedBox.shrink();

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
              'TA LIGNE',
              style: text.bodyMedium?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(t.lineName, style: text.titleMedium?.copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            // Wrap plutôt que Row : plaque et chauffeur passent à la
            // ligne sur écran étroit au lieu de déborder.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (t.plate.isNotEmpty)
                  _MetaChip(icon: Icons.badge_outlined, label: t.plate),
                if (t.driverName.isNotEmpty)
                  _MetaChip(
                    icon: Icons.person_outline_rounded,
                    label: t.driverName,
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.blueSoft,
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

/// Deux raccourcis vers la carte et l'achat de pass.
class _QuickActions extends GetView<HomeController> {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.map_rounded,
            label: 'Suivre\nsur la carte',
            color: AppColors.blue,
            onTap: () => controller.changeTab(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.add_card_rounded,
            label: 'Acheter\nun pass',
            color: AppColors.gold,
            onTap: () => controller.changeTab(2),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onColor = color == AppColors.gold ? AppColors.ink : AppColors.white;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: 2.5),
          boxShadow: Brutal.shadow(const Offset(4, 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, color: onColor),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.25,
                fontWeight: FontWeight.w900,
                color: onColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
