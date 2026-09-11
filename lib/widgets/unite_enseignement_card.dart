import 'package:flutter/material.dart';
import '../models/unite_enseignement.dart';
import '../shared/rh_ui.dart';

class UniteEnseignementCard extends StatelessWidget {
  final UniteEnseignement ue;
  final VoidCallback? onTap;

  const UniteEnseignementCard({
    super.key,
    required this.ue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Brutal.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec code UE et statut
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ue.codeUe,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ue.nomMatiere,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ue.isActivee()
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(Brutal.radius),
                    ),
                    child: Text(
                      ue.isActivee() ? 'Activée' : 'En attente',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: ue.isActivee()
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),

              if (ue.isActivee()) ...[
                const SizedBox(height: 16),
                // Barre de progression
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progression',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        Text(
                          ue.getFormattedPourcentage(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                      child: LinearProgressIndicator(
                        value: ue.pourcentageProgression / 100,
                        minHeight: 8,
                        backgroundColor: AppColors.line,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getProgressColor(ue.pourcentageProgression),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Statistiques
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        context,
                        icon: Icons.access_time,
                        label: 'Effectuées',
                        value: '${ue.heuresEffectuees.toStringAsFixed(1)}h',
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        context,
                        icon: Icons.hourglass_empty,
                        label: 'Restantes',
                        value: '${ue.heuresRestantes.toStringAsFixed(1)}h',
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        context,
                        icon: Icons.schedule,
                        label: 'Total',
                        value: '${ue.volumeHoraireTotal.toStringAsFixed(1)}h',
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Montants
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Montant payé',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${ue.montantPaye.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: AppColors.line,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Restant',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${ue.montantRestant.toStringAsFixed(0)} FCFA',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'En attente d\'activation par l\'administration',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Volume horaire',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    Text(
                      '${ue.volumeHoraireTotal.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(Brutal.radiusSmall),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.inkMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) return AppColors.success;
    if (percentage >= 50) return AppColors.blue;
    if (percentage >= 30) return AppColors.warning;
    return AppColors.danger;
  }
}
