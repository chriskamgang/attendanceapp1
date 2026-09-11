import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/brutal_bottom_nav.dart';
import '../controllers/home_controller.dart';
import '../../scolarite/views/scolarite_view.dart';
import 'tabs/home_tab.dart';
import 'tabs/map_tab.dart';
import 'tabs/pass_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/trips_tab.dart';

/// Espace étudiant : en-tête de marque, contenu, barre d'onglets basse.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  /// La carte n'est construite qu'à sa sélection : un IndexedStack
  /// dimensionne tous ses enfants, et la vue native de Google Maps
  /// imposerait sa taille aux autres onglets.
  static Widget _tabAt(int index, int current) => switch (index) {
    0 => const HomeTab(),
    // La scolarité tient le second rang : l'étudiant vient d'abord ici
    // pour ses cours, la navette n'étant qu'un des services du campus.
    1 => const ScolariteView(),
    2 => current == 2 ? const MapTab() : const SizedBox.shrink(),
    3 => const PassTab(),
    4 => const TripsTab(),
    _ => const ProfileTab(),
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
                      6,
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
            items: const [
              BrutalNavItem(icon: Icons.home_rounded, label: 'Accueil'),
              BrutalNavItem(icon: Icons.school_rounded, label: 'Scolarité'),
              BrutalNavItem(icon: Icons.map_rounded, label: 'Carte'),
              BrutalNavItem(
                icon: Icons.confirmation_number_rounded,
                label: 'Pass',
              ),
              BrutalNavItem(
                icon: Icons.receipt_long_rounded,
                label: 'Trajets',
              ),
              BrutalNavItem(icon: Icons.person_rounded, label: 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau de marque en tête d'écran : logo, rafraîchissement, alertes.
class _Header extends GetView<HomeController> {
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
                  child: BrandMark(fontSize: tight ? 16 : 19),
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
                      badgeCount: controller.student.unreadCount,
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
    );
  }
}
