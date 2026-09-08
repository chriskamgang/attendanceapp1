import 'package:flutter/material.dart';

/// Palette INSAM — thème clair uniquement.
///
/// Rouge INSAM en primaire, bleu en secondaire, blanc et crème pour les
/// fonds, noir pour les traits et les ombres dures du Neo-Brutalism.
/// Cette palette est commune aux deux espaces : Estuaire RH et INSAM BUS
/// partagent une seule identité.
abstract class AppColors {
  AppColors._();

  // --- Rouge : la couleur d'action -------------------------------------

  /// Rouge INSAM. Porte les actions principales, les boutons pleins et
  /// les accents ; c'est la couleur qui appelle le geste.
  static const Color red = Color(0xFFC81E2D);

  /// Rouge sombre, pour les appuis et les états pressés.
  static const Color redDark = Color(0xFF8E1520);

  /// Rouge très clair, fond de bloc d'accent.
  static const Color redSoft = Color(0xFFFDE8EA);

  // --- Bleu : la couleur de structure ----------------------------------

  /// Bleu INSAM. Sert la structure : en-têtes, titres, états informatifs.
  static const Color blue = Color(0xFF1B4FD8);

  /// Bleu profond, texte fort et fonds pleins.
  static const Color blueDark = Color(0xFF11296B);

  /// Bleu très clair, fond de bloc secondaire.
  static const Color blueSoft = Color(0xFFE3EAFB);

  // --- Neutres ----------------------------------------------------------

  static const Color white = Color(0xFFFFFFFF);

  /// Blanc cassé du fond d'écran, laisse respirer les blocs blancs.
  static const Color background = Color(0xFFFBFBF8);

  /// Noir des bordures et des ombres dures.
  static const Color ink = Color(0xFF0B0B0F);

  /// Gris de texte secondaire.
  static const Color inkMuted = Color(0xFF6B6B76);

  /// Gris de séparation, plus clair que le texte muet.
  static const Color line = Color(0xFFE4E4E0);

  // --- États ------------------------------------------------------------

  /// Vert de confirmation : présence validée, paiement abouti.
  static const Color success = Color(0xFF1B7F4B);

  static const Color successSoft = Color(0xFFE3F3EA);

  /// Ambre d'attente : en cours, à confirmer.
  static const Color warning = Color(0xFFB4690E);

  static const Color warningSoft = Color(0xFFFDF0DC);

  /// Rouge d'erreur, distinct du rouge de marque pour ne pas confondre
  /// une action avec un incident.
  static const Color danger = Color(0xFFD7263D);

  static const Color dangerSoft = Color(0xFFFDE8EA);

  // --- Compatibilité ----------------------------------------------------
  //
  // L'espace bus était bâti sur un jaune d'or. La marque passant au rouge,
  // ces deux noms y renvoient : les écrans du transport suivent la nouvelle
  // identité sans qu'il faille les reprendre un à un.

  /// @deprecated Utiliser [red].
  static const Color gold = red;

  /// @deprecated Utiliser [redSoft].
  static const Color goldSoft = redSoft;
}
