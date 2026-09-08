import 'package:flutter/material.dart';
import '../../services/bus_service.dart';
import 'bus_tracking_screen.dart';
import 'bus_subscriptions_screen.dart';
import 'bus_qr_pass_screen.dart';
import 'bus_routes_screen.dart';
import 'bus_trips_screen.dart';

class BusHomeScreen extends StatefulWidget {
  const BusHomeScreen({super.key});

  @override
  State<BusHomeScreen> createState() => _BusHomeScreenState();
}

class _BusHomeScreenState extends State<BusHomeScreen> {
  final BusService _busService = BusService();
  bool _isLoading = true;
  bool _isRegistered = false;
  String? _errorMessage;
  Map<String, dynamic>? _busUser;

  @override
  void initState() {
    super.initState();
    _initBus();
  }

  /// Verifie le statut bus. Le backend auto-inscrit si pas encore fait.
  Future<void> _initBus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _busService.getStatus();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isRegistered = result['registered'] == true;
      _busUser = result['utilisateur'];
      if (!_isRegistered) {
        _errorMessage = result['message'];
      }
    });
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Transport Bus', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _isRegistered
              ? _buildMainView()
              : _buildErrorView(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Configuration du service bus...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off, size: 48, color: Colors.orange.shade700),
            ),
            const SizedBox(height: 24),
            const Text(
              'Service bus indisponible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Impossible de se connecter au service de transport. Reessayez plus tard.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initBus,
              icon: const Icon(Icons.refresh),
              label: const Text('Reessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _navigateTo(const BusRoutesScreen()),
              icon: const Icon(Icons.route),
              label: const Text('Voir les lignes et tarifs'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return RefreshIndicator(
      onRefresh: _initBus,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_bus, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'INSAM Bus',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Actif', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (_busUser != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${_busUser!['prenom'] ?? ''} ${_busUser!['nom'] ?? ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Quick actions
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildActionCard(
                icon: Icons.gps_fixed,
                label: 'Mon Bus',
                subtitle: 'Suivi en temps reel',
                color: Colors.green,
                onTap: () => _navigateTo(const BusTrackingScreen()),
              ),
              _buildActionCard(
                icon: Icons.qr_code,
                label: 'QR Pass',
                subtitle: 'Scanner pour embarquer',
                color: Colors.orange,
                onTap: () => _navigateTo(const BusQrPassScreen()),
              ),
              _buildActionCard(
                icon: Icons.card_membership,
                label: 'Abonnements',
                subtitle: 'Gerer mes abonnements',
                color: Colors.blue,
                onTap: () => _navigateTo(const BusSubscriptionsScreen()),
              ),
              _buildActionCard(
                icon: Icons.history,
                label: 'Mes Trajets',
                subtitle: 'Historique',
                color: Colors.purple,
                onTap: () => _navigateTo(const BusTripsScreen()),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Lignes et tarifs
          _buildListTile(
            icon: Icons.route,
            title: 'Lignes & Parcours',
            subtitle: 'Voir les itineraires et arrets',
            onTap: () => _navigateTo(const BusRoutesScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1565C0)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
