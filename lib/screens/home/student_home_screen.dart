import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/campus.dart';
import '../../services/api_service.dart';
import '../attendance/check_in_screen.dart';
import '../schedule/schedule_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final ApiService _apiService = ApiService();
  List<Campus> _campuses = [];
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  List<Map<String, dynamic>> _todaySchedule = [];

  static const Color _primaryDark = Color(0xFF0D47A1);
  static const Color _accentBlue = Color(0xFF1976D2);
  static const Color _surfaceGrey = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);

    try {
      final results = await Future.wait([
        _apiService.getMyCampuses(),
        _apiService.getDashboard(),
        _apiService.getTodaySchedule(),
        attendanceProvider.checkCurrentStatus().then((_) => {'success': true}),
      ]);

      if (results[0]['success'] == true) {
        _campuses = results[0]['campuses'];
      }
      if (results[1]['success'] == true) {
        _dashboardData = results[1]['data'];
      }
      if (results[2]['success'] == true) {
        _todaySchedule = List<Map<String, dynamic>>.from(results[2]['data'] ?? []);
      }
    } catch (e) {
      print('Erreur chargement données étudiant: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: _surfaceGrey,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryDark))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildHeader(user),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildCheckInStatus(attendanceProvider),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionTitle('Emploi du temps d\'aujourd\'hui', Icons.calendar_today),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ScheduleScreen()),
                              ),
                              child: const Text('Voir tout'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildScheduleSection(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Statistiques du mois', Icons.analytics_outlined),
                        const SizedBox(height: 12),
                        _buildMonthStats(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Mes Campus', Icons.location_on),
                        const SizedBox(height: 12),
                        if (_campuses.isEmpty)
                          _buildEmptyState(Icons.location_off, 'Aucun campus assigné')
                        else
                          ..._campuses.map((c) => _buildCampusCard(c)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(user) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: _primaryDark,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryDark, _accentBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Bonjour, ${user?.firstName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user?.specialite ?? "Étudiant"} • ${user?.niveau ?? ""}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadData,
        ),
      ],
    );
  }

  Widget _buildCheckInStatus(AttendanceProvider provider) {
    final hasCheckIn = provider.hasActiveCheckIn;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (hasCheckIn ? Colors.green : Colors.orange).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasCheckIn ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: hasCheckIn ? Colors.green : Colors.orange,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCheckIn ? 'Présence validée' : 'Pointage requis',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      hasCheckIn 
                          ? 'Vous êtes actuellement en cours' 
                          : 'Pensez à pointer votre arrivée sur le campus',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!hasCheckIn && _campuses.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CheckInScreen(campus: _campuses.first)),
                ).then((_) => _loadData()),
                icon: const Icon(Icons.location_on, size: 18),
                label: const Text(
                  'Pointer ma présence',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    if (_todaySchedule.isEmpty) {
      return _buildEmptyState(Icons.event_busy, 'Aucun cours prévu aujourd\'hui');
    }

    return Column(
      children: _todaySchedule.map((s) => _buildScheduleCard(s)).toList(),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final ue = schedule['ue'];
    final campus = schedule['campus'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 6,
              decoration: const BoxDecoration(
                color: _accentBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${schedule['heure_debut']} - ${schedule['heure_fin']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _primaryDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            schedule['salle'] ?? 'N/A',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ue['nom_matiere'] ?? 'Matière inconnue',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          campus['name'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthStats() {
    if (_dashboardData == null || _dashboardData!['month_stats'] == null) {
      return const SizedBox.shrink();
    }
    
    final stats = _dashboardData!['month_stats'];
    return Row(
      children: [
        _buildMiniStatCard('Présences', '${stats['total_check_ins']}', Colors.green),
        const SizedBox(width: 10),
        _buildMiniStatCard('Retards', '${stats['total_late']}', Colors.orange),
        const SizedBox(width: 10),
        _buildMiniStatCard('Jours', '${stats['days_worked']}', Colors.blue),
      ],
    );
  }

  Widget _buildMiniStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primaryDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCampusCard(Campus campus) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryDark.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.location_city, color: _primaryDark, size: 20),
        ),
        title: Text(
          campus.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          campus.address,
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CheckInScreen(campus: campus)),
        ).then((_) => _loadData()),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
