import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Marque compacte : le logo rond suivi de « ESTUAIRE · RH ».
///
/// L'application est une seule et même chose pour celui qui l'ouvre :
/// l'étudiant y consulte son emploi du temps, note ses cours et suit la
/// navette sans avoir à savoir que le transport a été bâti à part. La
/// marque INSAM BUS ne paraît donc plus nulle part côté écran.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.fontSize = 17, this.showLogo = true});

  final double fontSize;

  /// Masque la pastille quand le logo est déjà affiché juste à côté.
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLogo) ...[
          BrandLogoDot(size: fontSize * 1.65),
          SizedBox(width: fontSize * 0.42),
        ],
        Text(
          'ESTUAIRE',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: AppColors.blueDark,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: fontSize * 0.36,
            vertical: fontSize * 0.11,
          ),
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: Text(
            'RH',
            style: TextStyle(
              fontSize: fontSize * 0.86,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// Logo rond encadré, pour les barres compactes.
class BrandLogoDot extends StatelessWidget {
  const BrandLogoDot({super.key, this.size = 30, this.shadow = false});

  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.05),
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: shadow ? Brutal.shadow(const Offset(2, 2)) : null,
      ),
      child: ClipOval(
        child: Image.asset('assets/img/logo.png', fit: BoxFit.cover),
      ),
    );
  }
}

/// Logo complet dans son bloc encadré, pour le splash et les en-têtes larges.
class BrandLogoBlock extends StatelessWidget {
  const BrandLogoBlock({super.key, this.size = 52, this.shadow = true});

  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.09),
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: Brutal.border),
        boxShadow: shadow ? Brutal.shadow(const Offset(3, 3)) : null,
      ),
      child: ClipOval(
        child: Image.asset('assets/img/logo.png', fit: BoxFit.cover),
      ),
    );
  }
}
