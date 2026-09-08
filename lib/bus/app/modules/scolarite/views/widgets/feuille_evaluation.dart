import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_button.dart';
import '../../../../data/models/cours_evaluable.dart';
import '../../controllers/scolarite_controller.dart';

/// Saisie de l'avis sur un cours : une note, un commentaire facultatif.
///
/// Ouverte en feuille plutôt qu'en écran : l'étudiant note plusieurs cours
/// à la suite, et repartir de la liste à chaque fois lui coûterait un
/// aller-retour par avis.
class FeuilleEvaluation extends StatefulWidget {
  const FeuilleEvaluation({
    super.key,
    required this.cours,
    required this.controller,
  });

  final CoursEvaluable cours;
  final ScolariteController controller;

  static Future<void> ouvrir(
    BuildContext context, {
    required CoursEvaluable cours,
    required ScolariteController controller,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          FeuilleEvaluation(cours: cours, controller: controller),
    );
  }

  @override
  State<FeuilleEvaluation> createState() => _FeuilleEvaluationState();
}

class _FeuilleEvaluationState extends State<FeuilleEvaluation> {
  late int _note = widget.cours.monEvaluation?.note ?? 0;
  late final TextEditingController _commentaire = TextEditingController(
    text: widget.cours.monEvaluation?.commentaire ?? '',
  );

  bool _envoi = false;

  @override
  void dispose() {
    _commentaire.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (_note == 0 || _envoi) return;

    setState(() => _envoi = true);

    final passe = await widget.controller.evaluer(
      coursVise: widget.cours,
      note: _note,
      commentaire: _commentaire.text,
    );

    if (!mounted) return;

    // La feuille ne se referme qu'en cas de succès : un avis refusé doit
    // rester sous les yeux, avec sa saisie, plutôt que disparaître.
    if (passe) {
      Navigator.of(context).pop();
    } else {
      setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      // Laisse la place au clavier : sans cela il recouvrirait le champ de
      // commentaire et le bouton d'envoi.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: AppColors.ink, width: Brutal.borderThick),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Ton avis sur ce cours', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                widget.cours.nomMatiere,
                style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 20),
              _SelecteurEtoiles(
                note: _note,
                onChange: (n) => setState(() => _note = n),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _commentaire,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Un commentaire ? (facultatif)',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                    borderSide: const BorderSide(
                      color: AppColors.ink,
                      width: Brutal.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                    borderSide: const BorderSide(
                      color: AppColors.ink,
                      width: Brutal.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                    borderSide: const BorderSide(
                      color: AppColors.blue,
                      width: Brutal.borderThick,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              BrutalButton(
                label: _envoi ? 'Envoi…' : 'Envoyer mon avis',
                icon: Icons.send_rounded,
                iconTrailing: true,
                // Sans étoile, il n'y a pas d'avis à envoyer : le bouton
                // reste inerte plutôt que de laisser partir une note nulle
                // que le serveur refuserait.
                onPressed: (_note == 0 || _envoi) ? null : _envoyer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les cinq étoiles, à toucher pour noter.
class _SelecteurEtoiles extends StatelessWidget {
  const _SelecteurEtoiles({required this.note, required this.onChange});

  final int note;
  final ValueChanged<int> onChange;

  static const List<String> _mentions = [
    'Touche une étoile pour noter',
    'Très insuffisant',
    'Insuffisant',
    'Correct',
    'Bien',
    'Excellent',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => onChange(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    i <= note ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 42,
                    color: i <= note ? AppColors.warning : AppColors.inkMuted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _mentions[note],
          style: TextStyle(
            fontSize: 13,
            fontWeight: note == 0 ? FontWeight.w500 : FontWeight.w800,
            color: note == 0 ? AppColors.inkMuted : AppColors.ink,
          ),
        ),
      ],
    );
  }
}
