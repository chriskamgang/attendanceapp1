import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/brutal_bottom_nav.dart';
import '../controllers/driverhome_controller.dart';
import 'tabs/bonus_tab.dart';
import 'tabs/driver_map_tab.dart';
import 'tabs/driver_profile_tab.dart';
import 'tabs/headcount_tab.dart';
import 'tabs/tour_tab.dart';

/// Espace chauffeur : en-tête de service, contenu, barre d'onglets basse.
class DriverhomeView extends GetView<DriverhomeController> {
  const DriverhomeView({super.key});

  /// La carte n'est construite qu'à sa sélection : un IndexedStack
  /// dimensionne tous ses enfants, et la vue native de Google Maps
  /// imposerait sa taille aux autres onglets.
  static Widget _tabAt(int index, int current) => switch (index) {
    0 => const TourTab(),
    1 => current == 1 ? const DriverMapTab() : const SizedBox.shrink(),
    2 => const HeadcountTab(),
    3 => const BonusTab(),
    _ => const DriverProfileTab(),
  };

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay.copyWith(
        systemNavigationBarColor: AppColors.white,
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _Header(),
              Expanded(
                child: Obx(
                  () => IndexedStack(
                    index: controller.tab.value,
                    children: List.generate(
                      5,
                      (i) => _tabAt(i, controller.tab.value),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Obx(
          () => BrutalBottomNav(
            currentIndex: controller.tab.value,
            onTap: controller.changeTab,
            items: [
              const BrutalNavItem(
                icon: Icons.route_rounded,
                label: 'Tournée',
              ),
              const BrutalNavItem(icon: Icons.map_rounded, label: 'Carte'),
              const BrutalNavItem(
                icon: Icons.groups_rounded,
                label: 'Effectifs',
              ),
              BrutalNavItem(
                icon: Icons.savings_rounded,
                label: 'Cagnotte',
                badgeCount: controller.driver.pendingMissionCount,
              ),
              const BrutalNavItem(
                icon: Icons.person_rounded,
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau de marque, avec la pastille « Chauffeur » qui distingue
/// l'espace métier de l'application étudiante.
class _Header extends GetView<DriverhomeController> {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Sous 360 px, la marque rétrécit pour laisser la place aux
          // deux boutons plutôt que de déborder.
          final tight = constraints.maxWidth < 360;

          // La marque à gauche, les deux boutons groupés à droite :
          // l'espace libre se place entre les deux, jamais entre eux.
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BrandMark(fontSize: tight ? 15 : 17),
                      const SizedBox(width: 8),
                      const _RolePill(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconButton(
                    icon: Icons.refresh_rounded,
                    onTap: controller.reload,
                    compact: tight,
                  ),
                  SizedBox(width: tight ? 7 : 10),
                  Obx(
                    () => _IconButton(
                      icon: Icons.notifications_rounded,
                      badgeCount: controller.unreadCount,
                      onTap: controller.openNotifications,
                      compact: tight,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.blueSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: const Text(
        'CHAUFFEUR',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: AppColors.blueDark,
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    this.compact = false,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Pastille de compteur, masquée à zéro.
  final int badgeCount;

  /// Réduit le bouton sur les écrans étroits.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(Brutal.radiusSmall),
              border: Border.all(color: AppColors.ink, width: 2.5),
              boxShadow: Brutal.shadow(const Offset(2.5, 2.5)),
            ),
            child: Icon(icon, size: compact ? 18 : 20, color: AppColors.ink),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
