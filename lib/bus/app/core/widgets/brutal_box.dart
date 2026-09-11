import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Bloc de base du style : fond plein, bordure noire, ombre dure décalée.
class BrutalBox extends StatelessWidget {
  const BrutalBox({
    super.key,
    required this.child,
    this.color = AppColors.white,
    this.padding = const EdgeInsets.all(20),
    this.radius = Brutal.radius,
    this.borderWidth = Brutal.border,
    this.shadowOffset = Brutal.shadowOffset,
    this.width,
    this.height,
    this.alignment,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double borderWidth;
  final Offset shadowOffset;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.ink, width: borderWidth),
        boxShadow: shadowOffset == Offset.zero
            ? null
            : Brutal.shadow(shadowOffset),
      ),
      child: child,
    );
  }
}
