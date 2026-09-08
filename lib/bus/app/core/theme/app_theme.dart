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
      // Les Card et les boutons de Material portent par défaut une ombre
      // floue et des angles doux, étrangers à ce langage. Les régler ici
      // suffit : les écrans qui les emploient suivent sans être réécrits.
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Brutal.radius),
          side: const BorderSide(color: AppColors.ink, width: Brutal.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.blueDark,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brutal.radiusSmall),
            side: const BorderSide(color: AppColors.ink, width: Brutal.border),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brutal.radiusSmall),
            side: const BorderSide(color: AppColors.ink, width: Brutal.border),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: AppColors.blueDark,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          side: const BorderSide(color: AppColors.ink, width: Brutal.border),
        ),
      ),
      // Les champs de saisie portent le même contour que les cartes : les
      // formulaires venus de Material gardaient un liseré fin et pâle.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          borderSide: const BorderSide(
            color: AppColors.ink,
            width: Brutal.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          borderSide: const BorderSide(
            color: AppColors.ink,
            width: Brutal.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          borderSide: const BorderSide(
            color: AppColors.blue,
            width: Brutal.borderThick,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          borderSide: const BorderSide(
            color: AppColors.danger,
            width: Brutal.border,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          borderSide: const BorderSide(
            color: AppColors.danger,
            width: Brutal.borderThick,
          ),
        ),
        labelStyle: const TextStyle(
          color: AppColors.inkMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (etats) => etats.contains(WidgetState.selected)
                ? AppColors.blueDark
                : AppColors.white,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (etats) => etats.contains(WidgetState.selected)
                ? AppColors.white
                : AppColors.ink,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.ink, width: Brutal.border),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Brutal.radiusSmall),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.blueSoft,
        side: const BorderSide(color: AppColors.ink, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          side: const BorderSide(color: AppColors.ink, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Brutal.radius),
          side: const BorderSide(
            color: AppColors.ink,
            width: Brutal.borderThick,
          ),
        ),
      ),
      // Le bandeau bleu encadré est la constante des deux espaces : les
      // écrans qui gardent une AppBar de Material — pour sa TabBar ou ses
      // actions — le reçoivent sans être réécrits.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.blueDark,
        foregroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.white),
        actionsIconTheme: IconThemeData(color: AppColors.white),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.4,
          color: AppColors.white,
        ),
        shape: Border(
          bottom: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.white,
        indicatorColor: AppColors.white,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
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
