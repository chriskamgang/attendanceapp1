import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_motion.dart';
import '../../../../core/widgets/brutal_state.dart';
import '../../../../data/models/app_notification.dart';
import '../../../../data/services/notification_service.dart';
import '../../controllers/home_controller.dart';

/// Onglet des alertes de l'espace étudiant.
class NotificationsTab extends GetView<HomeController> {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) =>
      NotificationsList(service: Get.find<NotificationService>());
}

/// Liste des alertes reçues (US-03, US-04).
///
/// Partagée par l'onglet étudiant, l'écran plein et l'espace chauffeur :
/// elle ne dépend que de la boîte commune, jamais d'un controller de rôle.
class NotificationsList extends StatelessWidget {
  const NotificationsList({super.key, required this.service});

  final NotificationService service;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: service.refresh,
      color: AppColors.blue,
      backgroundColor: AppColors.white,
      child: Obx(() {
        if (service.error.value.isNotEmpty) {
          return _Centre(
            child: BrutalState.error(
              title: 'Alertes indisponibles',
              message: service.error.value,
              onAction: service.refresh,
            ),
          );
        }

        if (service.loading.value &&
            service.items.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: const [BrutalSkeletonList(count: 4, itemHeight: 88)],
          );
        }

        if (service.items.isEmpty) {
          return _Centre(
            child: const BrutalState.empty(
              icon: Icons.notifications_off_rounded,
              title: 'Aucune alerte',
              message:
                  'Tu seras prévenu ici du départ de ton bus, '
                  'des retards et des changements de véhicule.',
            ),
          );
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            _ActionsRow(service: service),
            const SizedBox(height: 14),
            BrutalStagger(
              children: service.items
                  .map(
                    (n) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      // La clé porte l'identifiant : sans elle, Flutter
                      // réutiliserait l'état du Dismissible de la ligne
                      // suivante après une suppression.
                      child: _DismissibleNotification(
                        key: ValueKey(n.id),
                        notification: n,
                        onDismissed: () => service.remove(n.id),
                        onTap: () => service.markRead(n.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      }),
    );
  }
}

class _Centre extends StatelessWidget {
  const _Centre({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Ligne d'actions au-dessus de la liste : lecture et suppression en masse.
class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.service});

  final NotificationService service;

  @override
  Widget build(BuildContext context) {
    final nonLues = service.unreadCount;

    return Row(
      children: [
        Expanded(
          child: Text(
            nonLues > 0
                ? '$nonLues non lue${nonLues > 1 ? 's' : ''}'
                : '${service.items.length} alerte'
                      '${service.items.length > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.inkMuted,
            ),
          ),
        ),
        if (nonLues > 0) ...[
          _ActionChip(
            label: 'Tout lire',
            icon: Icons.done_all_rounded,
            onTap: service.markAllRead,
          ),
          const SizedBox(width: 8),
        ],
        _ActionChip(
          label: 'Tout vider',
          icon: Icons.delete_sweep_rounded,
          danger: true,
          onTap: () => _confirmerVidage(context),
        ),
      ],
    );
  }

  /// La suppression totale est irréversible : elle passe par une
  /// confirmation, contrairement au swipe qui ne coûte qu'une ligne.
  Future<void> _confirmerVidage(BuildContext context) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Brutal.radius),
          side: const BorderSide(color: AppColors.ink, width: Brutal.border),
        ),
        title: const Text(
          'Vider les alertes ?',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        content: const Text(
          'Toutes tes alertes seront supprimées définitivement.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Annuler',
              style: TextStyle(
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Tout supprimer',
              style: TextStyle(
                color: _danger,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    await service.removeAll();
  }
}

/// Rouge réservé aux actions destructrices ; il ne fait pas partie de la
/// palette de marque, qui ne porte que du bleu et de l'or.
const Color _danger = Color(0xFFD92D20);

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(color: AppColors.ink, width: 2.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: danger ? _danger : AppColors.ink),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: danger ? _danger : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alerte supprimable d'un glissement latéral.
class _DismissibleNotification extends StatelessWidget {
  const _DismissibleNotification({
    super.key,
    required this.notification,
    required this.onDismissed,
    required this.onTap,
  });

  final AppNotification notification;
  final Future<bool> Function() onDismissed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss-${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: _danger,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: 2.5),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.white,
          size: 22,
        ),
      ),
      // La ligne ne disparaît que si le serveur a suivi : sinon elle
      // revient en place plutôt que de laisser croire à une suppression.
      confirmDismiss: (_) => onDismissed(),
      child: _NotificationCard(notification: notification, onTap: onTap),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final nonLue = !notification.read;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: nonLue ? AppColors.white : AppColors.background,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: 2.5),
          boxShadow: nonLue ? Brutal.shadow(const Offset(4, 4)) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: nonLue ? AppColors.gold : AppColors.blueSoft,
                borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                border: Border.all(color: AppColors.ink, width: 2.5),
              ),
              child: Icon(
                notification.kind.icon,
                size: 21,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: text.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: nonLue
                                ? FontWeight.w900
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (nonLue)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(left: 8, top: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: text.bodyMedium?.copyWith(
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _relatif(notification.time),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ancienneté en clair : « il y a 6 min » plutôt qu'un horodatage.
  static String _relatif(DateTime moment) {
    final ecart = DateTime.now().difference(moment);

    if (ecart.inMinutes < 1) return 'à l’instant';
    if (ecart.inMinutes < 60) return 'il y a ${ecart.inMinutes} min';
    if (ecart.inHours < 24) return 'il y a ${ecart.inHours} h';
    if (ecart.inDays == 1) return 'hier';
    if (ecart.inDays < 7) return 'il y a ${ecart.inDays} jours';

    return '${moment.day.toString().padLeft(2, '0')}/'
        '${moment.month.toString().padLeft(2, '0')}';
  }
}
