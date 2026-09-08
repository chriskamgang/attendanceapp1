import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_button.dart';
import '../../../../core/widgets/brutal_motion.dart';
import '../../../../core/widgets/brutal_state.dart';
import '../../../../data/models/student_pass.dart';
import '../../../../data/services/api_exception.dart';
import '../../controllers/home_controller.dart';
import '../widgets/pass_qr_card.dart';
import '../widgets/payment_sheet.dart';

/// Pass : formule en cours et catalogue des tarifs (CDC §3.1).
class PassTab extends GetView<HomeController> {
  const PassTab({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.student.refreshPass,
      color: AppColors.blue,
      backgroundColor: AppColors.white,
      child: Obx(() {
        final student = controller.student;

        if (student.passError.value.isNotEmpty) {
          return _Centre(
            child: BrutalState.error(
              title: 'Pass indisponible',
              message: student.passError.value,
              onAction: student.refreshPass,
            ),
          );
        }

        if (student.loadingPass.value && student.tarifs.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: const [
              BrutalLoading(height: 150),
              SizedBox(height: 16),
              BrutalSkeletonList(count: 2, itemHeight: 120),
            ],
          );
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            BrutalStagger(
              children: [
                const _Title(),
                const SizedBox(height: 18),
                const _QrSection(),
                const _PassList(),
                const SizedBox(height: 20),
                const _TarifsHeader(),
                const SizedBox(height: 12),
                ...student.tarifs.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TarifCard(tarif: t),
                  ),
                ),
                if (student.tarifs.isEmpty)
                  const BrutalState.empty(
                    icon: Icons.sell_rounded,
                    title: 'Aucune formule disponible',
                    message:
                        'Les tarifs ne sont pas encore publiés. '
                        'Reviens un peu plus tard.',
                    compact: true,
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

/// Contenu centré, scrollable pour laisser passer le geste de rafraîchir.
class _Centre extends StatelessWidget {
  const _Centre({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TON ABONNEMENT',
          style: text.bodyMedium?.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text('Pass.', style: text.displayMedium?.copyWith(fontSize: 30)),
      ],
    );
  }
}

/// Les QR à présenter, quand au moins un pass est utilisable.
class _QrSection extends GetView<HomeController> {
  const _QrSection();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final utilisables = controller.student.passes.where((p) => p.usable);

      if (utilisables.isEmpty) return const SizedBox.shrink();

      return const Padding(
        padding: EdgeInsets.only(bottom: 18),
        child: PassQrCard(),
      );
    });
  }
}

/// Les pass dont l'étudiant dispose, empilés.
///
/// Il peut en détenir plusieurs de natures différentes — un forfait semaine
/// et un ticket d'appoint ne se cumulent pas, ils coexistent. Chacun garde
/// donc sa carte, avec ses trajets, sa validité et son éventuel règlement.
class _PassList extends GetView<HomeController> {
  const _PassList();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final passes = controller.student.passes;

      if (passes.isEmpty) {
        return const BrutalState.empty(
          icon: Icons.confirmation_number_rounded,
          title: 'Aucun pass actif',
          message:
              'Choisis une formule ci-dessous pour monter à bord. '
              'Le paiement se fait par Mobile Money.',
        );
      }

      return Column(
        children: [
          for (final pass in passes) ...[
            _PassCard(pass: pass),
            if (pass != passes.last) const SizedBox(height: 14),
          ],
        ],
      );
    });
  }
}

/// Un pass : ce qu'il contient, jusqu'à quand, et ce qu'il reste à régler.
class _PassCard extends StatelessWidget {
  const _PassCard({required this.pass});

  final StudentPass pass;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Un pass utilisable se distingue de celui qui attend son paiement,
    // même quand les deux portent une somme due (cas d'une recharge).
    final actif = pass.usable || pass.isActive;

    return Container(
      decoration: BoxDecoration(
        color: actif ? AppColors.blue : AppColors.goldSoft,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
        boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusChip(pass: pass, actif: actif),
                const SizedBox(height: 12),
                Text(
                  pass.tarif?.label ?? 'Formule',
                  style: text.displayMedium?.copyWith(
                    fontSize: 25,
                    color: actif ? AppColors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _reste(pass),
                  style: text.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: actif
                        ? AppColors.white.withValues(alpha: 0.9)
                        : AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.gold,
              border: Border(
                top: BorderSide(color: AppColors.white, width: 2.5),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.payments_rounded, size: 18),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        pass.needsPayment
                            ? '${pass.amountDue} FCFA à régler'
                            : '${pass.amountPaid} FCFA réglés',
                        style: text.titleMedium?.copyWith(fontSize: 13.5),
                      ),
                    ),
                    if (pass.endDate != null)
                      Text(
                        'jusqu’au ${_date(pass.endDate!)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                  ],
                ),
                if (pass.needsPayment) ...[
                  const SizedBox(height: 11),
                  BrutalButton(
                    label: 'Payer ${pass.amountDue} FCFA',
                    icon: Icons.smartphone_rounded,
                    height: 46,
                    fontSize: 14.5,
                    onPressed: () => showPaymentSheet(context, pass),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Décrit ce dont dispose l'étudiant sur ce pass.
  static String _reste(StudentPass pass) {
    // Une recharge impayée se dit à part : les trajets déjà réglés restent
    // utilisables, les autres attendent leur paiement.
    if (pass.hasRecharge) {
      final t = pass.tripsLeft;
      return '$t trajet${t > 1 ? 's' : ''} disponible${t > 1 ? 's' : ''}, '
          '${pass.pendingTrips} en attente de paiement.';
    }

    if (pass.isPending) return 'Règle ton paiement pour l’activer.';

    if (pass.tarif?.isSubscription ?? false) {
      final j = pass.daysLeft;
      return j == 0
          ? 'Dernier jour de validité.'
          : '$j jour${j > 1 ? 's' : ''} restant${j > 1 ? 's' : ''}.';
    }

    final t = pass.tripsLeft;
    return '$t trajet${t > 1 ? 's' : ''} restant${t > 1 ? 's' : ''}.';
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

/// Pastille d'état, en tête de carte.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.pass, required this.actif});

  final StudentPass pass;
  final bool actif;

  @override
  Widget build(BuildContext context) {
    final libelle = switch (true) {
      _ when pass.hasRecharge => 'Recharge à régler',
      _ when pass.isPending => 'En attente',
      _ when pass.statusLabel.isNotEmpty => pass.statusLabel,
      _ when actif => 'Actif',
      _ => 'Inactif',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: actif ? AppColors.white : AppColors.gold,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Text(
        libelle.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _TarifsHeader extends StatelessWidget {
  const _TarifsHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      'FORMULES DISPONIBLES',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
        color: AppColors.inkMuted,
      ),
    );
  }
}

/// Une formule du catalogue, souscrivable d'un geste.
class _TarifCard extends GetView<HomeController> {
  const _TarifCard({required this.tarif});

  final PassTarif tarif;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final abonnement = tarif.isSubscription;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: abonnement ? AppColors.goldSoft : AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: Brutal.shadow(const Offset(4, 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tarif.label,
                  style: text.titleMedium?.copyWith(fontSize: 16.5),
                ),
              ),
              Text(
                '${tarif.totalAmount} F',
                style: text.headlineMedium?.copyWith(
                  fontSize: 21,
                  color: AppColors.blueDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _detail(tarif),
            style: text.bodyMedium?.copyWith(fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          _SubscribeButton(tarif: tarif),
        ],
      ),
    );
  }

  static String _detail(PassTarif tarif) {
    if (!tarif.isSubscription) {
      return '${tarif.amount} FCFA le trajet.';
    }

    return '${tarif.amount} FCFA par jour, sur ${tarif.daysCovered} jours '
        '— ${tarif.tripsPerDay} trajet'
        '${tarif.tripsPerDay > 1 ? 's' : ''} par jour.';
  }
}

class _SubscribeButton extends StatefulWidget {
  const _SubscribeButton({required this.tarif});

  final PassTarif tarif;

  @override
  State<_SubscribeButton> createState() => _SubscribeButtonState();
}

class _SubscribeButtonState extends State<_SubscribeButton> {
  bool _envoi = false;

  Future<void> _souscrire() async {
    setState(() => _envoi = true);

    try {
      final souscrit = await Get.find<HomeController>().student.buyPass(
        widget.tarif,
      );

      // La souscription n'a de valeur qu'une fois réglée : le paiement
      // s'enchaîne sans laisser l'étudiant chercher où le finaliser.
      if (mounted) await showPaymentSheet(context, souscrit);
    } on ApiException catch (e) {
      Get.snackbar(
        'Souscription impossible',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.gold,
        colorText: AppColors.ink,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _envoi ? null : _souscrire,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _envoi ? AppColors.blueSoft : AppColors.blue,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(color: AppColors.ink, width: 2.5),
          boxShadow: _envoi ? null : Brutal.shadow(const Offset(3, 3)),
        ),
        child: Text(
          _envoi ? 'Souscription…' : 'Souscrire',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            color: _envoi ? AppColors.inkMuted : AppColors.white,
          ),
        ),
      ),
    );
  }
}
