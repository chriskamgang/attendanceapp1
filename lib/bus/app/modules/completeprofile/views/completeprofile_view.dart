import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_field.dart';
import '../../../core/widgets/brutal_motion.dart';
import '../../../data/models/pickup_point.dart';
import '../controllers/completeprofile_controller.dart';

class CompleteprofileView extends GetView<CompleteprofileController> {
  const CompleteprofileView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay,
      child: Scaffold(
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                const _ProgressHeader(),
                Expanded(
                  child: PageView(
                    controller: controller.pageController,
                    onPageChanged: controller.onPageChanged,
                    // La progression se fait au bouton : chaque étape doit
                    // être validée avant de passer à la suivante.
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      _IdentityStep(),
                      _MatriculeStep(),
                      _ScolariteStep(),
                      _PickupStep(),
                    ],
                  ),
                ),
                const _Bottom(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// En-tête : retour, titre, et jauge de progression en trois segments.
class _ProgressHeader extends GetView<CompleteprofileController> {
  const _ProgressHeader();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Obx(
                () => AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: controller.step.value == 0 ? 0 : 1,
                  child: GestureDetector(
                    onTap: controller.previous,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                        border: Border.all(
                          color: AppColors.ink,
                          width: Brutal.border,
                        ),
                        boxShadow: Brutal.shadow(const Offset(3, 3)),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Obx(
                () => Text(
                  'ÉTAPE ${controller.step.value + 1} / '
                  '${CompleteprofileController.stepCount}',
                  style: text.bodyMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Obx(
            () => Row(
              children: List.generate(
                CompleteprofileController.stepCount,
                (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    height: 12,
                    margin: EdgeInsets.only(
                      right: i == CompleteprofileController.stepCount - 1
                          ? 0
                          : 7,
                    ),
                    decoration: BoxDecoration(
                      color: i <= controller.step.value
                          ? AppColors.blue
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Enveloppe d'une étape : titre, sous-titre et contenu, animés à l'entrée.
class _StepBody extends GetView<CompleteprofileController> {
  const _StepBody({
    required this.title,
    required this.subtitle,
    required this.children,
    this.onRefresh,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  /// Tirer pour recharger, sur les étapes dont le contenu vient du réseau.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final contenu = SingleChildScrollView(
      // Le geste doit partir même quand la liste ne remplit pas l'écran.
      physics: onRefresh == null
          ? null
          : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrutalSlideIn(
            animation: controller.entry,
            begin: const Offset(-14, 0),
            child: Text(title, style: text.displayMedium),
          ),
          const SizedBox(height: 10),
          BrutalSlideIn(
            animation: controller.entry,
            begin: const Offset(0, 12),
            interval: const Interval(0.2, 1, curve: Curves.easeOut),
            child: Text(subtitle, style: text.bodyLarge),
          ),
          const SizedBox(height: 26),
          ...children,
        ],
      ),
    );

    if (onRefresh == null) return contenu;

    return RefreshIndicator(
      onRefresh: onRefresh!,
      color: AppColors.blue,
      backgroundColor: AppColors.white,
      child: contenu,
    );
  }
}

// ── Étape 1 : identité ──────────────────────────────────────────────────────

class _IdentityStep extends GetView<CompleteprofileController> {
  const _IdentityStep();

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Fais les\nprésentations.',
      subtitle:
          'Ces informations permettent au chauffeur de te reconnaître à ton '
          'point de ramassage.',
      children: [
        Obx(
          () => BrutalField(
            label: 'Prénom',
            hint: 'Ex. Steve',
            icon: Icons.person_outline_rounded,
            controller: controller.firstName,
            textCapitalization: TextCapitalization.words,
            error: controller.firstNameError.value,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => BrutalField(
            label: 'Nom',
            hint: 'Ex. Boussa',
            icon: Icons.badge_outlined,
            controller: controller.lastName,
            textCapitalization: TextCapitalization.words,
            error: controller.lastNameError.value,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => BrutalField(
            label: 'Téléphone',
            hint: '+237 6 00 00 00 00',
            icon: Icons.phone_outlined,
            controller: controller.phone,
            keyboardType: TextInputType.phone,
            error: controller.phoneError.value,
          ),
        ),
      ],
    );
  }
}

// ── Étape 2 : matricule ─────────────────────────────────────────────────────

class _MatriculeStep extends GetView<CompleteprofileController> {
  const _MatriculeStep();

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Ton matricule\nINSAM.',
      subtitle:
          'Il relie ton compte à ton dossier étudiant. Tu peux le renseigner '
          'plus tard si tu ne l’as pas sous la main.',
      children: [
        Obx(
          () => AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: controller.matriculeForgotten.value ? 0.4 : 1,
            child: IgnorePointer(
              ignoring: controller.matriculeForgotten.value,
              child: BrutalField(
                label: 'Matricule',
                hint: 'Ex. 24A0157',
                icon: Icons.tag_rounded,
                controller: controller.matricule,
                textCapitalization: TextCapitalization.characters,
                error: controller.matriculeError.value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _ForgotMatriculeCheckbox(),
      ],
    );
  }
}

/// Case à cocher permettant de passer l'étape du matricule.
class _ForgotMatriculeCheckbox extends GetView<CompleteprofileController> {
  const _ForgotMatriculeCheckbox();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final checked = controller.matriculeForgotten.value;

      return GestureDetector(
        onTap: () => controller.toggleMatriculeForgotten(!checked),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: checked ? AppColors.goldSoft : AppColors.white,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: 2.5),
            boxShadow: checked ? Brutal.shadow(const Offset(3, 3)) : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: checked ? AppColors.gold : AppColors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.ink, width: 2.5),
                ),
                child: checked
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.ink,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'J’ai oublié mon matricule',
                      style: text.titleMedium?.copyWith(fontSize: 15.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tu pourras l’ajouter depuis ton profil.',
                      style: text.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Étape 3 : point de ramassage ────────────────────────────────────────────

// ── Étape 3 : scolarité ─────────────────────────────────────────────────────

/// Niveau et filière de l'étudiant.
///
/// C'est ce couple, et lui seul, qui rattache l'étudiant à son emploi du
/// temps : sans lui sa semaine et ses cours resteraient vides, sans que
/// rien ne lui dise pourquoi.
class _ScolariteStep extends GetView<CompleteprofileController> {
  const _ScolariteStep();

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Ta filière\net ton niveau',
      subtitle:
          'Ils déterminent l’emploi du temps et les cours qui t’attendent '
          'dans ton espace.',
      onRefresh: controller.chargerScolarite,
      children: [
        Obx(() {
          if (controller.chargeScolarite.value) {
            return const _PickupSkeleton();
          }

          // La liste n'est pas venue : l'étape reste franchissable, le
          // profil se complétera plus tard plutôt que d'enfermer
          // l'étudiant sur un écran qu'il ne peut pas remplir.
          if (controller.niveaux.isEmpty && controller.specialites.isEmpty) {
            return _PickupError(
              message: controller.scolariteError.value.isEmpty
                  ? 'Aucune filière disponible pour le moment. Tu pourras '
                        'la renseigner depuis ton profil.'
                  : controller.scolariteError.value,
              onRetry: controller.chargerScolarite,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller.niveaux.isNotEmpty) ...[
                const _EtiquetteChamp('Niveau'),
                const SizedBox(height: 10),
                _ChoixPuces(
                  options: controller.niveaux,
                  selection: controller.niveau.value,
                  onChoisi: controller.selectNiveau,
                ),
              ],
              if (controller.specialites.isNotEmpty) ...[
                const SizedBox(height: 22),
                const _EtiquetteChamp('Filière'),
                const SizedBox(height: 10),
                _ChoixPuces(
                  options: controller.specialites,
                  selection: controller.specialite.value,
                  onChoisi: controller.selectSpecialite,
                ),
              ],
              if (controller.scolariteError.value.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  controller.scolariteError.value,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          );
        }),
      ],
    );
  }
}

class _EtiquetteChamp extends StatelessWidget {
  const _EtiquetteChamp(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Text(
      texte.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
        color: AppColors.inkMuted,
      ),
    );
  }
}

/// Une rangée de puces à choix unique.
///
/// Les intitulés sont courts — « Licence 1 », « Génie Logiciel » — et une
/// tuile pleine largeur par option remplirait l'écran pour rien.
class _ChoixPuces extends StatelessWidget {
  const _ChoixPuces({
    required this.options,
    required this.selection,
    required this.onChoisi,
  });

  final List<String> options;
  final String? selection;
  final ValueChanged<String> onChoisi;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final option in options)
          GestureDetector(
            onTap: () => onChoisi(option),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              transform: Matrix4.translationValues(
                option == selection ? 2 : 0,
                option == selection ? 2 : 0,
                0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: option == selection ? AppColors.blue : AppColors.white,
                borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                border: Border.all(color: AppColors.ink, width: 2.5),
                boxShadow: option == selection
                    ? null
                    : Brutal.shadow(const Offset(3, 3)),
              ),
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: option == selection
                      ? AppColors.white
                      : AppColors.ink,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Étape 4 : point de ramassage ────────────────────────────────────────────

class _PickupStep extends GetView<CompleteprofileController> {
  const _PickupStep();

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Où te\nrécupère-t-on ?',
      subtitle:
          'Choisis ton point de ramassage habituel. Tire vers le bas pour '
          'actualiser la liste.',
      onRefresh: controller.retryPickups,
      children: [
        Obx(() {
          if (controller.session.loadingPickups.value) {
            return const _PickupSkeleton();
          }

          // Le serveur n'a pas répondu : l'étudiant peut relancer sans
          // quitter l'écran ni ressaisir les étapes précédentes.
          if (controller.pickupError.value.isNotEmpty) {
            return _PickupError(
              message: controller.pickupError.value,
              onRetry: controller.retryPickups,
            );
          }

          final points = controller.session.pickupPoints;
          if (points.isEmpty) {
            return Text(
              'Aucun point de ramassage disponible pour le moment.',
              style: Theme.of(context).textTheme.bodyLarge,
            );
          }

          return Column(
            children: points
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PickupTile(point: p),
                  ),
                )
                .toList(),
          );
        }),
      ],
    );
  }
}

/// Échec de chargement des points : message et nouvelle tentative.
class _PickupError extends StatelessWidget {
  const _PickupError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: 2.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: text.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onRetry,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                border: Border.all(color: AppColors.ink, width: 2.5),
                boxShadow: Brutal.shadow(const Offset(3, 3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 17),
                  SizedBox(width: 7),
                  Text(
                    'Réessayer',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholders affichés pendant le chargement des points depuis le backend.
class _PickupSkeleton extends StatelessWidget {
  const _PickupSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          height: 74,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: 2.5),
          ),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.blue,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickupTile extends GetView<CompleteprofileController> {
  const _PickupTile({required this.point});

  final PickupPoint point;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final selected = controller.pickup.value?.id == point.id;

      return GestureDetector(
        onTap: () => controller.selectPickup(point),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(
            selected ? 3 : 0,
            selected ? 3 : 0,
            0,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.blue : AppColors.white,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: 2.5),
            boxShadow: selected ? null : Brutal.shadow(const Offset(4, 4)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? AppColors.white : AppColors.gold,
                  borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                  border: Border.all(color: AppColors.ink, width: 2.5),
                ),
                child: Icon(
                  Icons.place_rounded,
                  size: 24,
                  color: selected ? AppColors.blue : AppColors.ink,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      style: text.titleMedium?.copyWith(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: selected ? AppColors.white : AppColors.ink,
                      ),
                    ),
                    if (point.address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        point.address,
                        style: text.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: selected
                              ? AppColors.white.withValues(alpha: 0.85)
                              : AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected ? AppColors.white : AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 2.5),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppColors.blue,
                      )
                    : null,
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Bas de page ─────────────────────────────────────────────────────────────

class _Bottom extends GetView<CompleteprofileController> {
  const _Bottom();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Obx(
        () => BrutalButton(
          label: controller.saving.value
              ? 'Enregistrement…'
              : (controller.isLast ? 'Terminer' : 'Continuer'),
          icon: controller.isLast
              ? Icons.check_rounded
              : Icons.arrow_forward_rounded,
          iconTrailing: !controller.isLast,
          onPressed: controller.saving.value ? null : controller.next,
        ),
      ),
    );
  }
}
