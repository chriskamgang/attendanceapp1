import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_button.dart';
import '../../../../core/widgets/brutal_state.dart';
import '../../../../data/models/pickup_point.dart';
import '../../../../data/services/api_exception.dart';
import '../../../../data/services/session_service.dart';

/// Changement du point de ramassage habituel (CDC §3.1).
///
/// L'étudiant qui déménage corrige son arrêt sans repasser par la
/// complétion de profil, qui lui ferait ressaisir toute son identité.
Future<bool> showPickupSheet(BuildContext context) async {
  final change = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PickupSheet(),
  );

  return change ?? false;
}

class _PickupSheet extends StatefulWidget {
  const _PickupSheet();

  @override
  State<_PickupSheet> createState() => _PickupSheetState();
}

class _PickupSheetState extends State<_PickupSheet> {
  SessionService get _session => Get.find<SessionService>();

  String _selection = '';
  String _error = '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _selection = _session.user.value?.pickup?.id ?? '';
    _session.loadPickupPoints();
  }

  Future<void> _submit() async {
    final choisi = _session.pickupPoints.firstWhereOrNull(
      (p) => p.id == _selection,
    );

    if (choisi == null) {
      setState(() => _error = 'Choisis ton point de ramassage.');
      return;
    }

    setState(() {
      _sending = true;
      _error = '';
    });

    try {
      await _session.changePickupPoint(choisi);
      if (mounted) Get.back<bool>(result: true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hauteur = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: hauteur * 0.82),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ton point de montée.',
                    style: text.displayMedium?.copyWith(fontSize: 25),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'C’est là que le bus vient te chercher, et c’est ce qui '
                    'détermine les alertes que tu reçois.',
                    style: text.bodyMedium?.copyWith(
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Obx(() {
                final points = _session.pickupPoints;

                if (points.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: BrutalState.empty(
                      icon: Icons.place_outlined,
                      title: 'Aucun arrêt disponible',
                      message: 'Les points de ramassage ne sont pas encore '
                          'publiés. Reviens un peu plus tard.',
                      compact: true,
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                  itemCount: points.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (_, i) {
                    final point = points[i];

                    return _PickupTile(
                      point: point,
                      selected: _selection == point.id,
                      onTap: () => setState(() {
                        _selection = point.id;
                        _error = '';
                      }),
                    );
                  },
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error.isNotEmpty) ...[
                    Text(
                      _error,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD8341B),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  BrutalButton(
                    label: _sending ? 'Enregistrement…' : 'Enregistrer',
                    icon: Icons.check_rounded,
                    onPressed: _sending ? null : _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un arrêt proposé.
class _PickupTile extends StatelessWidget {
  const _PickupTile({
    required this.point,
    required this.selected,
    required this.onTap,
  });

  final PickupPoint point;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point.name,
                    style: text.titleMedium?.copyWith(fontSize: 14.5),
                  ),
                  if (point.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      point.address,
                      style: text.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
