import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Bloc d'état : rien à afficher, erreur réseau, ou chargement.
///
/// Ces trois situations partagent la même forme pour que l'application
/// reste lisible quand elle n'a rien à montrer — un écran vide sans
/// explication laisse l'étudiant croire à une panne.
class BrutalState extends StatelessWidget {
  const BrutalState({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
    this.actionLabel,
    this.onAction,
    this.tone = BrutalStateTone.neutral,
    this.compact = false,
  });

  /// État vide : il n'y a rien, et c'est normal.
  const BrutalState.empty({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
    this.actionLabel,
    this.onAction,
    this.compact = false,
  }) : tone = BrutalStateTone.neutral;

  /// État d'erreur : quelque chose a échoué, on propose de réessayer.
  const BrutalState.error({
    super.key,
    required this.title,
    this.message = '',
    this.actionLabel = 'Réessayer',
    this.onAction,
    this.compact = false,
  }) : icon = Icons.cloud_off_rounded,
       tone = BrutalStateTone.warning;

  final IconData icon;
  final String title;
  final String message;

  final String? actionLabel;
  final VoidCallback? onAction;

  final BrutalStateTone tone;

  /// Réduit les marges, pour un bloc inséré dans une liste.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fond = switch (tone) {
      BrutalStateTone.neutral => AppColors.white,
      BrutalStateTone.warning => AppColors.goldSoft,
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 48 : 58,
            height: compact ? 48 : 58,
            decoration: BoxDecoration(
              color: tone == BrutalStateTone.warning
                  ? AppColors.gold
                  : AppColors.blueSoft,
              borderRadius: BorderRadius.circular(Brutal.radiusSmall),
              border: Border.all(color: AppColors.ink, width: 2.5),
            ),
            child: Icon(icon, size: compact ? 24 : 28, color: AppColors.ink),
          ),
          SizedBox(height: compact ? 12 : 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(
              fontSize: compact ? 15.5 : 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(fontSize: 13.5, height: 1.45),
            ),
          ],
          if (onAction != null && actionLabel != null) ...[
            SizedBox(height: compact ? 14 : 18),
            _ActionButton(label: actionLabel!, onTap: onAction!),
          ],
        ],
      ),
    );
  }
}

enum BrutalStateTone { neutral, warning }

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(color: AppColors.ink, width: 2.5),
          boxShadow: Brutal.shadow(const Offset(3, 3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

/// Bloc de chargement, à la même forme que les états vides.
class BrutalLoading extends StatelessWidget {
  const BrutalLoading({super.key, this.height = 160, this.label = ''});

  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: AppColors.blue,
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rangée de blocs gris simulant le contenu à venir.
class BrutalSkeletonList extends StatelessWidget {
  const BrutalSkeletonList({super.key, this.count = 3, this.itemHeight = 74});

  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => Container(
          height: itemHeight,
          margin: EdgeInsets.only(bottom: i == count - 1 ? 0 : 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: 2.5),
          ),
        ),
      ),
    );
  }
}
