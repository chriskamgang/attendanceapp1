import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class HrAnalyticsScreen extends StatefulWidget {
  const HrAnalyticsScreen({super.key});

  @override
  State<HrAnalyticsScreen> createState() => _HrAnalyticsScreenState();
}

class _HrAnalyticsScreenState extends State<HrAnalyticsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _dashboard;
  List<dynamic> _trends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _apiService.getHrDashboard(),
      _apiService.getHrTrends(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (results[0]['success']) _dashboard = results[0]['dashboard'];
        if (results[1]['success']) _trends = results[1]['trends'];
      });
    }
  }

  String _formatNumber(dynamic val) {
    if (val == null) return '0';
    if (val is num) {
      return val.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ',
      );
    }
    return val.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord RH'),
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Workforce section
                    _buildSectionTitle('Effectifs'),
                    _buildWorkforceSection(),
                    const SizedBox(height: 16),

                    // Attendance today
                    _buildSectionTitle('Presence aujourd\'hui'),
                    _buildAttendanceSection(),
                    const SizedBox(height: 16),

                    // Monthly stats
                    _buildSectionTitle('Ce mois-ci'),
                    _buildMonthlySection(),
                    const SizedBox(height: 16),

                    // Training & Recruitment
                    _buildSectionTitle('Formation & Recrutement'),
                    _buildTrainingRecruitmentSection(),
                    const SizedBox(height: 16),

                    // Trends
                    if (_trends.isNotEmpty) ...[
                      _buildSectionTitle('Tendances (${_trends.length} mois)'),
                      _buildTrendsSection(),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildWorkforceSection() {
    final workforce = _dashboard?['workforce'];
    if (workforce == null) return const SizedBox.shrink();

    final byType = workforce['by_type'] as Map<String, dynamic>? ?? {};
    final byDept = workforce['by_department'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        // Total employees big card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF263238)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text('Total employes', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text(_formatNumber(workforce['total']), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // By type
        if (byType.isNotEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Par type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...byType.entries.map((e) => _barRow(e.key, e.value, workforce['total'] ?? 1, Colors.blue)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),

        // By department
        if (byDept.isNotEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Par departement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...byDept.entries.map((e) => _barRow(e.key, e.value, workforce['total'] ?? 1, Colors.purple)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _barRow(String label, dynamic value, dynamic total, Color color) {
    final num v = value is num ? value : 0;
    final num t = total is num ? total : 1;
    final ratio = t > 0 ? v / t : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: ratio.toDouble(), backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation(color), minHeight: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text('$v', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection() {
    final att = _dashboard?['attendance_today'];
    if (att == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(child: _statCard('Presents', '${att['present']}', Icons.check_circle, Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Total', '${att['total']}', Icons.people, Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Taux', '${att['rate']}%', Icons.trending_up, att['rate'] > 80 ? Colors.green : Colors.orange)),
      ],
    );
  }

  Widget _buildMonthlySection() {
    final monthly = _dashboard?['monthly'];
    if (monthly == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(child: _statCard('Retards', '${monthly['late_count']}', Icons.access_time, Colors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Absences', '${monthly['absence_count']}', Icons.event_busy, Colors.red)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('En conge', '${monthly['active_leaves']}', Icons.beach_access, Colors.teal)),
      ],
    );
  }

  Widget _buildTrainingRecruitmentSection() {
    final training = _dashboard?['training'];
    final recruitment = _dashboard?['recruitment'];

    return Row(
      children: [
        Expanded(child: _statCard('Formations actives', '${training?['active_enrollments'] ?? 0}', Icons.school, const Color(0xFF0D47A1))),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Postes ouverts', '${recruitment?['open_positions'] ?? 0}', Icons.work, const Color(0xFFE65100))),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Candidatures', '${recruitment?['applications_this_month'] ?? 0}', Icons.person_add, Colors.purple)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Header row
            Row(
              children: [
                const SizedBox(width: 60, child: Text('Periode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                const Expanded(child: Text('Effectif', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                const Expanded(child: Text('Presence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                const Expanded(child: Text('Retards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                const Expanded(child: Text('Turnover', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
              ],
            ),
            const Divider(),
            ..._trends.map((t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 60, child: Text(t['period'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
                  Expanded(child: Text('${t['total_employees']}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(child: Text('${t['avg_attendance_rate']}%', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(child: Text('${t['avg_late_rate']}%', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(child: Text('${t['turnover_rate']}%', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
