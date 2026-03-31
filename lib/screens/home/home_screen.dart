import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/campus.dart';
import '../../models/unite_enseignement.dart';
import '../../services/api_service.dart';
import '../../models/task.dart';
import '../../services/location_service.dart';
import '../../widgets/unite_enseignement_card.dart';
import '../../models/ue_schedule.dart';
import '../attendance/check_in_screen.dart';
import '../schedule/schedule_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _dashboardData;
  List<Campus> _campuses = [];
  List<UniteEnseignement> _unitesActivees = [];
  List<UniteEnseignement> _unitesNonActivees = [];
  Map<String, dynamic>? _ueStats;
  bool _isLoading = true;
  List<Map<String, dynamic>> _todaySchedule = [];
  bool _isOnBreak = false;
  String? _breakStartTime;
  int _breakElapsedMinutes = 0;
  bool _breakLoading = false;
  List<Task> _myTasks = [];

  // Couleurs du thème
  static const Color _primaryDark = Color(0xFF1A237E);
  static const Color _primaryMid = Color(0xFF283593);
  static const Color _primaryLight = Color(0xFF3949AB);
  static const Color _accentBlue = Color(0xFF42A5F5);
  static const Color _surfaceGrey = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    final dashResult = await _apiService.getDashboard();
    if (dashResult['success']) {
      _dashboardData = dashResult['data'];
    }

    final campusResult = await _apiService.getMyCampuses();
    if (campusResult['success']) {
      _campuses = campusResult['campuses'];
    }

    if (user != null && (user.isVacataire() || user.isSemiPermanent() || user.isTitulaire())) {
      final ueResult = await _apiService.getUnitesEnseignement();
      if (ueResult['success']) {
        final data = ueResult['data'];
        _unitesActivees = (data['unites_activees'] as List)
            .map((ue) => UniteEnseignement.fromJson(ue))
            .toList();
        _unitesNonActivees = (data['unites_non_activees'] as List)
            .map((ue) => UniteEnseignement.fromJson(ue))
            .toList();
        _ueStats = data['totaux'];
      }
    }

    if (user != null && (user.isVacataire() || user.isSemiPermanent() || user.isTitulaire())) {
      final scheduleResult = await _apiService.getTodaySchedule();
      if (scheduleResult['success']) {
        _todaySchedule = List<Map<String, dynamic>>.from(scheduleResult['data'] ?? []);
      }
    }

    // Charger les taches
    final tasksResult = await _apiService.getMyTasks();
    if (tasksResult['success']) {
      _myTasks = (tasksResult['data'] as List)
          .map((t) => Task.fromJson(t))
          .toList();
    }

    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);
    await attendanceProvider.checkCurrentStatus();

    // Charger le statut de pause
    final breakResult = await _apiService.getBreakStatus();
    if (breakResult['success'] == true) {
      final breakData = breakResult['data'];
      _isOnBreak = breakData['on_break'] ?? false;
      if (_isOnBreak && breakData['active_break'] != null) {
        _breakStartTime = breakData['active_break']['break_start'];
        _breakElapsedMinutes = breakData['active_break']['elapsed_minutes'] ?? 0;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  String _getEmployeeTypeLabel(String type) {
    switch (type) {
      case 'enseignant_vacataire':
        return 'Enseignant Vacataire';
      case 'semi_permanent':
        return 'Semi-Permanent';
      case 'enseignant_titulaire':
        return 'Enseignant Titulaire';
      case 'administratif':
        return 'Administratif';
      case 'technique':
        return 'Technique';
      case 'direction':
        return 'Direction';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: _surfaceGrey,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primaryDark),
            )
          : RefreshIndicator(
              color: _primaryDark,
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Header gradient
                  _buildSliverHeader(user),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Check-in status card
                        _buildCheckInStatus(attendanceProvider),
                        const SizedBox(height: 16),

                        // Boutons de pause (uniquement si check-in actif)
                        if (attendanceProvider.hasActiveCheckIn)
                          _buildBreakSection(user),
                        if (attendanceProvider.hasActiveCheckIn)
                          const SizedBox(height: 16),

                        // Vérifications en attente
                        if (_dashboardData != null &&
                            _dashboardData!['pending_presence_checks'] > 0) ...[
                          _buildPendingChecks(),
                          const SizedBox(height: 16),
                        ],

                        // Taches assignees
                        if (_myTasks.isNotEmpty) ...[
                          _buildTasksPreview(),
                          const SizedBox(height: 16),
                        ],

                        // Statistiques du mois
                        if (_dashboardData != null) ...[
                          _buildMonthStats(),
                          const SizedBox(height: 20),
                        ],

                        // Emploi du temps du jour
                        if (user != null && (user.isVacataire() || user.isSemiPermanent() || user.isTitulaire())) ...[
                          _buildTodayScheduleSection(),
                          const SizedBox(height: 20),
                        ],

                        // Section UE pour enseignants
                        if (user != null && (user.isVacataire() || user.isSemiPermanent() || user.isTitulaire())) ...[
                          _buildUESection(),
                          const SizedBox(height: 20),
                        ],

                        // Liste des campus
                        _buildCampusList(),
                        const SizedBox(height: 16),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSliverHeader(user) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: _primaryDark,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          onPressed: _loadData,
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
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 48),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting()},',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.fullName ?? 'Utilisateur',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user != null
                                ? _getEmployeeTypeLabel(user.employeeType)
                                : '',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildCheckInStatus(AttendanceProvider attendanceProvider) {
    final hasActive = attendanceProvider.hasActiveCheckIn;
    final activeCheckIns = attendanceProvider.activeCheckIns;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (hasActive ? Colors.green : Colors.orange).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hasActive
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                hasActive ? Icons.check_circle_rounded : Icons.access_time_rounded,
                color: hasActive ? Colors.green[600] : Colors.orange[600],
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasActive ? 'Check-in actif' : 'Pas de check-in actif',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: hasActive ? Colors.green[800] : Colors.orange[800],
                    ),
                  ),
                  if (hasActive && activeCheckIns.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...activeCheckIns.map((attendance) => Text(
                          '${attendance.campus?.name ?? 'Campus'} - ${attendance.getFormattedTime()}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        )),
                  ] else if (!hasActive) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Sélectionnez un campus pour pointer',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasActive ? Colors.green : Colors.orange[400],
                boxShadow: [
                  BoxShadow(
                    color: (hasActive ? Colors.green : Colors.orange).withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startBreak() async {
    setState(() => _breakLoading = true);
    try {
      // Récupérer la position GPS
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d\'obtenir votre position GPS.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _breakLoading = false);
        return;
      }

      final result = await _apiService.startBreak(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (result['success'] == true) {
        setState(() {
          _isOnBreak = true;
          _breakStartTime = result['data']?['break_start'];
          _breakElapsedMinutes = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pause commencée. Bon appétit !'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Erreur'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _breakLoading = false);
  }

  Future<void> _endBreak() async {
    setState(() => _breakLoading = true);
    try {
      // Récupérer la position GPS
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d\'obtenir votre position GPS.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _breakLoading = false);
        return;
      }

      final result = await _apiService.endBreak(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (result['success'] == true) {
        final duration = result['data']?['duration_minutes'] ?? 0;
        setState(() {
          _isOnBreak = false;
          _breakStartTime = null;
          _breakElapsedMinutes = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bon retour ! Pause de ${duration} minutes.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Erreur'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _breakLoading = false);
  }

  Widget _buildBreakSection(user) {
    // Pause uniquement pour le personnel permanent (pas les vacataires)
    if (user == null || !['semi_permanent', 'enseignant_titulaire', 'administratif', 'technique', 'direction'].contains(user.employeeType)) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isOnBreak ? Colors.orange : Colors.brown).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isOnBreak
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.brown.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isOnBreak ? Icons.timer_rounded : Icons.restaurant_rounded,
                    color: _isOnBreak ? Colors.orange[700] : Colors.brown[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOnBreak ? 'En pause' : 'Pause déjeuner',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _isOnBreak ? Colors.orange[800] : Colors.brown[800],
                        ),
                      ),
                      if (_isOnBreak && _breakStartTime != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Depuis $_breakStartTime',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _breakLoading ? null : (_isOnBreak ? _endBreak : _startBreak),
                icon: _breakLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        _isOnBreak ? Icons.arrow_back_rounded : Icons.coffee_rounded,
                        size: 20,
                      ),
                label: Text(
                  _isOnBreak ? 'Retour de pause' : 'Prendre ma pause',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOnBreak ? Colors.green[600] : Colors.orange[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingChecks() {
    final count = _dashboardData!['pending_presence_checks'];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[600]!, Colors.red[400]!],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vérifications en attente',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$count vérification${count > 1 ? 's' : ''} à traiter',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTasksPreview() {
    final pendingTasks = _myTasks.where((t) => t.myStatus != 'completed').take(3).toList();
    if (pendingTasks.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryDark.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.task_alt, color: _primaryDark, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Mes Taches',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_myTasks.where((t) => t.myStatus != "completed").length} en cours',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...pendingTasks.map((task) => _buildTaskPreviewItem(task)),
        ],
      ),
    );
  }

  Widget _buildTaskPreviewItem(Task task) {
    Color priorityColor;
    switch (task.priority) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      default:
        priorityColor = Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      task.myStatusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: task.myStatus == 'in_progress' ? Colors.blue : Colors.grey[600],
                      ),
                    ),
                    if (task.dueDate != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.calendar_today,
                        size: 11,
                        color: task.isOverdue ? Colors.red : Colors.grey[500],
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${task.dueDate!.day}/${task.dueDate!.month}',
                        style: TextStyle(
                          fontSize: 12,
                          color: task.isOverdue ? Colors.red : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthStats() {
    final stats = _dashboardData!['month_stats'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Statistiques du mois', Icons.bar_chart_rounded),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Check-ins',
                '${stats['total_check_ins']}',
                Icons.login_rounded,
                const Color(0xFF2196F3),
                const Color(0xFF1976D2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                'Retards',
                '${stats['total_late']}',
                Icons.schedule_rounded,
                const Color(0xFFFF9800),
                const Color(0xFFF57C00),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                'Jours',
                '${stats['days_worked']}',
                Icons.calendar_today_rounded,
                const Color(0xFF4CAF50),
                const Color(0xFF388E3C),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color, Color darkColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: darkColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: darkColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampusList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Mes Campus', Icons.location_on_rounded),
        const SizedBox(height: 12),
        if (_campuses.isEmpty)
          _buildEmptyState(
            icon: Icons.location_off_rounded,
            message: 'Aucun campus assigné',
          )
        else
          ..._campuses.map((campus) => _buildCampusCard(campus)),
      ],
    );
  }

  Widget _buildCampusCard(Campus campus) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CheckInScreen(campus: campus),
              ),
            );
            if (result == true) {
              _loadData();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: campus.isActive
                        ? _primaryDark.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.apartment_rounded,
                    color: campus.isActive ? _primaryDark : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campus.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        campus.address,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 13, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            '${campus.getFormattedStartTime()} - ${campus.getFormattedEndTime()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _primaryDark.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: _primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUESection() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final isVacataire = user?.isVacataire() ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête UE avec stats
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryDark, _primaryLight],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _primaryDark.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.school_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Mes Unités d\'Enseignement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                // Stats heures/montant uniquement pour les vacataires (payés à l'heure)
                if (_ueStats != null && isVacataire) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildUEStatItem(
                          label: 'Heures effectuées',
                          value:
                              '${_ueStats!['heures_effectuees']?.toStringAsFixed(1) ?? 0}h',
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildUEStatItem(
                          label: 'Montant payé',
                          value:
                              '${(_ueStats!['montant_paye'] ?? 0).toStringAsFixed(0)} F',
                          icon: Icons.payments_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // UE Activées
        if (_unitesActivees.isNotEmpty) ...[
          _buildSubSectionTitle(
              'UE Activées (${_unitesActivees.length})', Colors.green),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _unitesActivees.length,
            itemBuilder: (context, index) {
              return UniteEnseignementCard(
                ue: _unitesActivees[index],
                onTap: () {},
              );
            },
          ),
        ],

        // UE Non Activées
        if (_unitesNonActivees.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSubSectionTitle(
              'UE En Attente (${_unitesNonActivees.length})', Colors.orange),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _unitesNonActivees.length,
            itemBuilder: (context, index) {
              return UniteEnseignementCard(
                ue: _unitesNonActivees[index],
                onTap: () {},
              );
            },
          ),
        ],

        // Aucune UE
        if (_unitesActivees.isEmpty && _unitesNonActivees.isEmpty)
          _buildEmptyState(
            icon: Icons.school_outlined,
            message: 'Aucune unité d\'enseignement attribuée',
          ),
      ],
    );
  }

  Widget _buildTodayScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: _buildSectionTitle(
                  'Emploi du Temps', Icons.calendar_month_rounded),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScheduleScreen(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: _primaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: _primaryDark.withValues(alpha: 0.2)),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Semaine', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_todaySchedule.isEmpty)
          _buildEmptyState(
            icon: Icons.event_busy_rounded,
            message: 'Pas de cours aujourd\'hui',
          )
        else
          ...List.generate(_todaySchedule.length, (index) {
            final item = _todaySchedule[index];
            final ue = item['ue'] as Map<String, dynamic>?;
            final campus = item['campus'] as Map<String, dynamic>?;
            final heureDebut = item['heure_debut'] ?? '';
            final heureFin = item['heure_fin'] ?? '';
            final salle = item['salle'];

            final colors = [
              const Color(0xFF2196F3),
              const Color(0xFF4CAF50),
              const Color(0xFFFF9800),
              const Color(0xFF9C27B0),
              const Color(0xFF009688),
            ];
            final color = colors[index % colors.length];

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
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
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Barre colorée latérale
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                    ),
                    // Horaire
                    Container(
                      width: 70,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            heureDebut,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 13,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 12,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: Colors.grey[300],
                          ),
                          Text(
                            heureFin,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Détails
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              ue?['code_ue'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ue?['nom_matiere'] ?? '',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (campus != null) ...[
                                  Icon(Icons.location_on_rounded,
                                      size: 12, color: Colors.grey[400]),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      campus['name'] ?? '',
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey[500]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                if (salle != null &&
                                    salle.toString().isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.meeting_room_rounded,
                                      size: 12, color: Colors.grey[400]),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Salle $salle',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
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
          }),
      ],
    );
  }

  // --- Composants réutilisables ---

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _primaryDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _buildSubSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildUEStatItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
