import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_button.dart';
import '../../../../core/widgets/brutal_field.dart';
import '../../../../data/models/boarding_count.dart';
import '../../../../data/services/boarding_service.dart';

/// Justification de l'écart entre l'effectif compté et les pass scannés.
///
/// Le départ reste bloqué tant que ces passagers sans titre ne sont pas
/// expliqués : l'écart remonte ensuite à la régulation (CDC §3.2, §3.5).
Future<bool> showGapSheet(BuildContext context) async {
  final resultat = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _GapSheet(),
  );

  return resultat ?? false;
}

class _GapSheet extends StatefulWidget {
  const _GapSheet();

  @override
  State<_GapSheet> createState() => _GapSheetState();
}

class _GapSheetState extends State<_GapSheet> {
  final TextEditingController _comment = TextEditingController();

  BoardingService get _boarding => Get.find<BoardingService>();

  String _reason = '';
  String _error = '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _boarding.loadReasons();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  GapReason? get _selected =>
      _boarding.reasons.firstWhereOrNull((r) => r.value == _reason);

  Future<void> _submit() async {
    final motif = _selected;

    if (motif == null) {
      setState(() => _error = 'Choisis un motif.');
      return;
    }

    if (motif.needsComment && _comment.text.trim().isEmpty) {
      setState(() => _error = 'Précise le motif de l’écart.');
      return;
    }

    setState(() {
      _sending = true;
      _error = '';
    });

    final ok = await _boarding.justifyGap(
      motif.value,
      comment: _comment.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      Get.back<bool>(result: true);
      return;
    }

    setState(() {
      _sending = false;
      _error = _boarding.error.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: SafeArea(
          top: false,
          child: Obx(() {
            final comptage = _boarding.count.value;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Écart de comptage.',
                  style: text.displayMedium?.copyWith(fontSize: 25),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu as compté ${comptage.headcount ?? 0} passagers pour '
                  '${comptage.validated} pass scanné'
                  '${comptage.validated > 1 ? 's' : ''}. '
                  '${comptage.withoutTicket} personne'
                  '${comptage.withoutTicket > 1 ? 's sont montées' : ' est montée'} '
                  'sans ticket.',
                  style: text.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 18),
                Text(
                  'MOTIF',
                  style: text.bodyMedium?.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 8),
                ..._boarding.reasons.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ReasonTile(
                      reason: r,
                      selected: _reason == r.value,
                      onTap: () => setState(() {
                        _reason = r.value;
                        _error = '';
                      }),
                    ),
                  ),
                ),
                if (_selected?.needsComment ?? false) ...[
                  const SizedBox(height: 6),
                  BrutalField(
                    label: 'Précision',
                    controller: _comment,
                    hint: 'Ex. groupe encadré par un enseignant',
                    icon: Icons.notes_rounded,
                  ),
                ],
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD8341B),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                BrutalButton(
                  label: _sending ? 'Envoi…' : 'Justifier et continuer',
                  icon: Icons.check_rounded,
                  onPressed: _sending ? null : _submit,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final GapReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.goldSoft : AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(
            color: AppColors.ink,
            width: selected ? Brutal.borderThick : 2,
          ),
          boxShadow: selected ? Brutal.shadow(const Offset(3, 3)) : null,
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 21,
              color: selected ? AppColors.ink : AppColors.inkMuted,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                reason.label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.ink : AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
