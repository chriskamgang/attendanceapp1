import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_field.dart';
// Reactiver avec le bouton Google (voir plus bas).
// import '../../../core/widgets/google_mark.dart';
import '../../../../../main.dart';
import '../controllers/welcomer_controller.dart';

class WelcomerView extends GetView<WelcomerController> {
  const WelcomerView({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay,
      // Cet écran est la racine de sa pile : sans cela, le bouton retour
      // d'Android fermerait l'application au lieu de rendre la main au
      // login du personnel, d'où l'on vient.
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (aQuitte, _) {
          if (!aQuitte) RootApp.revenirAEstuaireRh();
        },
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
                    const _Header(),
                    const SizedBox(height: 26),
                    Text('Bienvenue à\nbord.', style: text.displayLarge),
                    const SizedBox(height: 10),
                    Text(controller.intro, style: text.bodyLarge),
                    const SizedBox(height: 28),
                    // Seul le message d'erreur varie ici : le champ attend
                    // une adresse, l'écran n'accueillant que l'étudiant.
                    Obx(
                      () => BrutalField(
                        label: controller.label,
                        hint: controller.hint,
                        icon: controller.icon,
                        controller: controller.identifiant,
                        keyboardType: controller.keyboardType,
                        error: controller.identifiantError.value,
                        onSubmitted: (_) => controller.continuer(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Obx(
                      () => BrutalButton(
                        label: controller.loading.value
                            ? 'Connexion…'
                            : 'Continuer',
                        icon: Icons.arrow_forward_rounded,
                        iconTrailing: true,
                        onPressed: controller.loading.value
                            ? null
                            : controller.continuer,
                      ),
                    ),
                    // Le chauffeur se déclare au login du personnel, d'où
                    // l'on vient : cet écran n'accueille plus que l'étudiant.
                    //
                    // Connexion Google retiree de la version 1.0 : l'App Store
                    // impose « Se connecter avec Apple » des qu'un fournisseur
                    // tiers est propose (guideline 4.8). A retablir avec Apple
                    // en meme temps.
                    const SizedBox(height: 26),
                    const _RegisterRow(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Retour au login du personnel.
///
/// L'étudiant arrive ici depuis la carte « Espace étudiant » : il doit
/// pouvoir revenir sur ses pas s'il s'est trompé de porte, sans avoir à
/// fermer l'application.
class _RetourPersonnel extends StatelessWidget {
  const _RetourPersonnel();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: RootApp.revenirAEstuaireRh,
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _RetourPersonnel(),
        const SizedBox(width: 12),
        const BrandLogoBlock(size: 52),
        const SizedBox(width: 12),
        // Expanded borne la colonne : sans lui, la marque déborde sur les
        // écrans étroits.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandMark(fontSize: 17, showLogo: false),
              const SizedBox(height: 2),
              Text(
                'Scolarité et transport',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Conserve pour la version qui reintroduira les fournisseurs tiers
// (Google + Apple) : le separateur va de pair avec ces boutons.
// ignore: unused_element
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      Container(height: 2.5, color: AppColors.ink);
}

/// Case « Je suis chauffeur », sous le champ d'identification.
///
/// Le chauffeur est inscrit par la régulation : il n'a ni code à recevoir
/// ni compte à créer. La cocher bascule le champ sur son numéro et mène
/// droit au mot de passe.
class _RegisterRow extends GetView<WelcomerController> {
  const _RegisterRow();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: GestureDetector(
        onTap: controller.goToRegister,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.goldSoft,
            borderRadius: BorderRadius.circular(Brutal.radiusSmall),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Nouveau à l’INSAM ?',
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Créer un compte',
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
