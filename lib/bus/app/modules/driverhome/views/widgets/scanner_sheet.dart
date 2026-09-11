import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_button.dart';
import '../../../../data/models/boarding_count.dart';
import '../../../../data/services/boarding_service.dart';

/// Contrôle des titres à la montée : le chauffeur scanne le QR de chaque
/// étudiant, ce qui consomme un trajet de son pass (CDC §3.2).
Future<void> showScannerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ScannerSheet(),
  );
}

class _ScannerSheet extends StatefulWidget {
  const _ScannerSheet();

  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  final MobileScannerController _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  BoardingService get _boarding => Get.find<BoardingService>();

  /// Dernière issue affichée sous la caméra, verte ou rouge.
  ScanResult? _accepted;
  String _refused = '';

  /// Le même code peut rester dans le champ de la caméra : sans ce verrou,
  /// il partirait en boucle vers le backend.
  bool _busy = false;
  Timer? _clear;

  @override
  void dispose() {
    _clear?.cancel();
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;

    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _busy = true);

    final resultat = await _boarding.scan(code);

    if (!mounted) return;

    setState(() {
      _accepted = resultat;
      _refused = resultat == null ? _boarding.error.value : '';
    });

    // Un retour tactile distinct : le chauffeur n'a pas à quitter des yeux
    // la file des étudiants pour savoir si le titre est passé.
    if (resultat != null && !resultat.alreadyBoarded) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    // La caméra reste ouverte : l'étudiant suivant enchaîne.
    _clear?.cancel();
    _clear = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _busy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hauteur = MediaQuery.of(context).size.height;

    return Container(
      height: hauteur * 0.86,
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
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Contrôle des pass.',
                      style: text.displayMedium?.copyWith(fontSize: 24),
                    ),
                  ),
                  Obx(
                    () => _Badge(
                      value: '${_boarding.count.value.validated}',
                      label: 'scannés',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Brutal.radius),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.ink,
                        width: Brutal.borderThick,
                      ),
                      borderRadius: BorderRadius.circular(Brutal.radius),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _camera,
                          onDetect: _onDetect,
                        ),
                        const _Reticle(),
                        if (_accepted != null || _refused.isNotEmpty)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _Outcome(
                              accepted: _accepted,
                              refused: _refused,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: BrutalButton(
                label: 'Terminer le contrôle',
                color: AppColors.ink,
                onPressed: () => Get.back<void>(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cadre de visée, pour que le chauffeur sache où présenter le code.
class _Reticle extends StatelessWidget {
  const _Reticle();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 210,
          height: 210,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold, width: 4),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

/// Bandeau d'issue du dernier scan.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.accepted, required this.refused});

  final ScanResult? accepted;
  final String refused;

  @override
  Widget build(BuildContext context) {
    final ok = accepted != null;
    final deja = accepted?.alreadyBoarded ?? false;

    final couleur = !ok
        ? const Color(0xFFD8341B)
        : deja
        ? AppColors.gold
        : const Color(0xFF16A34A);

    final titre = !ok
        ? 'Titre refusé'
        : deja
        ? 'Déjà scanné'
        : accepted!.studentName;

    final detail = !ok
        ? refused
        : deja
        ? '${accepted!.studentName} est déjà à bord.'
        : accepted!.tripsLeft == null
        ? 'Pass au forfait — embarquement validé.'
        : '${accepted!.tripsLeft} trajet'
              '${accepted!.tripsLeft! > 1 ? 's' : ''} restant'
              '${accepted!.tripsLeft! > 1 ? 's' : ''}.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: couleur,
        border: const Border(
          top: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
        ),
      ),
      child: Row(
        children: [
          Icon(
            !ok
                ? Icons.close_rounded
                : deja
                ? Icons.info_rounded
                : Icons.check_rounded,
            color: deja ? AppColors.ink : AppColors.white,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: deja ? AppColors.ink : AppColors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: deja
                        ? AppColors.ink
                        : AppColors.white.withValues(alpha: 0.92),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink, width: 2.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
