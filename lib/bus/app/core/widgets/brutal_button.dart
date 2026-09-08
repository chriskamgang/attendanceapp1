import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Bouton néobrutaliste : au press, il glisse dans son ombre puis la perd.
class BrutalButton extends StatefulWidget {
  const BrutalButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = AppColors.red,
    this.textColor = AppColors.white,
    this.icon,
    this.iconWidget,
    this.iconTrailing = false,
    this.expanded = true,
    this.height = 58,
    this.fontSize = 16.5,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final IconData? icon;

  /// Remplace [icon] quand l'icône n'est pas une police (ex. logo Google).
  final Widget? iconWidget;

  /// Place l'icône après le libellé plutôt qu'avant.
  final bool iconTrailing;
  final bool expanded;
  final double height;
  final double fontSize;

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  bool _down = false;

  void _setDown(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final leading =
        widget.iconWidget ??
        (widget.icon == null
            ? null
            : Icon(widget.icon, size: 21, color: widget.textColor));

    return GestureDetector(
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
          _down ? Brutal.shadowOffset.dx : 0,
          _down ? Brutal.shadowOffset.dy : 0,
          0,
        ),
        width: widget.expanded ? double.infinity : null,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.onPressed == null ? AppColors.blueSoft : widget.color,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
          boxShadow: _down ? null : Brutal.shadow(),
        ),
        child: Row(
          mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null && !widget.iconTrailing) ...[
              leading,
              const SizedBox(width: 10),
            ],
            // Flexible + FittedBox : sur un écran étroit, le libellé se
            // réduit au lieu de pousser le bouton hors de l'écran.
            Flexible(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.expanded ? 0 : 22,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                      color: widget.onPressed == null
                          ? AppColors.inkMuted
                          : widget.textColor,
                    ),
                  ),
                ),
              ),
            ),
            if (leading != null && widget.iconTrailing) ...[
              const SizedBox(width: 10),
              leading,
            ],
          ],
        ),
      ),
    );
  }
}
