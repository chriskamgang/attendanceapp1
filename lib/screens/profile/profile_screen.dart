import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
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

  static const Color _primaryDark = Color(0xFF1A237E);
  static const Color _primaryMid = Color(0xFF283593);
  static const Color _primaryLight = Color(0xFF3949AB);
  static const Color _surfaceGrey = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadSalaryStatus();
  }

  Future<void> _loadSalaryStatus() async {
    setState(() => _isLoading = true);

    try {
      final result = await _apiService.getSalaryStatus(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );

      if (result['success'] && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        // Ensure required keys exist with defaults
        data['salary'] ??= {
          'gross_salary': 0, 'net_salary': 0, 'total_deductions': 0,
          'hourly_rate': 0, 'hours_worked': 0,
        };
        data['attendance'] ??= {
          'working_days': 0, 'days_worked': 0, 'days_not_worked': 0,
          'days_justified': 0, 'scheduled_days': 0, 'days_missed': 0,
        };
        data['lateness'] ??= {'total_late_minutes': 0};
        data['deductions'] ??= {
          'late_penalty_amount': 0, 'absence_deduction': 0,
          'manual_deductions': 0, 'loan_deductions': 0,
        };
        setState(() {
          _salaryStatus = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _salaryStatus = null;
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Erreur lors du chargement des données')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _salaryStatus = null;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
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
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
      _loadSalaryStatus();
    }
  }

  bool _isDownloading = false;

  Future<void> _downloadPayslip() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final token = await StorageService().getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expirée, veuillez vous reconnecter')),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final fileName = 'fiche-paie-${_selectedMonth.month}-${_selectedMonth.year}.pdf';
      final filePath = '${dir.path}/$fileName';

      final dio = Dio();
      final url = '${ApiConstants.baseUrl}/user/payslip?month=${_selectedMonth.month}&year=${_selectedMonth.year}';

      await dio.download(
        url,
        filePath,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/pdf',
          },
        ),
      );

      if (!mounted) return;

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le fichier: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléchargement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  bool get _isVacataire => _salaryStatus?['is_vacataire'] == true;

  String _formatCurrency(dynamic value) {
    if (value == null) return '0 FCFA';
    final number = value is String ? double.tryParse(value) ?? 0 : value.toDouble();
    return '${NumberFormat('#,##0', 'fr_FR').format(number)} FCFA';
  }

  String _formatHours(dynamic value) {
    if (value == null) return '0h';
    final hours = value is String ? double.tryParse(value) ?? 0 : value.toDouble();
    if (hours == hours.roundToDouble()) return '${hours.toInt()}h';
    return '${hours.toStringAsFixed(1)}h';
  }

  String _getEmployeeTypeLabel(String? type) {
    switch (type) {
      case 'enseignant_titulaire': return 'Personnel Permanent';
      case 'semi_permanent': return 'Semi-Permanent';
      case 'enseignant_vacataire': return 'Vacataire';
      case 'administratif': return 'Administratif';
      case 'technique': return 'Technique';
      case 'direction': return 'Direction';
      default: return type ?? 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: _surfaceGrey,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryDark))
          : RefreshIndicator(
              color: _primaryDark,
              onRefresh: _loadSalaryStatus,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildSliverHeader(user),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Net salary highlight card
                        _buildNetSalaryCard(),

                        const SizedBox(height: 16),
                        // Month selector
                        _buildMonthSelector(),
                        const SizedBox(height: 12),

                        // Download payslip button
                        _buildDownloadPayslipButton(),
                        const SizedBox(height: 16),

                        if (_salaryStatus != null) ...[
                          // Salary breakdown
                          _isVacataire
                              ? _buildVacataireSalaryBreakdown()
                              : _buildSalaryBreakdown(),
                          const SizedBox(height: 16),

                          // Attendance
                          _isVacataire
                              ? _buildVacataireAttendance()
                              : _buildAttendance(),
                          const SizedBox(height: 16),

                          // Deductions
                          _buildDeductions(),

                          // UE Breakdown (détail par UE) for vacataires
                          if (_isVacataire && _salaryStatus!['ue_breakdown'] != null &&
                              (_salaryStatus!['ue_breakdown'] as List).isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildUEBreakdown(),
                          ],

                          // UE Summary for vacataires
                          if (_isVacataire && _salaryStatus!['ue_summary'] != null) ...[
                            const SizedBox(height: 16),
                            _buildUESummary(),
                          ],

                          const SizedBox(height: 16),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ===== SLIVER HEADER =====
  Widget _buildSliverHeader(user) {
    return SliverAppBar(
      expandedHeight: 260,
      floating: false,
      pinned: true,
      backgroundColor: _primaryDark,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          onPressed: _loadSalaryStatus,
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white70),
          onPressed: _logout,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryDark, _primaryMid, _primaryLight],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 46),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        user?.firstName?.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user?.fullName ?? 'Utilisateur',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getEmployeeTypeLabel(user?.employeeType),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
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

  // ===== NET SALARY HIGHLIGHT =====
  Widget _buildNetSalaryCard() {
    if (_salaryStatus == null) return const SizedBox.shrink();
    final salary = _salaryStatus!['salary'];
    final netSalary = salary['net_salary'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              _isVacataire ? 'Net à Percevoir' : 'Salaire Net Estimé',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatCurrency(netSalary),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: netSalary > 0 ? Colors.green[700] : Colors.grey[400],
              ),
            ),
            if (_isVacataire) ...[
              const SizedBox(height: 4),
              Text(
                '${_formatHours(salary['hours_worked'])} x ${_formatCurrency(salary['hourly_rate'])}/h',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===== MONTH SELECTOR =====
  Widget _buildMonthSelector() {
    return GestureDetector(
      onTap: _selectMonth,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _primaryDark.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_month_rounded, color: _primaryDark, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy', 'fr_FR').format(_selectedMonth),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // ===== DOWNLOAD PAYSLIP BUTTON =====
  Widget _buildDownloadPayslipButton() {
    return GestureDetector(
      onTap: _isDownloading ? null : _downloadPayslip,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primaryDark, _primaryLight],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _primaryDark.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isDownloading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              _isDownloading ? 'Téléchargement...' : 'Télécharger la Fiche de Paie',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== VACATAIRE SALARY BREAKDOWN =====
  Widget _buildVacataireSalaryBreakdown() {
    final salary = _salaryStatus!['salary'];
    final lateness = _salaryStatus!['lateness'];

    return _buildSection(
      title: 'Rémunération',
      icon: Icons.payments_rounded,
      iconColor: const Color(0xFF2E7D32),
      children: [
        _buildBreakdownRow('Taux Horaire', _formatCurrency(salary['hourly_rate']), const Color(0xFF1565C0)),
        _buildBreakdownRow('Heures Travaillées', _formatHours(salary['hours_worked']), const Color(0xFF00897B)),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1),
        ),
        _buildBreakdownRow('Montant Brut', _formatCurrency(salary['gross_salary']), Colors.grey[700]!),
        _buildBreakdownRow('Déductions', '-${_formatCurrency(salary['total_deductions'])}', Colors.red[600]!),
      ],
    );
  }

  // ===== STANDARD SALARY BREAKDOWN =====
  Widget _buildSalaryBreakdown() {
    final salary = _salaryStatus!['salary'];
    final attendance = _salaryStatus!['attendance'];
    final lateness = _salaryStatus!['lateness'];

    final totalHours = attendance['total_hours_worked'] ?? 0;
    final hoursDisplay = totalHours is num ? '${totalHours.toStringAsFixed(1)}h' : '${totalHours}h';

    return _buildSection(
      title: 'État du Salaire',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: const Color(0xFF2E7D32),
      children: [
        _buildBreakdownRow('Salaire Brut', _formatCurrency(salary['gross_salary']), Colors.grey[700]!),
        _buildBreakdownRow('Heures Travaillées', hoursDisplay, const Color(0xFF00897B)),
        _buildBreakdownRow('Jours Travaillés', '${(attendance['days_worked'] is num ? (attendance['days_worked'] as num).toStringAsFixed(2) : attendance['days_worked'])} jours', const Color(0xFF1565C0)),
        _buildBreakdownRow('Retards', '${lateness['total_late_minutes']} min', Colors.orange[700]!),
        _buildBreakdownRow('Déductions', '-${_formatCurrency(salary['total_deductions'])}', Colors.red[600]!),
      ],
    );
  }

  // ===== VACATAIRE ATTENDANCE =====
  Widget _buildVacataireAttendance() {
    final attendance = _salaryStatus!['attendance'];
    final salary = _salaryStatus!['salary'];

    return _buildSection(
      title: 'Présence (Emploi du Temps)',
      icon: Icons.event_note_rounded,
      iconColor: const Color(0xFF1565C0),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                '${attendance['scheduled_days'] ?? attendance['working_days']}',
                'Programmés',
                Icons.event_note_rounded,
                const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStat(
                '${attendance['days_worked']}',
                'Travaillés',
                Icons.check_circle_rounded,
                const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStat(
                '${attendance['days_missed'] ?? attendance['days_not_worked']}',
                'Manqués',
                Icons.cancel_rounded,
                const Color(0xFFD32F2F),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStat(
                _formatHours(salary['hours_worked']),
                'Heures',
                Icons.access_time_filled_rounded,
                const Color(0xFF00897B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===== STANDARD ATTENDANCE =====
  Widget _buildAttendance() {
    final attendance = _salaryStatus!['attendance'];
    final totalHours = attendance['total_hours_worked'] ?? 0;
    final hoursStr = totalHours is num ? totalHours.toStringAsFixed(1) : '$totalHours';
    final daysWorked = attendance['days_worked'];
    final daysStr = daysWorked is num ? daysWorked.toStringAsFixed(1) : '$daysWorked';

    return _buildSection(
      title: 'Statistiques de Présence',
      icon: Icons.bar_chart_rounded,
      iconColor: const Color(0xFF1565C0),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                '${attendance['working_days']}',
                'Ouvrables',
                Icons.date_range_rounded,
                const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStat(
                '${hoursStr}h',
                'Heures',
                Icons.access_time_filled_rounded,
                const Color(0xFF00897B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStat(
                daysStr,
                'Jours',
                Icons.check_circle_rounded,
                const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStat(
                '${attendance['days_justified']}',
                'Justifiées',
                Icons.verified_rounded,
                const Color(0xFFF57C00),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===== DEDUCTIONS =====
  Widget _buildDeductions() {
    final deductions = _salaryStatus!['deductions'];
    final lateness = _salaryStatus!['lateness'];

    return _buildSection(
      title: 'Détail des Déductions',
      icon: Icons.receipt_long_rounded,
      iconColor: const Color(0xFFD32F2F),
      children: [
        if (!_isVacataire) ...[
          _buildDeductionTile(
            'Retards',
            '${lateness['total_late_minutes']} min',
            deductions['late_penalty_amount'],
            Icons.schedule_rounded,
            const Color(0xFFF57C00),
          ),
        ],
        if (!_isVacataire) ...[
          const SizedBox(height: 8),
          _buildDeductionTile(
            'Absences',
            '${(_salaryStatus!['attendance']['days_not_worked'] ?? 0) - (_salaryStatus!['attendance']['days_justified'] ?? 0)} jours',
            deductions['absence_deduction'] ?? 0,
            Icons.cancel_rounded,
            const Color(0xFFD32F2F),
          ),
        ],
        const SizedBox(height: 8),
        _buildDeductionTile(
          'Déductions Manuelles',
          null,
          deductions['manual_deductions'],
          Icons.edit_note_rounded,
          const Color(0xFF7B1FA2),
        ),
        const SizedBox(height: 8),
        _buildDeductionTile(
          'Remboursement Prêts',
          null,
          deductions['loan_deductions'] ?? 0,
          Icons.account_balance_rounded,
          const Color(0xFF283593),
        ),

        // Manual deduction details
        if (deductions['manual_deductions_details'] != null &&
            (deductions['manual_deductions_details'] as List).isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Détails Déductions Manuelles',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 8),
          ...(deductions['manual_deductions_details'] as List).map(
            (detail) => _buildManualDeductionDetail(detail),
          ),
        ],

        // Loan details
        if (deductions['loan_deductions_details'] != null &&
            (deductions['loan_deductions_details'] as List).isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Détails Prêts en Cours',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 8),
          ...(deductions['loan_deductions_details'] as List).map(
            (loan) => _buildLoanDetail(loan),
          ),
        ],
      ],
    );
  }

  // ===== UE BREAKDOWN (Détail par UE avec taux) =====
  Widget _buildUEBreakdown() {
    final ueBreakdown = _salaryStatus!['ue_breakdown'] as List;
    if (ueBreakdown.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      title: 'Détail par UE',
      icon: Icons.receipt_long_rounded,
      iconColor: const Color(0xFF1565C0),
      children: [
        ...ueBreakdown.map((ue) {
          final niveau = ue['niveau'] ?? '';
          final taux = ue['taux_horaire'] ?? 0;
          final heures = ue['heures'] ?? 0;
          final montant = ue['montant'] ?? 0;
          final nomMatiere = ue['nom_matiere'] ?? 'N/A';
          final codeUe = ue['code_ue'];

          // Couleur selon le niveau
          final Color niveauColor;
          if (niveau.toString().toLowerCase().contains('licence')) {
            niveauColor = const Color(0xFF1565C0);
          } else if (niveau.toString().toLowerCase().contains('master')) {
            niveauColor = const Color(0xFF7B1FA2);
          } else {
            niveauColor = const Color(0xFF00897B);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: niveauColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: niveauColor.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: niveauColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        niveau.toString().isNotEmpty ? niveau.toString() : 'BTS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: niveauColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        codeUe != null ? '$codeUe - $nomMatiere' : nomMatiere,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Taux: ${_formatCurrency(taux)}/h',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      '${_formatHours(heures)} travaillées',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(montant),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: niveauColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        // Total
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total: ${_formatHours(ueBreakdown.fold<double>(0, (sum, ue) => sum + ((ue['heures'] ?? 0) is num ? (ue['heures'] as num).toDouble() : 0)))}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              _formatCurrency(ueBreakdown.fold<double>(0, (sum, ue) => sum + ((ue['montant'] ?? 0) is num ? (ue['montant'] as num).toDouble() : 0))),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===== UE SUMMARY =====
  Widget _buildUESummary() {
    final ueSummary = _salaryStatus!['ue_summary'] as List;
    if (ueSummary.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      title: 'UE Programmées',
      icon: Icons.school_rounded,
      iconColor: const Color(0xFF283593),
      children: [
        ...ueSummary.map((ue) {
          final jours = (ue['jours'] as List).join(', ');
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF283593).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF283593).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${ue['creneaux_par_semaine']}x',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF283593),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ue['code_ue']} - ${ue['nom_matiere']}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(jours, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ===== REUSABLE COMPONENTS =====

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionTile(String label, String? subtitle, dynamic amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Text(
            '- ${_formatCurrency(amount)}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
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
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(10),
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
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _formatCurrency(detail['amount']),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red[700]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Par ${detail['applied_by']} le ${detail['applied_at']}',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prêt de ${_formatCurrency(totalAmount)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Mensualité: ${_formatCurrency(monthlyAmount)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF283593).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_formatCurrency(deductionThisMonth)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF283593)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payé: ${_formatCurrency(amountPaid)}',
                  style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w600)),
              Text('Reste: ${_formatCurrency(remainingAmount)}',
                  style: TextStyle(fontSize: 10, color: Colors.orange[700], fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[500]!),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text('${progress.toStringAsFixed(1)}% remboursé',
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),

          if (loan['reason'] != null && loan['reason'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Motif: ${loan['reason']}',
                style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
