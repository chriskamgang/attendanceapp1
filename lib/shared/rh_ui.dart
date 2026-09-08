import 'package:flutter/material.dart';

import '../bus/app/core/theme/app_colors.dart';
import '../bus/app/core/theme/app_theme.dart';

export '../bus/app/core/theme/app_colors.dart';
export '../bus/app/core/theme/app_theme.dart';

/// Pièces d'interface d'Estuaire RH, dans le langage Neo-Brutalism.
///
/// Les deux espaces partagent désormais la même identité : bordures noires,
/// ombres dures, rouge INSAM pour l'action et bleu pour la structure. Ce
/// fichier rassemble ce qui revient d'un écran RH à l'autre — l'espace bus,
/// lui, garde ses propres blocs sous `bus/app/core/widgets`.

/// En-tête d'écran : un titre lourd, une ligne de contexte facultative.
class RhHeader extends StatelessWidget {
  const RhHeader({
    super.key,
    required this.titre,
    this.sousTitre,
    this.action,
  });

  final String titre;
  final String? sousTitre;

  /// Bouton posé à droite du titre (rafraîchir, filtrer…).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titre,
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: AppColors.blueDark,
                ),
              ),
              if (sousTitre != null) ...[
                const SizedBox(height: 6),
                Text(
                  sousTitre!,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    );
  }
}

/// Intitulé de section : court, capitalisé, précédé d'un trait rouge.
class RhSectionTitle extends StatelessWidget {
  const RhSectionTitle(this.libelle, {super.key, this.trailing});

  final String libelle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 17, color: AppColors.red),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            libelle.toUpperCase(),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
              color: AppColors.ink,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Pastille d'état : présent, en retard, en attente.
///
/// La couleur porte le sens, jamais seule — le libellé la double, pour
/// rester lisible sans distinguer les teintes.
class RhBadge extends StatelessWidget {
  const RhBadge({
    super.key,
    required this.libelle,
    this.couleur = AppColors.blue,
    this.fond,
    this.icone,
  });

  final String libelle;
  final Color couleur;
  final Color? fond;
  final IconData? icone;

  /// Raccourcis des états les plus fréquents du pointage.
  factory RhBadge.succes(String libelle) => RhBadge(
    libelle: libelle,
    couleur: AppColors.success,
    fond: AppColors.successSoft,
    icone: Icons.check_rounded,
  );

  factory RhBadge.attente(String libelle) => RhBadge(
    libelle: libelle,
    couleur: AppColors.warning,
    fond: AppColors.warningSoft,
    icone: Icons.schedule_rounded,
  );

  factory RhBadge.alerte(String libelle) => RhBadge(
    libelle: libelle,
    couleur: AppColors.danger,
    fond: AppColors.dangerSoft,
    icone: Icons.priority_high_rounded,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fond ?? couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.ink, width: 1.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 13, color: couleur),
            const SizedBox(width: 5),
          ],
          Text(
            libelle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chiffre mis en avant dans son bloc : heures faites, jours restants.
class RhStat extends StatelessWidget {
  const RhStat({
    super.key,
    required this.valeur,
    required this.libelle,
    this.icone,
    this.accent = AppColors.red,
  });

  final String valeur;
  final String libelle;
  final IconData? icone;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.border),
        boxShadow: Brutal.shadow(const Offset(3, 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                border: Border.all(color: AppColors.ink, width: 1.8),
              ),
              child: Icon(icone, size: 18, color: AppColors.white),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            valeur,
            style: const TextStyle(
              fontSize: 25,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            libelle,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de liste cliquable : icône encadrée, texte, chevron.
class RhTile extends StatelessWidget {
  const RhTile({
    super.key,
    required this.titre,
    this.sousTitre,
    this.icone,
    this.accent = AppColors.blue,
    this.trailing,
    this.onTap,
  });

  final String titre;
  final String? sousTitre;
  final IconData? icone;
  final Color accent;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Brutal.radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: Brutal.border),
            boxShadow: Brutal.shadow(const Offset(3, 3)),
          ),
          child: Row(
            children: [
              if (icone != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                    border: Border.all(color: AppColors.ink, width: 1.8),
                  ),
                  child: Icon(icone, size: 19, color: AppColors.white),
                ),
                const SizedBox(width: 13),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titre,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    if (sousTitre != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sousTitre!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.inkMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Écran vide : ce qu'on voit quand il n'y a rien à montrer.
class RhEmpty extends StatelessWidget {
  const RhEmpty({
    super.key,
    required this.titre,
    this.message,
    this.icone = Icons.inbox_rounded,
    this.action,
  });

  final String titre;
  final String? message;
  final IconData icone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                borderRadius: BorderRadius.circular(Brutal.radius),
                border: Border.all(color: AppColors.ink, width: Brutal.border),
                boxShadow: Brutal.shadow(const Offset(3, 3)),
              ),
              child: Icon(icone, size: 31, color: AppColors.blueDark),
            ),
            const SizedBox(height: 20),
            Text(
              titre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: AppColors.ink,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 7),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}
