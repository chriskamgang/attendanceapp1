import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Constantes du langage visuel Neo-Brutalism :
/// bordures noires épaisses, angles peu arrondis, ombres dures décalées,
/// aucun dégradé, aucune ombre floue.
///
/// Commun aux deux espaces : Estuaire RH et INSAM BUS partagent ce langage,
/// seul le contenu change d'un univers à l'autre.
abstract class Brutal {
  Brutal._();

  static const double border = 2.5;
  static const double borderThick = 3.5;
  static const double radius = 14;
  static const double radiusSmall = 10;
  static const Offset shadowOffset = Offset(4, 4);
  static const Offset shadowOffsetLarge = Offset(6, 6);

  static Border get outline => Border.all(color: AppColors.ink, width: border);

  static Border get outlineThick =>
      Border.all(color: AppColors.ink, width: borderThick);

  /// Ombre dure : pas de flou, pas d'étalement.
  static List<BoxShadow> shadow([Offset offset = shadowOffset]) => [
    BoxShadow(
      color: AppColors.ink,
      offset: offset,
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];
}

abstract class AppTheme {
  AppTheme._();

  static const String fontFamily = 'SFPro';

  static const SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static ThemeData get light {
    // Rouge en primaire : c'est lui qui porte l'action. Le bleu passe en
    // secondaire, ou il tient la structure — en-tetes, titres, reperes.
    const scheme = ColorScheme.light(
      primary: AppColors.red,
      onPrimary: AppColors.white,
      secondary: AppColors.blue,
      onSecondary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.ink,
      error: AppColors.danger,
      onError: AppColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlay,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 40,
          height: 1.05,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          color: AppColors.ink,
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          height: 1.08,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.9,
          color: AppColors.ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: AppColors.inkMuted,
        ),
        bodyMedium: TextStyle(
          fontSize: 14.5,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: AppColors.inkMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
