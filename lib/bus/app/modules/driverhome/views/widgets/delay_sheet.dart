import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_button.dart';
import '../../../../core/widgets/brutal_field.dart';
import '../../controllers/driverhome_controller.dart';

/// Ouvre la feuille de signalement de retard (CDC §3.1 — US-04).
Future<void> showDelaySheet(
  BuildContext context,
  DriverhomeController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DelaySheet(controller: controller),
  );
}

class _DelaySheet extends StatefulWidget {
  const _DelaySheet({required this.controller});

  final DriverhomeController controller;

  @override
  State<_DelaySheet> createState() => _DelaySheetState();
}

class _DelaySheetState extends State<_DelaySheet> {
  /// Paliers courants : au volant, on choisit plus vite qu'on ne tape.
  static const List<int> _presets = [5, 10, 15, 30];

  int _minutes = 10;
  final TextEditingController _reason = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    await widget.controller.declareDelay(
      minutes: _minutes,
      reason: _reason.text.trim(),
    );
    if (mounted) Get.back<void>();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
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
                  'Signaler un retard',
                  style: text.displayMedium?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  'Les étudiants qui attendent à ton arrêt sont prévenus '
                  'tout de suite.',
                  style: text.bodyMedium?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 18),
                Text(
                  'RETARD ESTIMÉ',
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
                    for (final preset in _presets)
                      _MinuteChip(
                        minutes: preset,
                        selected: _minutes == preset,
                        onTap: () => setState(() => _minutes = preset),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                BrutalField(
                  label: 'Motif (facultatif)',
                  controller: _reason,
                  icon: Icons.notes_rounded,
                  hint: 'Ex. embouteillage au carrefour',
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 20),
                BrutalButton(
                  label: _sending ? 'Envoi…' : 'Prévenir les étudiants',
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

class _MinuteChip extends StatelessWidget {
  const _MinuteChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(color: AppColors.ink, width: 2.5),
          boxShadow: selected ? Brutal.shadow(const Offset(3, 3)) : null,
        ),
        child: Text(
          '$minutes min',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}
