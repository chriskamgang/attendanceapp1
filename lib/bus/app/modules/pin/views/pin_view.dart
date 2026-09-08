import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../routes/app_pages.dart';
import '../controllers/pin_controller.dart';

/// Saisie du code à quatre chiffres : choix à l'inscription, puis à
/// chaque connexion.
class PinView extends GetView<PinController> {
  const PinView({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // L'adresse a été saisie à l'écran précédent : celui qui
                  // s'est trompé doit pouvoir la corriger sans fermer
                  // l'application.
                  const _RetourAccueil(),
                  const SizedBox(height: 18),
                  Text(controller.titre, style: text.displayLarge),
                  const SizedBox(height: 14),
                  Text(controller.consigne, style: text.bodyLarge),
                  const SizedBox(height: 28),
                  const _PinRow(),
                  if (controller.error.value.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              controller.error.value,
                              style: text.bodyMedium?.copyWith(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 28),
                  BrutalButton(
                    label:
                        controller.loading.value ? 'Un instant…' : 'Continuer',
                    icon: Icons.arrow_forward_rounded,
                    iconTrailing: true,
                    onPressed:
                        controller.loading.value ? null : controller.valider,
                  ),
                  // Le code oublié n'a de sens qu'à la connexion : pendant
                  // le choix, il n'y a encore rien à oublier.
                  if (controller.mode == PinMode.connexion) ...[
                    const SizedBox(height: 22),
                    Center(
                      child: GestureDetector(
                        onTap: controller.loading.value
                            ? null
                            : controller.codeOublie,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            'Code oublié ?',
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Retour à l'accueil de connexion, pour corriger l'adresse saisie.
class _RetourAccueil extends StatelessWidget {
  const _RetourAccueil();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.previousRoute.isEmpty
          ? Get.offAllNamed(Routes.WELCOMER)
          : Get.back(),
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
        child: const Icon(Icons.arrow_back_rounded, size: 22),
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PinController>(
      builder: (c) => LayoutBuilder(
        builder: (context, constraints) {
          // Quatre cases, plus larges que celles du code email : elles se
          // partagent la même largeur à deux de moins.
          const gap = 12.0;
          final cell =
              ((constraints.maxWidth - gap * (PinController.pinLength - 1)) /
                      PinController.pinLength)
                  .clamp(46.0, 66.0);

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < PinController.pinLength; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Obx(
                  () => _PinCell(
                    index: i,
                    size: cell,
                    active: c.active.value == i,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Une case du code : le chiffre reste masqué, comme un mot de passe.
class _PinCell extends GetView<PinController> {
  const _PinCell({
    required this.index,
    required this.size,
    required this.active,
  });

  final int index;

  final double size;

  /// Vrai pour la case où va la frappe : le curseur n'y bat que là.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final filled = controller.digits[index].text.isNotEmpty;

    return Container(
      width: size,
      height: size * 1.25,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.gold : AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radiusSmall),
        border: Border.all(color: AppColors.ink, width: Brutal.border),
        // La case en cours se soulève : l'œil retrouve où il en est sans
        // avoir à compter les points déjà saisis.
        boxShadow:
            Brutal.shadow(active ? const Offset(5, 5) : const Offset(3, 3)),
      ),
      child: TextField(
        controller: controller.digits[index],
        focusNode: controller.nodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        // Le curseur ne bat que dans la case en cours : partout ailleurs,
        // il désignerait un endroit où la frappe n'ira pas.
        showCursor: active,
        cursorColor: filled ? AppColors.white : AppColors.ink,
        cursorWidth: 2.5,
        cursorRadius: const Radius.circular(2),
        // Le code s'affiche en points : il se saisit souvent dans le bus,
        // voisins compris.
        obscureText: true,
        obscuringCharacter: '●',
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        // Le point saisi se lit en blanc sur la case rouge.
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w900,
          color: filled ? AppColors.white : AppColors.ink,
        ),
        decoration: const InputDecoration(
          counterText: '',
          // Le cadre est celui de la case qui entoure ce champ : les
          // contours du thème s'y ajouteraient en doublon.
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) => controller.onDigitChanged(index, value),
      ),
    );
  }
}
