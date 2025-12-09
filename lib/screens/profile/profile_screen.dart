import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _salaryStatus;
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSalaryStatus();
  }

  Future<void> _loadSalaryStatus() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _apiService.getSalaryStatus(
      month: _selectedMonth.month,
      year: _selectedMonth.year,
    );

    if (result['success']) {
      setState(() {
        _salaryStatus = result['data'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du chargement des données')),
        );
      }
    }
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      locale: const Locale('fr', 'FR'),
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadSalaryStatus();
    }
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0 FCFA';
    final number = value is String ? double.tryParse(value) ?? 0 : value.toDouble();
    return '${NumberFormat('#,##0', 'fr_FR').format(number)} FCFA';
  }

  String _getEmployeeTypeLabel(String? type) {
    switch (type) {
      case 'enseignant_titulaire':
        return 'Personnel Permanent';
      case 'semi_permanent':
        return 'Personnel Semi-Permanent';
      case 'enseignant_vacataire':
        return 'Vacataire';
      default:
        return type ?? 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSalaryStatus,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSalaryStatus,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête utilisateur
                    _buildUserHeader(user),
                    const SizedBox(height: 24),

                    // Sélecteur de mois
                    _buildMonthSelector(),
                    const SizedBox(height: 24),

                    // Salaire
                    if (_salaryStatus != null) ...[
                      _buildSalarySummary(),
                      const SizedBox(height: 24),
                      _buildAttendanceStats(),
                      const SizedBox(height: 24),
                      _buildDeductionsSection(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserHeader(user) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue,
              child: Text(
                user?.firstName?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.fullName ?? 'Utilisateur',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getEmployeeTypeLabel(user?.employeeType),
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user?.email ?? '',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return InkWell(
      onTap: _selectMonth,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMMM yyyy', 'fr_FR').format(_selectedMonth),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            Icon(Icons.arrow_drop_down, color: Colors.blue[700]),
          ],
        ),
      ),
    );
  }

  Widget _buildSalarySummary() {
    final salary = _salaryStatus!['salary'];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'État du Salaire',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            _buildSalaryRow('Salaire Brut', salary['gross_salary'], Colors.grey[700]!),
            const SizedBox(height: 12),
            _buildSalaryRow('Total Déductions', salary['total_deductions'], Colors.red[700]!, isNegative: true),
            const Divider(height: 24),
            _buildSalaryRow('Salaire Net Estimé', salary['net_salary'], Colors.green[700]!, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryRow(String label, dynamic value, Color color, {bool isNegative = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.grey[700],
          ),
        ),
        Text(
          '${isNegative ? "-" : ""}${_formatCurrency(value)}',
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceStats() {
    final attendance = _salaryStatus!['attendance'];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Statistiques de Présence',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Jours Ouvrables',
                    '${attendance['working_days']}',
                    Icons.date_range,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Jours Travaillés',
                    '${attendance['days_worked']}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Absences',
                    '${attendance['days_not_worked']}',
                    Icons.cancel,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Justifiées',
                    '${attendance['days_justified']}',
                    Icons.verified,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionsSection() {
    final deductions = _salaryStatus!['deductions'];
    final lateness = _salaryStatus!['lateness'];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.remove_circle, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text(
                  'Détail des Déductions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Retards
            _buildDeductionRow(
              'Retards',
              '${lateness['total_late_minutes']} min',
              deductions['late_penalty_amount'],
              Colors.orange,
              Icons.schedule,
            ),
            const SizedBox(height: 12),

            // Absences
            _buildDeductionRow(
              'Absences',
              '${_salaryStatus!['attendance']['days_not_worked'] - _salaryStatus!['attendance']['days_justified']} jours',
              deductions['absence_deduction'],
              Colors.red,
              Icons.cancel,
            ),
            const SizedBox(height: 12),

            // Déductions manuelles
            _buildDeductionRow(
              'Déductions Manuelles',
              null,
              deductions['manual_deductions'],
              Colors.purple,
              Icons.warning,
            ),
            const SizedBox(height: 12),

            // Remboursement Prêts
            _buildDeductionRow(
              'Remboursement Prêts',
              null,
              _salaryStatus!['deductions']['loan_deductions'] ?? 0,
              Colors.indigo,
              Icons.account_balance,
            ),

            // Détails des déductions manuelles
            if (deductions['manual_deductions_details'] != null &&
                (deductions['manual_deductions_details'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Détails Déductions Manuelles:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ...(deductions['manual_deductions_details'] as List).map(
                (detail) => _buildManualDeductionDetail(detail),
              ),
            ],

            // Détails des prêts
            if (deductions['loan_deductions_details'] != null &&
                (deductions['loan_deductions_details'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Détails Prêts en Cours:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ...(deductions['loan_deductions_details'] as List).map(
                (loan) => _buildLoanDetail(loan),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeductionRow(String label, String? subtitle, dynamic amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '- ${_formatCurrency(amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualDeductionDetail(Map<String, dynamic> detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  detail['reason'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _formatCurrency(detail['amount']),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Appliqué par: ${detail['applied_by']} le ${detail['applied_at']}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanDetail(Map<String, dynamic> loan) {
    final totalAmount = loan['total_amount'] ?? 0;
    final amountPaid = loan['amount_paid'] ?? 0;
    final remainingAmount = loan['remaining_amount'] ?? 0;
    final monthlyAmount = loan['monthly_amount'] ?? 0;
    final deductionThisMonth = loan['deduction_this_month'] ?? 0;
    final progress = totalAmount > 0 ? (amountPaid / totalAmount) * 100 : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Montant total et mensualité
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prêt de ${_formatCurrency(totalAmount)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Mensualité: ${_formatCurrency(monthlyAmount)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Ce mois: ${_formatCurrency(deductionThisMonth)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barre de progression
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Déjà payé: ${_formatCurrency(amountPaid)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Reste: ${_formatCurrency(remainingAmount)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${progress.toStringAsFixed(1)}% remboursé',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          // Motif si disponible
          if (loan['reason'] != null && loan['reason'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Motif: ${loan['reason']}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
