import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Les étoiles d'une note, en lecture seule.
class Etoiles extends StatelessWidget {
  const Etoiles({super.key, required this.note, this.taille = 20, this.max = 5});

  final int note;
  final double taille;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= max; i++)
          Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Icon(
              i <= note ? Icons.star_rounded : Icons.star_outline_rounded,
              size: taille,
              color: i <= note ? AppColors.warning : AppColors.inkMuted,
            ),
          ),
      ],
    );
  }
}
