import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_motion.dart';
import '../../../../../../launcher/switch_space_button.dart';
import '../../controllers/home_controller.dart';
import '../widgets/pickup_sheet.dart';

/// Profil étudiant : identité, matricule, point de ramassage (CDC §3.1).
class ProfileTab extends GetView<HomeController> {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final user = controller.session.user.value;

      return RefreshIndicator(
        onRefresh: controller.session.refreshProfile,
        color: AppColors.blue,
        backgroundColor: AppColors.white,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          children: [
            Text(
              'Ton profil.',
              style: text.displayMedium?.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 20),
            BrutalStagger(
              children: [
                _IdentityCard(
                  name: user?.fullName ?? '',
                  email: user?.email ?? '',
                ),
                const SizedBox(height: 20),
                _Field(
                  icon: Icons.tag_rounded,
                  label: 'Matricule INSAM',
                  // Le matricule peut avoir été passé à l'inscription : on invite
                  // alors explicitement à le compléter.
                  value: (user?.matricule.isEmpty ?? true)
                      ? 'À compléter'
                      : user!.matricule,
                  missing: user?.matricule.isEmpty ?? true,
                ),
                const SizedBox(height: 12),
                _Field(
                  icon: Icons.phone_outlined,
                  label: 'Téléphone',
                  value: user?.phone ?? '',
                ),
                const SizedBox(height: 12),
                _Field(
                  icon: Icons.place_outlined,
                  label: 'Point de ramassage',
                  value: user?.pickup?.name ?? 'Non défini',
                  hint: user?.pickup?.address ?? '',
                  missing: user?.pickup == null,
                  // Seul champ modifiable ici : un étudiant qui déménage
                  // change d'arrêt sans refaire tout son profil.
                  onTap: () => _changerArret(context),
                ),
                const SizedBox(height: 24),
                const SwitchSpaceButton(label: 'Espace du personnel'),
                const SizedBox(height: 14),
                _SignOutButton(onTap: controller.signOut),
                const SizedBox(height: 14),
                _DeleteAccountButton(
                  onTap: () => _confirmerSuppression(context),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

/// Demande confirmation avant d'effacer le compte.
///
/// La suppression est definitive et Apple l'exige (5.1.1(v)) : le dialogue
/// dit ce qui disparait, et le bouton rouge n'est pas celui par defaut.
Future<void> _confirmerSuppression(BuildContext context) async {
  final controller = Get.find<HomeController>();

  final confirme = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Brutal.radius),
        side: const BorderSide(color: AppColors.ink, width: Brutal.border),
      ),
      title: const Text(
        'Supprimer ton compte ?',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
      ),
      content: const Text(
        'Ton profil, ton pass et ton historique de trajets seront effacés '
        'définitivement. Cette action est irréversible.',
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
            'Supprimer',
            style: TextStyle(color: _danger, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );

  if (confirme != true) return;

  await controller.deleteAccount();
}

/// Ouvre le choix d'arrêt et confirme le changement.
Future<void> _changerArret(BuildContext context) async {
  final change = await showPickupSheet(context);

  if (!change || !context.mounted) return;

  Get.snackbar(
    'Point de ramassage mis à jour',
    'Tes alertes suivent désormais ce nouvel arrêt.',
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: AppColors.blue,
    colorText: AppColors.white,
    margin: const EdgeInsets.all(16),
  );
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.name, required this.email});

  final String name;
  final String email;

  /// Initiales affichées dans la pastille.
  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
        boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(Brutal.radiusSmall),
              border: Border.all(color: AppColors.ink, width: 2.5),
            ),
            child: Text(
              _initials,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Étudiant' : name,
                  style: text.headlineMedium?.copyWith(
                    fontSize: 20,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: text.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: AppColors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.label,
    required this.value,
    this.hint = '',
    this.missing = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Précision affichée sous la valeur : le repère d'un arrêt, par exemple.
  final String hint;

  /// Signale une information encore absente du profil.
  final bool missing;

  /// Rend le champ modifiable ; sans rappel, il reste en lecture seule.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: missing ? AppColors.goldSoft : AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: 2.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 21, color: AppColors.inkMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: text.bodyMedium?.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(value, style: text.titleMedium?.copyWith(fontSize: 15)),
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: text.bodyMedium?.copyWith(fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
            // Le chevron n'a de sens que si le champ mene quelque part :
            // l'afficher partout promettrait une action inexistante.
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, size: 22),
          ],
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Obx(() {
      final enCours = controller.signingOut.value;

      return GestureDetector(
        onTap: enCours ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Le bouton grisé pendant l'appel : sans ce retrait, seul le
            // libellé changeait et la carte semblait encore pressable.
            color: enCours ? AppColors.blueSoft : AppColors.white,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: 2.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (enCours)
                const SizedBox(
                  height: 17,
                  width: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.ink,
                  ),
                )
              else
                const Icon(Icons.logout_rounded, size: 19),
              const SizedBox(width: 8),
              Text(
                enCours ? 'Déconnexion…' : 'Se déconnecter',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: enCours ? AppColors.inkMuted : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Bouton de suppression : discret, en retrait du reste, comme il se doit
/// pour une action qu'on ne declenche pas par megarde.
class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Obx(() {
      final enCours = controller.deleting.value;

      return GestureDetector(
        onTap: enCours ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          child: enCours
              ? const SizedBox(
                  height: 17,
                  width: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _danger,
                  ),
                )
              : Text(
                  'Supprimer mon compte',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _danger,
                    decoration: TextDecoration.underline,
                    decorationColor: _danger,
                  ),
                ),
        ),
      );
    });
  }
}

/// Rouge reserve aux actions destructrices ; il ne fait pas partie de la
/// palette de marque, qui ne porte que du bleu et de l'or.
const Color _danger = Color(0xFFD92D20);

