import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class BrutalNavItem {
  const BrutalNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;

  /// Pastille de compteur, masquée à zéro.
  final int badgeCount;
}

/// Barre d'onglets basse, posée sur un liseré noir épais.
///
/// L'onglet actif reçoit un bloc plein encadré : le repère reste lisible
/// même du coin de l'œil, ce qu'un simple changement de teinte ne donne pas.
class BrutalBottomNav extends StatelessWidget {
  const BrutalBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    // Le bleu des bandeaux et des titres : l'onglet actif appartient à la
    // même famille que le reste de l'écran, là où le rouge tranchait.
    this.activeColor = AppColors.blueDark,
  });

  final List<BrutalNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Teinte du bloc actif. Rouge par défaut, la couleur d'action.
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(
            children: List.generate(items.length, (i) {
              return Expanded(
                child: _NavCell(
                  item: items[i],
                  selected: i == currentIndex,
                  activeColor: activeColor,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.item,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  final BrutalNavItem item;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Le texte suit la clarté du fond, et non une couleur nommée : `gold`
    // est devenu un alias de `red`, et la comparaison qui tenait lieu de
    // règle posait de l'encre noire sur un rouge soutenu — illisible.
    final onActive = activeColor.computeLuminance() > 0.5
        ? AppColors.ink
        : AppColors.white;
    final foreground = selected ? onActive : AppColors.inkMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(
            color: selected ? AppColors.ink : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: selected ? Brutal.shadow(const Offset(2.5, 2.5)) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(item.icon, size: 21, color: foreground),
                if (item.badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 17),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.ink, width: 2),
                      ),
                      child: Text(
                        item.badgeCount > 9 ? '9+' : '${item.badgeCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // FittedBox : « Effectifs » et « Cagnotte » tiennent sur les
            // écrans étroits sans couper le libellé.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.1,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
