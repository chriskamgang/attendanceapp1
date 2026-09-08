import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_motion.dart';
import '../controllers/onboarding_controller.dart';

class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const _TopBar(),
              Expanded(
                child: PageView(
                  controller: controller.pageController,
                  onPageChanged: controller.onPageChanged,
                  children: const [_TrackingStep(), _PassStep()],
                ),
              ),
              const _Bottom(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends GetView<OnboardingController> {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          // La marque cède la place au bouton « Passer » si l'écran est
          // trop étroit, plutôt que de déborder.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: const BrandMark(fontSize: 18),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: controller.skip,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                children: [
                  Text(
                    'Passer',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.inkMuted,
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

/// Enveloppe commune aux deux étapes : marges, défilement, hauteur pleine.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Défilement simple : les étapes règlent leurs écarts au SizedBox.
    // Pas de Spacer ici — il exigerait une hauteur bornée, que le
    // SingleChildScrollView ne fournit jamais.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

// ── Étape 1 : le suivi en direct ────────────────────────────────────────────

class _TrackingStep extends GetView<OnboardingController> {
  const _TrackingStep();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return _StepScaffold(
      children: [
        BrutalSlideIn(
          animation: controller.entry,
          begin: const Offset(-20, -20),
          child: const _TrackingArt(),
        ),
        const SizedBox(height: 30),
        BrutalSlideIn(
          animation: controller.entry,
          begin: const Offset(-14, 0),
          interval: const Interval(0.2, 1, curve: Curves.easeOutBack),
          child: const _StepBadge('ÉTAPE 01'),
        ),
        const SizedBox(height: 14),
        BrutalSlideIn(
          animation: controller.entry,
          begin: const Offset(-14, 0),
          interval: const Interval(0.3, 1, curve: Curves.easeOutBack),
          child: Text('Ton bus,\nen direct.', style: text.displayLarge),
        ),
        const SizedBox(height: 12),
        BrutalSlideIn(
          animation: controller.entry,
          begin: const Offset(0, 14),
          interval: const Interval(0.45, 1, curve: Curves.easeOut),
          child: Text(
            'Suis la position de ton car dès son départ du dépôt et connais '
            'l’heure d’arrivée estimée à ton point de ramassage.',
            style: text.bodyLarge,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Visuel de l'étape 1 : un bus qui avance sur une route hachurée, sous un
/// pointeur GPS qui bat. Tout est dessiné : aucun asset supplémentaire.
class _TrackingArt extends StatefulWidget {
  const _TrackingArt();

  @override
  State<_TrackingArt> createState() => _TrackingArtState();
}

class _TrackingArtState extends State<_TrackingArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _road = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _road.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 262,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
        boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo tournant derrière le pointeur.
          Positioned(
            top: 26,
            child: BrutalSpin(
              duration: const Duration(seconds: 14),
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.55),
                    width: 4,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    // À cheval sur le trait du cercle ; une marge négative
                    // serait refusée par Container.
                    offset: const Offset(0, -7),
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ink, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Pointeur GPS qui bat.
          Positioned(
            top: 44,
            child: BrutalPulse(
              scale: 1.07,
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.ink,
                    width: Brutal.borderThick,
                  ),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 52,
                  color: AppColors.blue,
                ),
              ),
            ),
          ),
          // Route hachurée + bus qui la parcourt.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _road,
              builder: (context, _) => SizedBox(
                height: 78,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RoadPainter(phase: _road.value),
                      ),
                    ),
                    Align(
                      alignment: Alignment(
                        // Le bus traverse d'un bord à l'autre, en boucle.
                        -1.15 + 2.3 * _road.value,
                        -0.15,
                      ),
                      child: const _BusChip(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusChip extends StatelessWidget {
  const _BusChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(Brutal.radiusSmall),
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: Brutal.shadow(const Offset(3, 3)),
      ),
      child: const Icon(
        Icons.directions_bus_filled_rounded,
        size: 26,
        color: AppColors.white,
      ),
    );
  }
}

/// Bande de route noire avec marquage central défilant.
class _RoadPainter extends CustomPainter {
  _RoadPainter({required this.phase});

  /// Avancement 0..1 du défilement des pointillés.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final roadTop = size.height * 0.52;

    canvas.drawRect(
      Rect.fromLTWH(0, roadTop, size.width, size.height - roadTop),
      Paint()..color = AppColors.ink,
    );

    final dash = Paint()
      ..color = AppColors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const period = 44.0;
    final y = roadTop + (size.height - roadTop) / 2;
    final offset = phase * period;

    for (double x = -period + offset; x < size.width; x += period) {
      canvas.drawLine(Offset(x, y), Offset(x + 22, y), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

// ── Étape 2 : le pass et les alertes ───────────────────────────────────────

class _PassStep extends GetView<OnboardingController> {
  const _PassStep();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return _StepScaffold(
      children: [
        BrutalSlideIn(
          animation: controller.entry,
          begin: const Offset(20, -20),
          child: const _PassArt(),
        ),
        const SizedBox(height: 30),
        BrutalSlideIn(
          animation: controller.entry,
          begin: const Offset(-14, 0),
          interval: const Interval(0.2, 1, curve: Curves.easeOutBack),
          child: const _StepBadge('ÉTAPE 02'),
        ),
        const SizedBox(height: 14),
        BrutalSlideIn(
          animation: controller.entry,
          begin: const Offset(-14, 0),
          interval: const Interval(0.3, 1, curve: Curves.easeOutBack),
          child: Text('Un pass,\nplus simple.', style: text.displayLarge),
        ),
        const SizedBox(height: 12),
        BrutalSlideIn(
          animation: controller.entry,
          begin: const Offset(0, 14),
          interval: const Interval(0.45, 1, curve: Curves.easeOut),
          child: Text(
            'Paie au trajet ou prends le pass semaine à tarif réduit. '
            'Tu reçois une alerte dès que ton bus quitte le dépôt.',
            style: text.bodyLarge,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Visuel de l'étape 2 : un ticket néobrutaliste qui bascule doucement,
/// avec son encoche et sa ligne de perforation.
class _PassArt extends StatelessWidget {
  const _PassArt();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      height: 262,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.white, width: Brutal.borderThick),
        boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _DiagonalPainter())),
          BrutalPulse(
            scale: 1.035,
            duration: const Duration(milliseconds: 2200),
            child: Container(
              // Largeur souple : sur un écran étroit, une valeur fixe
              // déborderait du bloc.
              constraints: const BoxConstraints(maxWidth: 232),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                border: Border.all(
                  color: AppColors.ink,
                  width: Brutal.borderThick,
                ),
                boxShadow: Brutal.shadow(),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.confirmation_number_rounded,
                        size: 22,
                        color: AppColors.blue,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'PASS SEMAINE',
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '400',
                        style: text.displayMedium?.copyWith(
                          fontSize: 40,
                          color: AppColors.blueDark,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'FCFA / jour',
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const _Perforation(),
                  const SizedBox(height: 10),
                  Text(
                    'Au lieu de 500 FCFA le trajet unitaire',
                    style: text.bodyMedium?.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
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

/// Ligne de perforation d'un ticket, en pointillés tracés à la main.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    // Tracé au pinceau plutôt qu'en Row de Containers : le nombre de
    // tirets s'ajuste seul et ne peut pas déborder de la largeur.
    return SizedBox(
      height: 3,
      width: double.infinity,
      child: CustomPaint(painter: _PerforationPainter()),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.35)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;

    const dash = 5.0;
    const gap = 4.0;
    for (double x = 0; x + dash <= size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + dash, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bandes obliques du fond, motif franc typique du style.
class _DiagonalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.08)
      ..strokeWidth = 14;

    for (double x = -size.height; x < size.width + size.height; x += 34) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Bas de page ─────────────────────────────────────────────────────────────

class _Bottom extends GetView<OnboardingController> {
  const _Bottom();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Obx(
        () => Column(
          children: [
            Row(
              children: List.generate(
                OnboardingController.stepCount,
                (i) => _Dot(active: controller.index.value == i),
              ),
            ),
            const SizedBox(height: 18),
            BrutalButton(
              label: controller.isLast ? 'Commencer' : 'Suivant',
              icon: Icons.arrow_forward_rounded,
              iconTrailing: true,
              onPressed: controller.next,
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicateur de page : barre large et pleine quand actif, carré sinon.
class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(right: 8),
      width: active ? 38 : 14,
      height: 14,
      decoration: BoxDecoration(
        color: active ? AppColors.blue : AppColors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
    );
  }
}
