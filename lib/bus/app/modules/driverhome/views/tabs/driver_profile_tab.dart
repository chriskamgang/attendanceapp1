import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_motion.dart';
import '../../../../data/models/breakdown_report.dart';
import '../../../../../../launcher/switch_space_button.dart';
import '../../controllers/driverhome_controller.dart';
import '../widgets/breakdown_sheet.dart';

/// Profil chauffeur : identité, véhicule, historique de pannes, sortie.
///
/// À la différence de l'étudiant, rien n'est modifiable ici : le compte
/// est créé et tenu à jour par l'administration (CDC §2).
class DriverProfileTab extends GetView<DriverhomeController> {
  const DriverProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: const [
        BrutalStagger(
          children: [
            _IdentityCard(),
            SizedBox(height: 16),
            _AssignmentCard(),
            SizedBox(height: 16),
            _BreakdownHistory(),
            SizedBox(height: 16),
            _Actions(),
          ],
        ),
      ],
    );
  }
}

class _IdentityCard extends GetView<DriverhomeController> {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final user = controller.user;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
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
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(Brutal.radiusSmall),
              border: Border.all(color: AppColors.ink, width: 2.5),
            ),
            child: Text(
              _initials(user?.fullName ?? ''),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName.isNotEmpty == true
                      ? user!.fullName
                      : 'Chauffeur',
                  style: text.headlineMedium?.copyWith(fontSize: 21),
                ),
                const SizedBox(height: 3),
                Text(
                  user?.phone ?? '',
                  style: text.bodyMedium?.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 3),
                Text(
                  user?.email ?? '',
                  style: text.bodyMedium?.copyWith(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Initiales pour l'avatar, à défaut de photo côté backend.
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'CH';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

/// Affectation du jour : ligne, véhicule, tours prévus.
class _AssignmentCard extends GetView<DriverhomeController> {
  const _AssignmentCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final tour = controller.driver.tour.value;

      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.blueSoft,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: 2.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AFFECTATION DU JOUR',
              style: text.bodyMedium?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 10),
            _Row(
              icon: Icons.alt_route_rounded,
              label: 'Ligne',
              value: tour?.lineName ?? '—',
            ),
            _Row(
              icon: Icons.place_rounded,
              label: 'Point de ramassage',
              value: tour?.pickupName ?? '—',
            ),
            _Row(
              icon: Icons.directions_bus_filled_rounded,
              label: 'Véhicule',
              value: controller.driver.busPlate.value.isEmpty
                  ? 'Aucun bus affecté'
                  : controller.driver.busPlate.value,
            ),
            _Row(
              icon: Icons.repeat_rounded,
              label: 'Tours prévus',
              value: '${controller.driver.toursPlannedToday} par jour',
              last: true,
            ),
          ],
        ),
      );
    });
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.blueDark),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pannes déjà déclarées par ce chauffeur.
class _BreakdownHistory extends GetView<DriverhomeController> {
  const _BreakdownHistory();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final reports = controller.driver.breakdowns;
      if (reports.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PANNES DÉCLARÉES',
            style: text.bodyMedium?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          for (final r in reports)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(Brutal.radius),
                  border: Border.all(color: AppColors.ink, width: 2.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.goldSoft,
                        borderRadius: BorderRadius.circular(
                          Brutal.radiusSmall,
                        ),
                        border: Border.all(color: AppColors.ink, width: 2.5),
                      ),
                      child: Icon(r.kind.icon, size: 19, color: AppColors.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.kind.label,
                            style: text.titleMedium?.copyWith(fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.status.label,
                            style: text.bodyMedium?.copyWith(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${r.reportedAt.day.toString().padLeft(2, '0')}/'
                      '${r.reportedAt.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _Actions extends GetView<DriverhomeController> {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionRow(
          icon: Icons.report_problem_rounded,
          label: 'Déclarer une panne',
          onTap: () => showBreakdownSheet(context, controller),
        ),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Icons.help_outline_rounded,
          label: 'Aide et contact régulation',
          onTap: () => Get.snackbar(
            'Régulation',
            'Appelle le +237 6 99 00 11 22 en cas d’urgence.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.blue,
            colorText: AppColors.white,
            margin: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Icons.swap_horiz_rounded,
          label: 'Espace du personnel',
          onTap: () => SwitchSpaceButton.demander(context),
        ),
        const SizedBox(height: 10),
        Obx(
          () => _ActionRow(
            icon: Icons.logout_rounded,
            label: 'Se déconnecter',
            labelEnCours: 'Déconnexion…',
            enCours: controller.signingOut.value,
            onTap: controller.signOut,
            danger: true,
          ),
        ),
        const SizedBox(height: 10),
        // Exigee par l'App Store des lors que l'application ouvre des
        // comptes (5.1.1(v)) : les deux espaces doivent l'offrir.
        _ActionRow(
          icon: Icons.delete_outline_rounded,
          label: 'Supprimer mon compte',
          onTap: () => _confirmerSuppression(context),
          danger: true,
        ),
      ],
    );
  }
}

/// Demande confirmation avant d'effacer le compte.
///
/// Le chauffeur perd son historique de service ; si sa cagnotte n'est pas
/// soldee, le serveur refuse et le message l'oriente vers la regulation.
Future<void> _confirmerSuppression(BuildContext context) async {
  final controller = Get.find<DriverhomeController>();

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
        'Ton profil et ton historique de service seront effacés '
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
            style: TextStyle(
              color: Color(0xFFD92D20),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );

  if (confirme != true) return;

  await controller.deleteAccount();
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.enCours = false,
    this.labelEnCours,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Teinte d'accent pour la déconnexion, sans rouge : la palette n'en a pas.
  final bool danger;

  /// Action en cours : la ligne prend un indicateur et cesse de répondre.
  final bool enCours;

  /// Libellé porté pendant l'attente ; [label] sinon.
  final String? labelEnCours;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enCours ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: danger ? AppColors.goldSoft : AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: 2.5),
        ),
        child: Row(
          children: [
            if (enCours)
              const SizedBox(
                width: 21,
                height: 21,
                child: Padding(
                  padding: EdgeInsets.all(2),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.ink,
                  ),
                ),
              )
            else
              Icon(icon, size: 21, color: AppColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                enCours ? (labelEnCours ?? label) : label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: enCours ? AppColors.inkMuted : AppColors.ink,
                ),
              ),
            ),
            // Le chevron s'efface pendant l'attente : il promettrait une
            // ligne encore pressable.
            if (!enCours) const Icon(Icons.chevron_right_rounded, size: 24),
          ],
        ),
      ),
    );
  }
}
