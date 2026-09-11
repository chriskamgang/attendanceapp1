import 'package:flutter/material.dart';

import '../bus/app/core/theme/app_colors.dart';
import '../bus/app/core/theme/app_theme.dart';
import '../main.dart';
import 'app_mode.dart';

/// Passage d'un espace à l'autre.
///
/// L'application se présente d'un seul tenant sous le nom d'Estuaire RH :
/// l'employé y pointe, l'étudiant y suit sa scolarité et la navette. Les
/// deux piles de navigation restent distinctes sous le capot, mais rien à
/// l'écran ne l'annonce.
class SwitchSpaceButton extends StatelessWidget {
  const SwitchSpaceButton({
    super.key,
    this.label = 'Revenir au pointage',
    this.destination = AppMode.estuaireRh,
  });

  final String label;

  /// Espace visé. Depuis le transport on revient aux RH, et l'inverse.
  final AppMode destination;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Brutal.radiusSmall),
        onTap: () => demander(context, destination),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.goldSoft,
            borderRadius: BorderRadius.circular(Brutal.radiusSmall),
            border: Border.all(color: AppColors.ink, width: Brutal.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.swap_horiz_rounded, size: 19),
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bascule vers [destination], sans rien demander.
  ///
  /// Il n'y a plus de dialogue : l'utilisateur qui touche « Espace
  /// étudiant » a déjà dit où il allait, et l'avertir qu'il « passe sur
  /// INSAM BUS » lui apprenait surtout qu'il existait deux applications là
  /// où il n'en voit qu'une. Les deux sessions restent ouvertes de part et
  /// d'autre : changer d'espace n'est pas se déconnecter.
  ///
  /// Exposée pour les écrans qui ont déjà leur propre style de bouton et
  /// n'ont besoin que du comportement.
  static Future<void> demander(
    BuildContext context, [
    AppMode destination = AppMode.estuaireRh,
  ]) =>
      RootApp.allerVers(destination);
}

/// Variante Material, pour les écrans de pointage qui ne suivent pas le
/// style brutaliste de l'espace étudiant.
class SwitchSpaceTile extends StatelessWidget {
  const SwitchSpaceTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.school_rounded),
      title: const Text('Espace étudiant'),
      subtitle: const Text('Emploi du temps, cours et navette du campus'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => SwitchSpaceButton.demander(context, AppMode.insamBus),
    );
  }
}
