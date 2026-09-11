import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/seance_cours.dart';

/// Une journée de cours : son nom, puis ses séances dans l'ordre horaire.
class JourEmploiDuTemps extends StatelessWidget {
  const JourEmploiDuTemps({
    super.key,
    required this.jour,
    required this.seances,
  });

  final String jour;
  final List<SeanceCours> seances;

  /// Le jour d'aujourd'hui, pour le distinguer du reste de la semaine.
  ///
  /// `DateTime.weekday` numérote lundi 1 … dimanche 7, soit exactement
  /// l'ordre de [joursSemaine].
  bool get _estAujourdhui =>
      joursSemaine.indexOf(jour) == DateTime.now().weekday - 1;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              // Le backend renvoie ses jours en minuscules.
              '${jour[0].toUpperCase()}${jour.substring(1)}',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (_estAujourdhui) ...[
              const SizedBox(width: 9),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.ink, width: 1.8),
                ),
                child: const Text(
                  "AUJOURD'HUI",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        for (final seance in seances) ...[
          _Seance(seance: seance, accent: _estAujourdhui),
          if (seance != seances.last) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _Seance extends StatelessWidget {
  const _Seance({required this.seance, required this.accent});

  final SeanceCours seance;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent ? AppColors.blueSoft : AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.border),
        boxShadow: Brutal.shadow(const Offset(3, 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // L'heure d'abord : c'est elle qu'on cherche en parcourant sa
          // journée, le nom du cours ne vient qu'ensuite.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                seance.heureDebut,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                seance.heureFin,
                style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(width: 13),
          Container(width: 2.5, height: 42, color: AppColors.ink),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seance.nomMatiere,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    if (seance.codeUe.isNotEmpty)
                      _Detail(icon: Icons.tag_rounded, texte: seance.codeUe),
                    if (seance.salle != null && seance.salle!.isNotEmpty)
                      _Detail(
                        icon: Icons.meeting_room_rounded,
                        texte: seance.salle!,
                      ),
                    if (seance.campus != null && seance.campus!.isNotEmpty)
                      _Detail(
                        icon: Icons.place_rounded,
                        texte: seance.campus!,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.texte});

  final IconData icon;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.inkMuted),
        const SizedBox(width: 4),
        Text(
          texte,
          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}
