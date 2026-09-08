import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/cours_evaluable.dart';
import '../../controllers/scolarite_controller.dart';
import 'feuille_evaluation.dart';
import 'etoiles.dart';

/// Un cours dans la liste : son nom, et l'avis qu'on en a donné.
///
/// La carte reste cliquable une fois notée — un avis se révise, et le
/// masquer laisserait croire le contraire.
class CarteCours extends StatelessWidget {
  const CarteCours({super.key, required this.cours});

  final CoursEvaluable cours;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final avis = cours.monEvaluation;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Brutal.radius),
        onTap: () => FeuilleEvaluation.ouvrir(
          context,
          cours: cours,
          controller: Get.find<ScolariteController>(),
        ),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: cours.estEvalue ? AppColors.successSoft : AppColors.white,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: Brutal.border),
            boxShadow: Brutal.shadow(const Offset(3, 3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cours.nomMatiere,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (avis == null)
                      Text(
                        cours.codeUe.isEmpty
                            ? 'Pas encore noté'
                            : '${cours.codeUe} · pas encore noté',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Etoiles(note: avis.note, taille: 15),
                          const SizedBox(width: 8),
                          Text(
                            'Ton avis',
                            style: text.bodySmall?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                cours.estEvalue
                    ? Icons.edit_rounded
                    : Icons.chevron_right_rounded,
                size: cours.estEvalue ? 19 : 23,
                color: AppColors.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
