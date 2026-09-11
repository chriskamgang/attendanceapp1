import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/pass_qr.dart';
import '../../../../data/models/student_pass.dart';
import '../../../../data/services/student_service.dart';

/// QR des pass, présentés au chauffeur à la montée (CDC §3.1).
///
/// L'étudiant peut détenir plusieurs pass de natures différentes ; chacun
/// porte son propre QR. Celui qu'il montre est celui qui sera débité — le
/// choix se fait en présentant la carte, sans manipulation dans la file.
///
/// Les codes tournent toutes les 30 secondes : une capture d'écran passée à
/// un camarade n'ouvre aucun droit.
class PassQrCard extends StatefulWidget {
  const PassQrCard({super.key});

  @override
  State<PassQrCard> createState() => _PassQrCardState();
}

class _PassQrCardState extends State<PassQrCard> {
  StudentService get _student => Get.find<StudentService>();

  /// Bat la seconde pour le compte à rebours ; le jeton, lui, est renouvelé
  /// par le service, qui seul parle au backend.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _student.startQr();
    // Un segment tombe toutes les deux secondes : battre plus vite ne
    // ferait que redessiner sans rien changer à l'écran.
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _student.stopQr();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final erreur = _student.qrError.value;
      final codes = _student.qrCodes;

      if (erreur.isNotEmpty) return _Frame(child: _Message(text: erreur));

      if (codes.isEmpty) {
        return const _Frame(
          child: SizedBox(
            height: 190,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.blue),
            ),
          ),
        );
      }

      // Un seul pass : pas de consigne de choix, elle n'aurait pas d'objet.
      if (codes.length == 1) {
        return _QrTile(qr: codes.first, showName: false);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ChoiceHint(),
          const SizedBox(height: 12),
          for (final qr in codes) ...[
            _QrTile(qr: qr, showName: true),
            if (qr != codes.last) const SizedBox(height: 14),
          ],
        ],
      );
    });
  }
}

/// Rappel que le pass montré est celui qui sera débité.
class _ChoiceHint extends StatelessWidget {
  const _ChoiceHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.blueSoft,
        borderRadius: BorderRadius.circular(Brutal.radiusSmall),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_rounded, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Montre le code du pass que tu veux utiliser : '
              'c’est celui-là qui sera débité.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un pass et son QR.
class _QrTile extends StatelessWidget {
  const _QrTile({required this.qr, required this.showName});

  final PassQr qr;

  /// Nomme le pass quand plusieurs sont affichés côte à côte.
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pass = qr.pass;

    return _Frame(
      child: Column(
        children: [
          if (showName && pass != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    pass.tarif?.label ?? 'Pass',
                    style: text.titleMedium?.copyWith(fontSize: 15.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _TripsBadge(pass: pass),
              ],
            ),
            const SizedBox(height: 14),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                'MONTRE CE CODE AU CHAUFFEUR',
                style: text.bodyMedium?.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(Brutal.radiusSmall),
              border: Border.all(color: AppColors.ink, width: 2.5),
            ),
            child: QrImageView(
              data: qr.token,
              version: QrVersions.auto,
              size: 186,
              padding: EdgeInsets.zero,
              backgroundColor: AppColors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.ink,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Countdown(qr: qr),
        ],
      ),
    );
  }
}

/// Compte à rebours du renouvellement du code.
///
/// Une barre plutôt qu'un anneau : le langage visuel de l'application est
/// fait d'angles et de bords nets, et un cercle fin passant derrière un QR
/// carré laissait des arcs flottants dans les coins.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.qr});

  final PassQr qr;

  /// Nombre de segments de la barre. Assez pour que la descente se voie,
  /// assez peu pour rester lisible d'un coup d'œil.
  static const _segments = 15;

  @override
  Widget build(BuildContext context) {
    final restants = (qr.progress * _segments).ceil().clamp(0, _segments);
    final secondes = qr.remaining.inSeconds;
    final urgent = secondes <= 5;
    final couleur = urgent ? AppColors.gold : AppColors.blue;

    return Column(
      children: [
        // Les segments restent carrés : arrondir les coins les ferait
        // glisser vers le Material, loin des bords nets du reste.
        Row(
          children: List.generate(_segments, (i) {
            return Expanded(
              child: Container(
                height: 11,
                margin: EdgeInsets.only(right: i == _segments - 1 ? 0 : 4),
                decoration: BoxDecoration(
                  color: i < restants ? couleur : AppColors.white,
                  border: Border.all(color: AppColors.ink, width: 1.8),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 11),
        // À l'approche du renouvellement, le décompte prend le pas : c'est
        // le moment où l'étudiant doit savoir que son code va changer.
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: urgent ? 13.5 : 12.5,
            fontWeight: urgent ? FontWeight.w900 : FontWeight.w800,
            color: urgent ? AppColors.ink : AppColors.inkMuted,
          ),
          child: Text(
            qr.isExpired
                ? 'Renouvellement…'
                : 'Nouveau code dans $secondes s',
          ),
        ),
      ],
    );
  }
}

/// Ce que contient le pass, en un coup d'œil.
class _TripsBadge extends StatelessWidget {
  const _TripsBadge({required this.pass});

  final StudentPass pass;

  @override
  Widget build(BuildContext context) {
    final abonnement = pass.tarif?.isSubscription ?? false;
    final valeur = abonnement
        ? '${pass.daysLeft} j'
        : '${pass.tripsLeft} trajet${pass.tripsLeft > 1 ? 's' : ''}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Text(
        valeur,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.qr_code_2_rounded, size: 40),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontSize: 13.5),
        ),
      ],
    );
  }
}

/// Encadré commun aux états de la carte.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
        boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
      ),
      child: child,
    );
  }
}
