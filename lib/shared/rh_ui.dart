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

/// Bandeau d'écran : le titre sur fond bleu, avec retour facultatif.
///
/// Il remplace l'`AppBar` de Material sur les écrans RH : celle-ci pose une
/// élévation floue et une flèche automatique qui jurent avec le reste.
class RhAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RhAppBar({
    super.key,
    required this.titre,
    this.sousTitre,
    this.actions,
    this.retour,
  });

  final String titre;
  final String? sousTitre;
  final List<Widget>? actions;

  /// `null` sur un onglet — il n'y a nulle part où revenir.
  final VoidCallback? retour;

  @override
  Size get preferredSize => Size.fromHeight(sousTitre == null ? 62 : 82);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.blueDark,
        border: Border(
          bottom: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(
            children: [
              if (retour != null) ...[
                _CarreAction(
                  icone: Icons.arrow_back_rounded,
                  onTap: retour!,
                  clair: true,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titre,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: AppColors.white,
                      ),
                    ),
                    if (sousTitre != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sousTitre!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton carré encadré, pour les actions d'un bandeau.
class _CarreAction extends StatelessWidget {
  const _CarreAction({
    required this.icone,
    required this.onTap,
    this.clair = false,
  });

  final IconData icone;
  final VoidCallback onTap;

  /// Posé sur fond sombre : le carré s'éclaircit au lieu de s'assombrir.
  final bool clair;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: clair
              ? AppColors.white.withValues(alpha: 0.16)
              : AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(
            color: clair ? AppColors.white : AppColors.ink,
            width: 2,
          ),
        ),
        child: Icon(
          icone,
          size: 20,
          color: clair ? AppColors.white : AppColors.ink,
        ),
      ),
    );
  }
}

/// Action d'un bandeau RH, exposée aux écrans.
class RhBarAction extends StatelessWidget {
  const RhBarAction({super.key, required this.icone, required this.onTap});

  final IconData icone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: _CarreAction(icone: icone, onTap: onTap, clair: true),
  );
}

/// Carte encadrée : le contenant de base d'un écran RH.
class RhCard extends StatelessWidget {
  const RhCard({
    super.key,
    required this.child,
    this.couleur = AppColors.white,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final Color couleur;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final boite = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.border),
        boxShadow: Brutal.shadow(const Offset(3, 3)),
      ),
      child: child,
    );

    if (onTap == null) return boite;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Brutal.radius),
        onTap: onTap,
        child: boite,
      ),
    );
  }
}

/// Tuile carrée d'une grille de services : icône colorée, libellé dessous.
class RhServiceTile extends StatelessWidget {
  const RhServiceTile({
    super.key,
    required this.titre,
    required this.icone,
    required this.accent,
    required this.onTap,
  });

  final String titre;
  final IconData icone;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Brutal.radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: Brutal.border),
            boxShadow: Brutal.shadow(const Offset(3, 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                child: Icon(icone, size: 21, color: AppColors.white),
              ),
              const SizedBox(height: 12),
              Text(
                titre,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.2,
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
}

/// Champ de saisie encadré, au langage des deux espaces.
class RhField extends StatelessWidget {
  const RhField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icone,
    this.lignes = 1,
    this.clavier,
    this.masque = false,
    this.suffixe,
    this.validation,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icone;
  final int lignes;
  final TextInputType? clavier;
  final bool masque;
  final Widget? suffixe;
  final String? Function(String?)? validation;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder bord(Color couleur, double epaisseur) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          borderSide: BorderSide(color: couleur, width: epaisseur),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: masque,
          keyboardType: clavier,
          maxLines: masque ? 1 : lignes,
          validator: validation,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: icone == null
                ? null
                : Icon(icone, size: 20, color: AppColors.blueDark),
            suffixIcon: suffixe,
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: bord(AppColors.ink, Brutal.border),
            enabledBorder: bord(AppColors.ink, Brutal.border),
            focusedBorder: bord(AppColors.blue, Brutal.borderThick),
            errorBorder: bord(AppColors.danger, Brutal.border),
            focusedErrorBorder: bord(AppColors.danger, Brutal.borderThick),
          ),
        ),
      ],
    );
  }
}
