import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class BrutalTopNavItem {
  const BrutalTopNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;

  /// Pastille de compteur, masquée à zéro.
  final int badgeCount;
}

/// Barre d'onglets placée en haut de l'écran, à la manière de Facebook :
/// une rangée d'icônes, l'onglet actif souligné d'un trait épais.
class BrutalTopNav extends StatelessWidget {
  const BrutalTopNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<BrutalTopNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
        ),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          return Expanded(
            child: _NavCell(
              item: items[i],
              selected: i == currentIndex,
              onTap: () => onTap(i),
            ),
          );
        }),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BrutalTopNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 7),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 24,
                  color: selected ? AppColors.blue : AppColors.inkMuted,
                ),
                if (item.badgeCount > 0)
                  Positioned(
                    right: -7,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.ink, width: 2),
                      ),
                      child: Text(
                        item.badgeCount > 9 ? '9+' : '${item.badgeCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.white,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Le trait actif remplace tout fond coloré : il marque l'onglet
          // sans alourdir la barre.
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 4,
            margin: EdgeInsets.symmetric(horizontal: selected ? 14 : 30),
            decoration: BoxDecoration(
              color: selected ? AppColors.blue : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
