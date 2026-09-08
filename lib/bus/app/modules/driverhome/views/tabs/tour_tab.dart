import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_motion.dart';
import '../../../../data/models/breakdown_report.dart';
import '../../../../data/models/driver_tour.dart';
import '../../../../data/models/tour_stage.dart';
import '../../controllers/driverhome_controller.dart';
import '../widgets/breakdown_sheet.dart';
import '../widgets/delay_sheet.dart';
import '../widgets/active_mission_card.dart';
import '../widgets/rescue_mission_card.dart';

/// Tournée : le cycle de pointage en cinq étapes, du dépôt au campus.
class TourTab extends GetView<DriverhomeController> {
  const TourTab({super.key});

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
              _Greeting(),
              SizedBox(height: 16),
              _PresenceCard(),
              SizedBox(height: 18),
              _MissionInbox(),
              _TourCard(),
              SizedBox(height: 16),
              _StageTimeline(),
              SizedBox(height: 16),
              _DayProgress(),
              SizedBox(height: 16),
              _DelayButton(),
              _BreakdownButton(),
            ],
          ),
        ],
      ),
    );
  }
}

class _Greeting extends GetView<DriverhomeController> {
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

/// Interrupteur de diffusion, au-dessus du cycle de pointage.
///
/// Le chauffeur doit pouvoir se retirer de la carte des étudiants sans se
/// déconnecter — pause déjeuner, trajet à vide, fin de service anticipée.
/// Le même interrupteur se trouve sur la carte ; ici il est déplié, avec
/// la conséquence écrite en toutes lettres.
class _PresenceCard extends GetView<DriverhomeController> {
  const _PresenceCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final driver = controller.driver;
      final enPause = driver.offlineByChoice.value;
      final diffuse = driver.broadcasting.value;
      final enLigne = driver.online.value;

      final titre = switch (true) {
        _ when enPause => 'Hors ligne',
        _ when diffuse => 'En ligne',
        _ when enLigne => 'Sans affectation',
        _ => 'Connexion…',
      };

      final detail = switch (true) {
        _ when enPause => 'Ton bus n’apparaît pas sur la carte des étudiants.',
        _ when diffuse => 'Les étudiants suivent ton bus en direct.',
        _ when enLigne =>
          'Aucun bus ne t’est affecté aujourd’hui : rien n’est diffusé.',
        _ => 'Mise en ligne de ta position…',
      };

      return Container(
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
        decoration: BoxDecoration(
          color: enPause ? AppColors.goldSoft : AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
          boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Center(
                child: diffuse && !enPause
                    ? BrutalPulse(
                        scale: 1.35,
                        duration: const Duration(milliseconds: 900),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.gps_off_rounded,
                        size: 21,
                        color: enPause ? AppColors.ink : AppColors.inkMuted,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: text.titleMedium?.copyWith(fontSize: 15.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: text.bodyMedium?.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _PresenceSwitch(enPause: enPause),
          ],
        ),
      );
    });
  }
}

/// Le rail de l'interrupteur, seul élément cliquable de la carte.
class _PresenceSwitch extends GetView<DriverhomeController> {
  const _PresenceSwitch({required this.enPause});

  final bool enPause;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: controller.togglePresence,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 54,
        height: 30,
        padding: const EdgeInsets.all(3),
        alignment: enPause ? Alignment.centerLeft : Alignment.centerRight,
        decoration: BoxDecoration(
          color: enPause ? AppColors.white : AppColors.blue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: enPause ? AppColors.ink : AppColors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Missions de secours en attente, posées au-dessus du cycle : une panne
/// ailleurs sur le réseau prime sur la tournée en cours.
class _MissionInbox extends GetView<DriverhomeController> {
  const _MissionInbox();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pending = controller.driver.missions
          .where((m) => !m.accepted)
          .toList();

      // Une mission acceptée reste visible jusqu'à sa clôture : sans cela,
      // elle disparaîtrait de l'écran et la prime resterait due.
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

/// Bloc principal : état du tour, étape courante et bouton d'avancement.
class _TourCard extends GetView<DriverhomeController> {
  const _TourCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final tour = controller.driver.tour.value;
      if (tour == null) return const _TourSkeleton();

      final live = tour.stage.isLive;

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
                  _ServicePill(stage: tour.stage),
                  const Spacer(),
                  Text(
                    'TOUR ${tour.index}',
                    style: text.titleMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: live ? AppColors.white : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Étape en cours',
                    style: text.bodyMedium?.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: live
                          ? AppColors.white.withValues(alpha: 0.9)
                          : AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tour.stage.label,
                    style: text.displayMedium?.copyWith(
                      fontSize: 25,
                      color: live ? AppColors.white : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _GeofenceStrip(),
                  const SizedBox(height: 14),
                  const _AdvanceButton(),
                ],
              ),
            ),
            // Bandeau bas : ligne desservie et effectif déjà saisi.
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
                  const Icon(Icons.alt_route_rounded, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tour.lineName,
                      style: text.titleMedium?.copyWith(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tour.headcount > 0)
                    Row(
                      children: [
                        const Icon(Icons.groups_rounded, size: 17),
                        const SizedBox(width: 4),
                        Text(
                          '${tour.headcount}',
                          style: text.titleMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
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

/// Pastille d'état du service, jumelle de celle de l'espace étudiant.
class _ServicePill extends StatelessWidget {
  const _ServicePill({required this.stage});

  final TourStage stage;

  @override
  Widget build(BuildContext context) {
    final live = stage.isLive;

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
            live ? 'GPS DIFFUSÉ' : 'HORS SERVICE',
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

/// Contrôle de zone (CDC §3.4) : distance à la cible et état du verrou.
class _GeofenceStrip extends GetView<DriverhomeController> {
  const _GeofenceStrip();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final driver = controller.driver;
      final tour = driver.tour.value;
      if (tour == null || !tour.stage.requiresGeofence) {
        return const SizedBox.shrink();
      }

      final ok = driver.canAdvance;
      final live = tour.stage.isLive;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ok ? AppColors.white : AppColors.goldSoft,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(color: AppColors.ink, width: 2.5),
        ),
        child: Row(
          children: [
            Icon(
              ok ? Icons.gps_fixed_rounded : Icons.lock_rounded,
              size: 18,
              color: ok ? AppColors.blue : AppColors.ink,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                ok ? 'Dans la zone de validation' : driver.lockReason,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            // Distance réelle à la cible : le contrôle de zone est tranché
            // par le backend, l'app annonce seulement ce qu'il reste à
            // parcourir pour éviter un appui perdu.
            if (live)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: ok ? AppColors.blueSoft : AppColors.gold,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                child: Text(
                  driver.busPosition.value == null
                      ? 'GPS…'
                      : _distance(driver.distance.value),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: AppColors.ink,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  /// Distance lisible d'un coup d'œil, au volant.
  ///
  /// Sans cible connue, on ne montre pas de chiffre : le tiret dit
  /// l'incertitude mieux qu'une valeur de repli.
  static String _distance(double? metres) => switch (metres) {
    null => '—',
    >= 1000 => '${(metres / 1000).toStringAsFixed(1)} km',
    _ => '${metres.round()} m',
  };
}

/// Bouton d'avancement du cycle, verrouillé hors zone.
class _AdvanceButton extends GetView<DriverhomeController> {
  const _AdvanceButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final driver = controller.driver;
      final tour = driver.tour.value;
      if (tour == null) return const SizedBox.shrink();

      final dayDone =
          tour.stage == TourStage.finished &&
          driver.toursDoneToday >= driver.toursPlannedToday;

      if (dayDone) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
          ),
          child: const Text(
            'Journée terminée — tous les tours sont validés',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        );
      }

      final unlocked = driver.canAdvance;
      final label = tour.stage.nextActionLabel;

      // Le bouton verrouillé garde sa place et son libellé : le chauffeur
      // voit ce qui l'attend, seul le cadenas change.
      return _PressableBlock(
        enabled: unlocked,
        onTap: controller.advance,
        color: unlocked ? AppColors.gold : AppColors.blueSoft,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              unlocked ? _iconFor(tour.stage) : Icons.lock_rounded,
              size: 21,
              color: unlocked ? AppColors.ink : AppColors.inkMuted,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: unlocked ? AppColors.ink : AppColors.inkMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  static IconData _iconFor(TourStage stage) => switch (stage) {
    TourStage.offline => Icons.play_arrow_rounded,
    TourStage.serviceStarted => Icons.place_rounded,
    TourStage.atPickup => Icons.groups_rounded,
    TourStage.headcountDone => Icons.local_shipping_rounded,
    TourStage.toCampus => Icons.flag_rounded,
    TourStage.finished => Icons.replay_rounded,
  };
}

/// Bloc pressable au comportement du BrutalButton, mais à contenu libre.
class _PressableBlock extends StatefulWidget {
  const _PressableBlock({
    required this.child,
    required this.onTap,
    required this.color,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color color;
  final bool enabled;

  @override
  State<_PressableBlock> createState() => _PressableBlockState();
}

class _PressableBlockState extends State<_PressableBlock> {
  bool _down = false;

  void _setDown(bool value) {
    if (!widget.enabled) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
          _down ? Brutal.shadowOffset.dx : 0,
          _down ? Brutal.shadowOffset.dy : 0,
          0,
        ),
        width: double.infinity,
        height: 58,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
          boxShadow: _down || !widget.enabled ? null : Brutal.shadow(),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Frise des cinq étapes : ce qui est fait, ce qui reste.
class _StageTimeline extends GetView<DriverhomeController> {
  const _StageTimeline();

  static const List<(TourStage, String)> _steps = [
    (TourStage.serviceStarted, 'Démarrage service'),
    (TourStage.atPickup, 'Arrivée au point'),
    (TourStage.headcountDone, 'Effectif saisi'),
    (TourStage.toCampus, 'Départ campus'),
    (TourStage.finished, 'Tour terminé'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final tour = controller.driver.tour.value;
      if (tour == null) return const SizedBox.shrink();

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
              'CYCLE DE POINTAGE',
              style: text.bodyMedium?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _steps.length; i++)
              _TimelineRow(
                position: i + 1,
                label: _steps[i].$2,
                done: tour.stage.step >= _steps[i].$1.step,
                current: tour.stage == _steps[i].$1,
                last: i == _steps.length - 1,
                time: _timeFor(tour, _steps[i].$1),
              ),
          ],
        ),
      );
    });
  }

  /// Horodatage de l'étape, affiché une fois franchie.
  static DateTime? _timeFor(DriverTour tour, TourStage stage) =>
      switch (stage) {
        TourStage.serviceStarted => tour.startedAt,
        TourStage.atPickup => tour.arrivedAtPickupAt,
        TourStage.toCampus => tour.departedAt,
        TourStage.finished => tour.finishedAt,
        _ => null,
      };
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.position,
    required this.label,
    required this.done,
    required this.current,
    required this.last,
    this.time,
  });

  final int position;
  final String label;
  final bool done;
  final bool current;
  final bool last;
  final DateTime? time;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? AppColors.blue : AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 2.5),
                ),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppColors.white,
                      )
                    : Text(
                        '$position',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2.5,
                    color: done ? AppColors.blue : AppColors.blueSoft,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: last ? 0 : 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: current ? FontWeight.w900 : FontWeight.w700,
                        color: done || current
                            ? AppColors.ink
                            : AppColors.inkMuted,
                      ),
                    ),
                  ),
                  if (time != null)
                    Text(
                      '${time!.hour.toString().padLeft(2, '0')}:'
                      '${time!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.inkMuted,
                      ),
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

/// Avancement de la journée : tours validés sur tours prévus.
class _DayProgress extends GetView<DriverhomeController> {
  const _DayProgress();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final done = controller.driver.toursDoneToday;
      final planned = controller.driver.toursPlannedToday;

      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.blueSoft,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: 2.5),
          boxShadow: Brutal.shadow(const Offset(4, 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tours d’aujourd’hui',
                    style: text.titleMedium?.copyWith(fontSize: 15),
                  ),
                ),
                Text(
                  '$done / $planned',
                  style: text.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.blueDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(planned, (i) {
                return Expanded(
                  child: Container(
                    height: 14,
                    margin: EdgeInsets.only(right: i == planned - 1 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: i < done ? AppColors.blue : AppColors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            Text(
              done >= planned
                  ? 'Prime d’assiduité acquise : '
                        '${_fcfa(500)} pour la journée.'
                  : 'Réalise tes $planned tours pour la prime d’assiduité.',
              style: text.bodyMedium?.copyWith(fontSize: 13),
            ),
          ],
        ),
      );
    });
  }

  static String _fcfa(int amount) => '$amount FCFA';
}

/// Signalement d'un retard aux étudiants desservis (US-04).
///
/// N'apparaît que sur un tour ouvert : un retard n'a de sens que pour des
/// étudiants qui attendent encore.
class _DelayButton extends GetView<DriverhomeController> {
  const _DelayButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tour = controller.driver.tour.value;

      if (tour == null || !tour.isOpen) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTap: () => showDelaySheet(context, controller),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(Brutal.radius),
              border: Border.all(color: AppColors.ink, width: 2.5),
            ),
            child: const Row(
              children: [
                Icon(Icons.schedule_rounded, size: 22, color: AppColors.ink),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Signaler un retard',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 24),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Accès à la déclaration de panne, toujours atteignable en bas d'écran.
class _BreakdownButton extends GetView<DriverhomeController> {
  const _BreakdownButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final open = controller.driver.breakdowns
          .where((b) => b.status != BreakdownStatus.resolved)
          .toList();

      if (open.isNotEmpty) {
        final b = open.first;
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.goldSoft,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: 2.5),
            boxShadow: Brutal.shadow(const Offset(4, 4)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                  border: Border.all(color: AppColors.ink, width: 2.5),
                ),
                child: Icon(b.kind.icon, size: 22, color: AppColors.ink),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.kind.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.status.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      return GestureDetector(
        onTap: () => showBreakdownSheet(context, controller),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: 2.5),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.report_problem_rounded,
                size: 22,
                color: AppColors.ink,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Déclarer une panne',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 24),
            ],
          ),
        ),
      );
    });
  }
}

class _TourSkeleton extends StatelessWidget {
  const _TourSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
        boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
      ),
      child: const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            color: AppColors.blue,
          ),
        ),
      ),
    );
  }
}
