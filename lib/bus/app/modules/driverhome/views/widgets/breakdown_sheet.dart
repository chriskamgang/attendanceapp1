import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_button.dart';
import '../../../../core/widgets/brutal_field.dart';
import '../../../../data/models/breakdown_report.dart';
import '../../controllers/driverhome_controller.dart';

/// Ouvre la feuille de déclaration de panne (CDC §3.3).
Future<void> showBreakdownSheet(
  BuildContext context,
  DriverhomeController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BreakdownSheet(controller: controller),
  );
}

class _BreakdownSheet extends StatefulWidget {
  const _BreakdownSheet({required this.controller});

  final DriverhomeController controller;

  @override
  State<_BreakdownSheet> createState() => _BreakdownSheetState();
}

class _BreakdownSheetState extends State<_BreakdownSheet> {
  BreakdownKind _kind = BreakdownKind.mechanical;
  final TextEditingController _note = TextEditingController();

  /// Étudiants immobilisés : pré-rempli avec l'effectif du tour en cours,
  /// puisque c'est presque toujours le bon chiffre.
  late final TextEditingController _students = TextEditingController(
    text: '${widget.controller.driver.tour.value?.headcount ?? 0}',
  );

  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    _students.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    await widget.controller.declareBreakdown(
      kind: _kind,
      studentsOnBoard: int.tryParse(_students.text.trim()) ?? 0,
      note: _note.text.trim(),
    );
    if (mounted) Get.back<void>();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      // Le clavier pousse la feuille au lieu de couvrir le champ note.
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
            left: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
            right: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Déclarer une panne',
                  style: text.displayMedium?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  'La régulation reçoit l’alerte et affecte un bus de '
                  'secours à tes étudiants.',
                  style: text.bodyMedium?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 18),
                Text(
                  'NATURE DE LA PANNE',
                  style: text.bodyMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    for (final kind in BreakdownKind.values)
                      _KindChip(
                        kind: kind,
                        selected: _kind == kind,
                        onTap: () => setState(() => _kind = kind),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                BrutalField(
                  label: 'Étudiants à bord',
                  controller: _students,
                  icon: Icons.groups_rounded,
                  keyboardType: TextInputType.number,
                  hint: 'Nombre de passagers immobilisés',
                ),
                const SizedBox(height: 14),
                BrutalField(
                  label: 'Précision (facultatif)',
                  controller: _note,
                  icon: Icons.notes_rounded,
                  hint: 'Ex. bruit moteur, arrêté au carrefour',
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 20),
                BrutalButton(
                  label: _sending ? 'Envoi…' : 'Envoyer l’alerte',
                  icon: Icons.campaign_rounded,
                  color: AppColors.gold,
                  textColor: AppColors.ink,
                  onPressed: _sending ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final BreakdownKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(color: AppColors.ink, width: 2.5),
          boxShadow: selected ? Brutal.shadow(const Offset(3, 3)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(kind.icon, size: 17, color: AppColors.ink),
            const SizedBox(width: 7),
            Text(
              kind.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
