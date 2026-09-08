import 'package:flutter/material.dart';

import '../../shared/rh_ui.dart';
import '../leaves/leaves_screen.dart';
import '../absences/absences_screen.dart';
import '../certificates/certificates_screen.dart';
import '../payslips/payslip_history_screen.dart';
import '../messaging/conversations_screen.dart';
import '../profile/salary_advance_screen.dart';
import '../profile/wallet_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../evaluations/evaluations_screen.dart';
import '../cnps/cnps_screen.dart';
import '../orgchart/orgchart_screen.dart';
import '../training/training_screen.dart';
import '../analytics/hr_analytics_screen.dart';
import '../tickets/tickets_screen.dart';
import '../bus/bus_home_screen.dart';

class RhServicesScreen extends StatelessWidget {
  const RhServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Onglet, non écran empilé : le bandeau ne porte pas de retour.
      appBar: const RhAppBar(titre: 'Services RH'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Gestion
            _buildSectionTitle('Gestion du personnel'),
            const SizedBox(height: 10),
            _buildGrid(context, [
              _ServiceItem(
                icon: Icons.event_note_rounded,
                label: 'Conges',
                color: const Color(0xFF5C6BC0),
                onTap: () => _navigate(context, const LeavesScreen()),
              ),
              _ServiceItem(
                icon: Icons.warning_amber_rounded,
                label: 'Absences\n& Retards',
                color: const Color(0xFFE53935),
                onTap: () => _navigate(context, const AbsencesScreen()),
              ),
              _ServiceItem(
                icon: Icons.description_outlined,
                label: 'Attestations',
                color: const Color(0xFF00897B),
                onTap: () => _navigate(context, const CertificatesScreen()),
              ),
              _ServiceItem(
                icon: Icons.receipt_long_rounded,
                label: 'Fiches\nde Paie',
                color: const Color(0xFF7B1FA2),
                onTap: () => _navigate(context, const PayslipHistoryScreen()),
              ),
            ]),

            const SizedBox(height: 24),

            // Section Finance
            _buildSectionTitle('Finance'),
            const SizedBox(height: 10),
            _buildGrid(context, [
              _ServiceItem(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Portefeuille',
                color: AppColors.blueDark,
                onTap: () => _navigate(context, const WalletScreen()),
              ),
              _ServiceItem(
                icon: Icons.money_rounded,
                label: 'Avance\nsur salaire',
                color: const Color(0xFF00695C),
                onTap: () => _navigate(context, const SalaryAdvanceScreen()),
              ),
              _ServiceItem(
                icon: Icons.shield_outlined,
                label: 'CNPS',
                color: const Color(0xFF2E7D32),
                onTap: () => _navigate(context, const CnpsScreen()),
              ),
            ]),

            const SizedBox(height: 24),

            // Section Carriere
            _buildSectionTitle('Carriere & Developpement'),
            const SizedBox(height: 10),
            _buildGrid(context, [
              _ServiceItem(
                icon: Icons.star_border_rounded,
                label: 'Evaluations',
                color: const Color(0xFFF57F17),
                onTap: () => _navigate(context, const EvaluationsScreen()),
              ),
              _ServiceItem(
                icon: Icons.school_rounded,
                label: 'Formations',
                color: const Color(0xFF6A1B9A),
                onTap: () => _navigate(context, const TrainingScreen()),
              ),
              _ServiceItem(
                icon: Icons.account_tree_rounded,
                label: 'Organigramme',
                color: const Color(0xFF00838F),
                onTap: () => _navigate(context, const OrgChartScreen()),
              ),
              _ServiceItem(
                icon: Icons.bar_chart_rounded,
                label: 'Analytique\nRH',
                color: const Color(0xFFD84315),
                onTap: () => _navigate(context, const HrAnalyticsScreen()),
              ),
            ]),

            const SizedBox(height: 24),

            // Section Transport
            _buildSectionTitle('Transport'),
            const SizedBox(height: 10),
            _buildGrid(context, [
              _ServiceItem(
                icon: Icons.directions_bus_rounded,
                label: 'Bus INSAM',
                color: AppColors.blue,
                onTap: () => _navigate(context, const BusHomeScreen()),
              ),
            ]),

            const SizedBox(height: 24),

            // Section Communication
            _buildSectionTitle('Communication'),
            const SizedBox(height: 10),
            _buildGrid(context, [
              _ServiceItem(
                icon: Icons.confirmation_number_rounded,
                label: 'Tickets',
                color: AppColors.blueDark,
                onTap: () => _navigate(context, const TicketsScreen()),
              ),
              _ServiceItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Messagerie',
                color: const Color(0xFF0277BD),
                onTap: () => _navigate(context, const ConversationsScreen()),
              ),
              _ServiceItem(
                icon: Icons.person_outline_rounded,
                label: 'Mon Profil',
                color: const Color(0xFF455A64),
                onTap: () => _navigate(context, const EditProfileScreen()),
              ),
            ]),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => RhSectionTitle(title);

  Widget _buildGrid(BuildContext context, List<_ServiceItem> items) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      // Les tuiles encadrées portent une ombre : un rapport plus haut leur
      // laisse la place sans rogner les libellés sur deux lignes.
      childAspectRatio: 1.35,
      children: items.map((item) => _buildCard(context, item)).toList(),
    );
  }

  Widget _buildCard(BuildContext context, _ServiceItem item) {
    return RhServiceTile(
      titre: item.label,
      icone: item.icon,
      accent: item.color,
      onTap: item.onTap,
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _ServiceItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ServiceItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
