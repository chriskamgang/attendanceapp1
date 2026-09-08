import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_field.dart';
import '../controllers/driverlogin_controller.dart';

/// Connexion chauffeur : numéro de téléphone et mot de passe.
class DriverloginView extends GetView<DriverloginController> {
  const DriverloginView({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay,
      child: Scaffold(
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BackRow(),
                  const SizedBox(height: 22),
                  const _Badge(),
                  const SizedBox(height: 18),
                  Text('Espace\nchauffeur.', style: text.displayLarge),
                  const SizedBox(height: 10),
                  Obx(
                    () => Text(
                      controller.numeroConnu.value
                          ? 'Plus qu’un mot de passe et ton service démarre.'
                          : 'Ton compte a été ouvert par la régulation. '
                                'Connecte-toi avec le numéro qui y est '
                                'enregistré.',
                      style: text.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Le numéro venu de l'accueil s'affiche en rappel : le
                  // ressaisir n'apprendrait rien de plus.
                  Obx(
                    () => controller.numeroConnu.value
                        ? const _PhoneRecap()
                        : BrutalField(
                            label: 'Numéro de téléphone',
                            hint: '+237 6 XX XX XX XX',
                            icon: Icons.phone_rounded,
                            controller: controller.phone,
                            keyboardType: TextInputType.phone,
                            error: controller.phoneError.value,
                          ),
                  ),
                  const SizedBox(height: 18),
                  Obx(
                    () => BrutalField(
                      label: 'Code à 4 chiffres',
                      hint: '••••',
                      icon: Icons.lock_rounded,
                      controller: controller.pin,
                      keyboardType: TextInputType.number,
                      obscure: controller.obscure.value,
                      onToggleObscure: controller.toggleObscure,
                      error: controller.pinError.value,
                      autofocus: controller.numeroConnu.value,
                      onSubmitted: (_) => controller.submit(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Obx(
                    () => BrutalButton(
                      label: controller.loading.value
                          ? 'Connexion…'
                          : 'Prendre mon service',
                      icon: Icons.arrow_forward_rounded,
                      iconTrailing: true,
                      onPressed: controller.loading.value
                          ? null
                          : controller.submit,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _Help(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackRow extends GetView<DriverloginController> {
  const _BackRow();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: controller.goBack,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(color: AppColors.ink, width: Brutal.border),
          boxShadow: Brutal.shadow(const Offset(3, 3)),
        ),
        child: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
      ),
    );
  }
}

/// Numéro repris de l'accueil, avec de quoi le corriger.
class _PhoneRecap extends GetView<DriverloginController> {
  const _PhoneRecap();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Pas d'Obx ici : le numéro vient d'un TextEditingController, qui n'est
    // pas observable. L'Obx du parent suffit à faire apparaître ce rappel.
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 12, 13),
      decoration: BoxDecoration(
        color: AppColors.blueSoft,
        borderRadius: BorderRadius.circular(Brutal.radiusSmall),
        border: Border.all(color: AppColors.ink, width: 2.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_rounded, size: 19, color: AppColors.ink),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NUMÉRO',
                  style: text.bodyMedium?.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  controller.phone.text,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(fontSize: 15.5),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: controller.changerNumero,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                'Modifier',
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(Brutal.radiusSmall),
        border: Border.all(color: AppColors.ink, width: Brutal.border),
        boxShadow: Brutal.shadow(const Offset(3, 3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_bus_filled_rounded,
            size: 18,
            color: AppColors.ink,
          ),
          SizedBox(width: 8),
          Text(
            'CONDUCTEUR INSAM',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Help extends StatelessWidget {
  const _Help();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.blueSoft,
        borderRadius: BorderRadius.circular(Brutal.radiusSmall),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.help_outline_rounded,
                size: 17,
                color: AppColors.ink,
              ),
              const SizedBox(width: 7),
              // Sans Expanded, le libellé déborde sur un écran de 320 px.
              Expanded(
                child: Text(
                  'Mot de passe oublié ?',
                  style: text.titleMedium?.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Contacte la régulation : elle seule peut réinitialiser un '
            'compte chauffeur.',
            style: text.bodyMedium?.copyWith(fontSize: 13.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}
