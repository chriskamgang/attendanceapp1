import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_field.dart';
// Reactiver avec le bouton Google (voir plus bas).
// import '../../../core/widgets/google_mark.dart';
import '../controllers/register_controller.dart';

class RegisterView extends GetView<RegisterController> {
  const RegisterView({super.key});

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
                  const _BackButton(),
                  const SizedBox(height: 22),
                  Text('Créer ton\ncompte.', style: text.displayLarge),
                  const SizedBox(height: 10),
                  Text(
                    'Entre ton adresse email : on t’envoie un code à '
                    '6 chiffres. Tu compléteras ton profil juste après.',
                    style: text.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  Obx(
                    () => BrutalField(
                      label: 'Adresse email',
                      hint: 'prenom.nom@insam.edu',
                      icon: Icons.alternate_email_rounded,
                      controller: controller.email,
                      keyboardType: TextInputType.emailAddress,
                      error: controller.emailError.value,
                      onSubmitted: (_) => controller.submit(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Obx(
                    () => BrutalButton(
                      label: controller.loading.value
                          ? 'Envoi du code…'
                          : 'Recevoir mon code',
                      icon: Icons.arrow_forward_rounded,
                      iconTrailing: true,
                      onPressed: controller.loading.value
                          ? null
                          : controller.submit,
                    ),
                  ),
                  // Inscription Google retiree de la version 1.0 :
                  // l'App Store impose « Se connecter avec Apple » des qu'un
                  // fournisseur tiers est propose (guideline 4.8).
                  // A retablir avec Apple en meme temps.
                  // const SizedBox(height: 22),
                  // const _OrDivider(),
                  // const SizedBox(height: 22),
                  // Obx(
                  //   () => BrutalButton(
                  //     label: 'S’inscrire avec Google',
                  //     color: AppColors.white,
                  //     textColor: AppColors.ink,
                  //     iconWidget: const GoogleMark(size: 21),
                  //     onPressed: controller.loading.value
                  //         ? null
                  //         : controller.registerWithGoogle,
                  //   ),
                  // ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: controller.goToLogin,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: RichText(
                          text: TextSpan(
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            children: [
                              const TextSpan(text: 'Tu as déjà un compte ?  '),
                              TextSpan(
                                text: 'Se connecter',
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: Get.back,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(color: AppColors.ink, width: Brutal.border),
          boxShadow: Brutal.shadow(const Offset(3, 3)),
        ),
        child: const Icon(Icons.arrow_back_rounded, size: 22),
      ),
    );
  }
}

// Conserve pour la version qui reintroduira les fournisseurs tiers
// (Google + Apple) : le separateur va de pair avec ces boutons.
// ignore: unused_element
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _Rule()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OU',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: AppColors.ink,
            ),
          ),
        ),
        const Expanded(child: _Rule()),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      Container(height: 2.5, color: AppColors.ink);
}
