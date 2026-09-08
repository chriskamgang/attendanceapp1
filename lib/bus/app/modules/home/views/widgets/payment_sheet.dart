import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_button.dart';
import '../../../../core/widgets/brutal_field.dart';
import '../../../../data/models/student_pass.dart';
import '../../../../data/services/api_exception.dart';
import '../../../../data/services/session_service.dart';
import '../../../../data/services/student_service.dart';

/// Règlement Mobile Money d'un pass souscrit (CDC §3.1, via KPay).
///
/// L'étudiant saisit son numéro, reçoit une demande USSD sur son téléphone
/// et la valide par son code secret. L'écran suit ensuite le statut jusqu'à
/// son issue.
Future<void> showPaymentSheet(
  BuildContext context,
  StudentPass pass,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _PaymentSheet(pass: pass),
  );
}

/// Opérateurs Mobile Money couverts au Cameroun.
///
/// Le backend sait déduire l'opérateur du numéro ; ce choix explicite lève
/// l'ambiguïté des préfixes portés d'un réseau à l'autre.
const _operators = [
  (code: 'MTN_MOMO_CMR', label: 'MTN MoMo', color: AppColors.gold),
  (code: 'ORANGE_CMR', label: 'Orange Money', color: Color(0xFFFF6600)),
];

/// Étapes traversées par la feuille, du formulaire à l'issue.
enum _Step { form, waiting, success, failure }

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.pass});

  final StudentPass pass;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final TextEditingController _phone = TextEditingController();

  StudentService get _student => Get.find<StudentService>();

  String _operator = _operators.first.code;

  @override
  void initState() {
    super.initState();

    // Le numéro du compte est presque toujours celui du Mobile Money :
    // le proposer évite de le retaper, sans empêcher de le corriger.
    if (Get.isRegistered<SessionService>()) {
      final tel = Get.find<SessionService>().user.value?.phone ?? '';
      if (tel.isNotEmpty) _phone.text = _lisible(tel);
    }
  }

  /// Ramène un numéro stocké au format local, plus facile à relire et à
  /// corriger que sa forme internationale.
  static String _lisible(String brut) {
    final chiffres = brut.replaceAll(RegExp(r'[^0-9]'), '');
    return chiffres.startsWith('237') ? chiffres.substring(3) : chiffres;
  }

  _Step _step = _Step.form;
  String _error = '';
  String _outcome = '';

  Timer? _poll;

  /// Nombre de consultations déjà faites, pour ne pas interroger sans fin.
  int _attempts = 0;

  /// KPay laisse au client le temps de composer son code : au-delà, on rend
  /// la main plutôt que de tourner indéfiniment.
  static const _maxAttempts = 40;

  @override
  void dispose() {
    _poll?.cancel();
    _phone.dispose();
    super.dispose();
  }

  /// Le backend attend un format international sans « + » ni zéro initial.
  String get _normalizedPhone {
    final chiffres = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (chiffres.startsWith('237')) return chiffres;
    return '237${chiffres.replaceFirst(RegExp(r'^0+'), '')}';
  }

  bool get _phoneLooksValid {
    final chiffres = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    return chiffres.length >= 9;
  }

  Future<void> _pay() async {
    if (!_phoneLooksValid) {
      setState(() => _error = 'Saisis un numéro Mobile Money valide.');
      return;
    }

    setState(() {
      _error = '';
      _step = _Step.waiting;
      _attempts = 0;
    });

    try {
      await _student.payPass(
        widget.pass,
        _normalizedPhone,
        provider: _operator,
      );
      _startPolling();
    } on ApiException catch (e) {
      setState(() {
        _step = _Step.failure;
        _outcome = e.message;
      });
    }
  }

  /// Consulte le statut à intervalle régulier ; le webhook KPay reste la
  /// source d'autorité, cette boucle ne fait qu'en rendre compte.
  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) return timer.cancel();

      _attempts++;

      try {
        final statut = await _student.paymentStatus(widget.pass);

        if (statut == 'COMPLETED') {
          timer.cancel();
          if (mounted) setState(() => _step = _Step.success);
          return;
        }

        if (statut == 'FAILED' || statut == 'CANCELLED') {
          timer.cancel();
          if (mounted) {
            setState(() {
              _step = _Step.failure;
              _outcome = statut == 'CANCELLED'
                  ? 'Tu as annulé la demande sur ton téléphone.'
                  : 'Le paiement n’a pas abouti. Vérifie ton solde et réessaie.';
            });
          }
          return;
        }
      } on ApiException {
        // Une consultation qui échoue n'invalide pas le paiement :
        // la prochaine tentative dira le vrai statut.
      }

      if (_attempts >= _maxAttempts) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _step = _Step.failure;
            _outcome =
                'Toujours sans réponse. Si tu as validé la demande, '
                'ton pass s’activera d’ici quelques instants.';
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Grip(),
              const SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: switch (_step) {
                  _Step.form => _form(context),
                  _Step.waiting => const _Waiting(),
                  _Step.success => _Outcome(
                    success: true,
                    title: 'Pass activé',
                    message:
                        'Ton paiement est confirmé. '
                        'Présente ton QR au chauffeur à la montée.',
                  ),
                  _Step.failure => _Outcome(
                    success: false,
                    title: 'Paiement non abouti',
                    message: _outcome,
                    onRetry: () => setState(() => _step = _Step.form),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Régler ton pass.', style: text.displayMedium?.copyWith(fontSize: 26)),
        const SizedBox(height: 6),
        Text(
          '${widget.pass.tarif?.label ?? 'Formule'} — '
          '${widget.pass.amountPaid} FCFA',
          style: text.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'OPÉRATEUR',
          style: text.bodyMedium?.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final op in _operators) ...[
              Expanded(
                child: _OperatorChip(
                  label: op.label,
                  color: op.color,
                  selected: _operator == op.code,
                  onTap: () => setState(() => _operator = op.code),
                ),
              ),
              if (op != _operators.last) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 16),
        BrutalField(
          label: 'Numéro Mobile Money',
          controller: _phone,
          hint: '6 XX XX XX XX',
          icon: Icons.smartphone_rounded,
          keyboardType: TextInputType.phone,
          error: _error,
          onSubmitted: (_) => _pay(),
        ),
        const SizedBox(height: 18),
        BrutalButton(
          label: 'Payer ${widget.pass.amountPaid} FCFA',
          icon: Icons.lock_rounded,
          onPressed: _pay,
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text(
              'Plus tard',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Poignée de la feuille modale.
class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _OperatorChip extends StatelessWidget {
  const _OperatorChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
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
        duration: const Duration(milliseconds: 160),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(
            color: AppColors.ink,
            width: selected ? Brutal.borderThick : 2,
          ),
          boxShadow: selected ? Brutal.shadow(const Offset(3, 3)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: selected ? AppColors.ink : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// Attente de la validation sur le téléphone de l'étudiant.
class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.blueSoft,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
          ),
          child: const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              color: AppColors.blue,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Vérifie ton téléphone.',
          style: text.displayMedium?.copyWith(fontSize: 23),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Une demande de paiement vient d’être envoyée. '
          'Saisis ton code secret Mobile Money pour la valider.',
          style: text.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

/// Issue du paiement, réussie ou non.
class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.success,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final bool success;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: success ? AppColors.blue : AppColors.goldSoft,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
            boxShadow: Brutal.shadow(const Offset(4, 4)),
          ),
          child: Icon(
            success ? Icons.check_rounded : Icons.priority_high_rounded,
            size: 44,
            color: success ? AppColors.white : AppColors.ink,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: text.displayMedium?.copyWith(fontSize: 23),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: text.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        if (onRetry != null)
          BrutalButton(label: 'Réessayer', onPressed: onRetry)
        else
          BrutalButton(
            label: 'Voir mon pass',
            icon: Icons.qr_code_rounded,
            onPressed: () => Get.back<void>(),
          ),
        const SizedBox(height: 6),
        if (onRetry != null)
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text(
              'Fermer',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.inkMuted,
              ),
            ),
          ),
      ],
    );
  }
}
