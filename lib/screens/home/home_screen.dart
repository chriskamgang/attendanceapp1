import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/campus.dart';
import '../../models/unite_enseignement.dart';
import '../../services/api_service.dart';
import '../../widgets/unite_enseignement_card.dart';
import '../attendance/check_in_screen.dart';

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

    // Charger les données du dashboard
    final dashResult = await _apiService.getDashboard();
    if (dashResult['success']) {
      _dashboardData = dashResult['data'];
    }

    // Charger les campus
    final campusResult = await _apiService.getMyCampuses();
    if (campusResult['success']) {
      _campuses = campusResult['campuses'];
    }

    // Si vacataire, charger les UE
    if (user != null && user.isVacataire()) {
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

    // Vérifier le statut actuel
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);
    await attendanceProvider.checkCurrentStatus();

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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
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
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête utilisateur
                    _buildUserHeader(user),
                    const SizedBox(height: 24),

                    // Statut check-in
                    _buildCheckInStatus(attendanceProvider),
                    const SizedBox(height: 24),

                    // Section UE pour vacataires
                    if (user != null && user.isVacataire()) ...[
                      _buildUESection(),
                      const SizedBox(height: 24),
                    ],

                    // Vérifications en attente
                    if (_dashboardData != null &&
                        _dashboardData!['pending_presence_checks'] > 0)
                      _buildPendingChecks(),

                    const SizedBox(height: 24),

                    // Statistiques du mois
                    if (_dashboardData != null) _buildMonthStats(),

                    const SizedBox(height: 24),

                    // Liste des campus
                    _buildCampusList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserHeader(user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue,
              child: Text(
                user?.firstName?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.fullName ?? 'Utilisateur',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.role?.displayName ?? '',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    user?.department?.name ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInStatus(AttendanceProvider attendanceProvider) {
    final hasActive = attendanceProvider.hasActiveCheckIn;
    final activeCheckIns = attendanceProvider.activeCheckIns;

    return Card(
      color: hasActive ? Colors.green[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasActive ? Icons.check_circle : Icons.info_outline,
                  color: hasActive ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  hasActive ? 'Check-in actif' : 'Pas de check-in actif',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hasActive ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ],
            ),
            if (hasActive && activeCheckIns.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...activeCheckIns.map((attendance) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${attendance.campus?.name ?? 'Campus'} - Check-in à ${attendance.getFormattedTime()}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingChecks() {
    final count = _dashboardData!['pending_presence_checks'];
    return Card(
      color: Colors.red[50],
      child: InkWell(
        onTap: () {
          // TODO: Naviguer vers l'écran des vérifications
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.red[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vérifications en attente',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    Text(
                      '$count vérification${count > 1 ? 's' : ''} à traiter',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.red[700]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthStats() {
    final stats = _dashboardData!['month_stats'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistiques du mois',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Check-ins',
                '${stats['total_check_ins']}',
                Icons.login,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Retards',
                '${stats['total_late']}',
                Icons.schedule,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Jours',
                '${stats['days_worked']}',
                Icons.calendar_today,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampusList() {
    if (_campuses.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aucun campus assigné'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mes Campus',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._campuses.map((campus) => _buildCampusCard(campus)).toList(),
      ],
    );
  }

  Widget _buildCampusCard(Campus campus) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CheckInScreen(campus: campus),
            ),
          );
          // Si check-in/out réussi, recharger les données
          if (result == true) {
            _loadData();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: campus.isActive ? Colors.blue : Colors.grey,
                size: 40,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campus.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      campus.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Horaires: ${campus.getFormattedStartTime()} - ${campus.getFormattedEndTime()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUESection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête avec statistiques globales
        Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.school, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    const Text(
                      'Mes Unités d\'Enseignement',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_ueStats != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          label: 'Heures effectuées',
                          value: '${_ueStats!['heures_effectuees']?.toStringAsFixed(1) ?? 0}h',
                          icon: Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          label: 'Montant payé',
                          value: '${(_ueStats!['montant_paye'] ?? 0).toStringAsFixed(0)} F',
                          icon: Icons.attach_money,
                          color: Colors.blue,
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
          Text(
            'UE Activées (${_unitesActivees.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _unitesActivees.length,
            itemBuilder: (context, index) {
              return UniteEnseignementCard(
                ue: _unitesActivees[index],
                onTap: () {
                  // TODO: Naviguer vers les détails de l'UE
                },
              );
            },
          ),
        ],

        // UE Non Activées
        if (_unitesNonActivees.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'UE En Attente d\'Activation (${_unitesNonActivees.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _unitesNonActivees.length,
            itemBuilder: (context, index) {
              return UniteEnseignementCard(
                ue: _unitesNonActivees[index],
                onTap: () {
                  // TODO: Naviguer vers les détails de l'UE
                },
              );
            },
          ),
        ],

        // Message si aucune UE
        if (_unitesActivees.isEmpty && _unitesNonActivees.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.school_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'Aucune unité d\'enseignement attribuée',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
