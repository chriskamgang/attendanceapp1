import 'package:flutter/material.dart';

/// Entrée « claquée » : le bloc arrive depuis son ombre en diagonale et
/// s'immobilise net. Pas de fondu mou — le mouvement doit rester franc.
class BrutalSlideIn extends StatelessWidget {
  const BrutalSlideIn({
    super.key,
    required this.child,
    required this.animation,
    this.begin = const Offset(-18, -18),
    this.interval = const Interval(0, 1, curve: Curves.easeOutBack),
  });

  final Widget child;
  final Animation<double> animation;

  /// Décalage de départ, en pixels.
  final Offset begin;
  final Interval interval;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: interval);

    return AnimatedBuilder(
      animation: curved,
      builder: (context, inner) {
        final t = curved.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(begin.dx * (1 - t), begin.dy * (1 - t)),
            child: inner,
          ),
        );
      },
      child: child,
    );
  }
}

/// Battement discret : le bloc « respire » en s'agrandissant très légèrement.
/// Utilisé sur les éléments qui attendent une action.
class BrutalPulse extends StatefulWidget {
  const BrutalPulse({
    super.key,
    required this.child,
    this.scale = 1.03,
    this.duration = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final double scale;
  final Duration duration;

  @override
  State<BrutalPulse> createState() => _BrutalPulseState();
}

class _BrutalPulseState extends State<BrutalPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 1,
        end: widget.scale,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Rotation lente et continue, pour les décors (roue, halo, pastille).
class BrutalSpin extends StatefulWidget {
  const BrutalSpin({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 12),
    this.clockwise = true,
  });

  final Widget child;
  final Duration duration;
  final bool clockwise;

  @override
  State<BrutalSpin> createState() => _BrutalSpinState();
}

class _BrutalSpinState extends State<BrutalSpin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: widget.clockwise
          ? _c
          : Tween<double>(begin: 1, end: 0).animate(_c),
      child: widget.child,
    );
  }
}

/// Entrée en cascade : chaque enfant arrive avec un léger décalage, ce qui
/// donne du rythme aux listes sans les faire clignoter.
class BrutalStagger extends StatefulWidget {
  const BrutalStagger({
    super.key,
    required this.children,
    this.stepDelay = const Duration(milliseconds: 70),
    this.offset = const Offset(0, 18),
  });

  final List<Widget> children;
  final Duration stepDelay;
  final Offset offset;

  @override
  State<BrutalStagger> createState() => _BrutalStaggerState();
}

class _BrutalStaggerState extends State<BrutalStagger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // La durée couvre le dernier enfant plus sa propre animation.
    _c = AnimationController(
      vsync: this,
      duration:
          widget.stepDelay * widget.children.length +
          const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _c.duration!.inMilliseconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(widget.children.length, (i) {
        final start = (widget.stepDelay.inMilliseconds * i) / total;
        return BrutalSlideIn(
          animation: _c,
          begin: widget.offset,
          interval: Interval(
            start.clamp(0.0, 0.9),
            (start + 0.42).clamp(0.1, 1.0),
            curve: Curves.easeOutBack,
          ),
          child: widget.children[i],
        );
      }),
    );
  }
}

/// Compteur qui se déroule jusqu'à sa valeur : l'ETA gagne en présence
/// quand le chiffre glisse plutôt que de sauter d'un coup.
class BrutalCounter extends StatelessWidget {
  const BrutalCounter({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 520),
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(v.round().toString(), style: style),
    );
  }
}
