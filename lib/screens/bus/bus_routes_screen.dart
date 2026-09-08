import 'package:flutter/material.dart';
import '../../services/bus_service.dart';

class BusRoutesScreen extends StatefulWidget {
  const BusRoutesScreen({super.key});

  @override
  State<BusRoutesScreen> createState() => _BusRoutesScreenState();
}

class _BusRoutesScreenState extends State<BusRoutesScreen> with SingleTickerProviderStateMixin {
  final BusService _busService = BusService();
  bool _isLoading = true;
  List<dynamic> _lignes = [];
  List<dynamic> _tarifs = [];
  List<dynamic> _points = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _busService.getLignes(),
      _busService.getParcours(),
      _busService.getTarifs(),
      _busService.getPointsRamassage(),
    ]);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _lignes = results[0]['data'] ?? [];
      _tarifs = results[2]['data'] ?? [];
      _points = results[3]['data'] ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Reseau de Transport'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Lignes', icon: Icon(Icons.route, size: 18)),
            Tab(text: 'Arrets', icon: Icon(Icons.location_on, size: 18)),
            Tab(text: 'Tarifs', icon: Icon(Icons.local_offer, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLignesTab(),
                _buildPointsTab(),
                _buildTarifsTab(),
              ],
            ),
    );
  }

  Widget _buildLignesTab() {
    if (_lignes.isEmpty) {
      return _emptyState(Icons.route, 'Aucune ligne configuree');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _lignes.length,
        itemBuilder: (context, index) {
          final ligne = _lignes[index];
          final arrets = ligne['arrets'] as List? ?? [];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.route, color: Colors.blue.shade700),
              ),
              title: Text(ligne['nom'] ?? 'Ligne', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${arrets.length} arret(s)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              children: [
                if (arrets.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: arrets.asMap().entries.map((entry) {
                        final i = entry.key;
                        final arret = entry.value;
                        final isLast = i == arrets.length - 1;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: i == 0 ? Colors.green : isLast ? Colors.red : Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                                  ),
                                ),
                                if (!isLast)
                                  Container(width: 2, height: 30, color: Colors.grey.shade300),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Text(
                                  arret['nom'] ?? arret['lieu']?['nom'] ?? 'Arret ${i + 1}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPointsTab() {
    if (_points.isEmpty) {
      return _emptyState(Icons.location_on, 'Aucun point de ramassage');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _points.length,
        itemBuilder: (context, index) {
          final point = _points[index];
          final lignes = point['lignes'] as List? ?? [];

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.location_on, color: Colors.orange.shade700),
              ),
              title: Text(point['nom'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: lignes.isNotEmpty
                  ? Wrap(
                      spacing: 4,
                      children: lignes.map<Widget>((l) => Chip(
                        label: Text(l['nom'] ?? l.toString(), style: const TextStyle(fontSize: 10)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.blue.shade50,
                      )).toList(),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTarifsTab() {
    if (_tarifs.isEmpty) {
      return _emptyState(Icons.local_offer, 'Aucun tarif disponible');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tarifs.length,
        itemBuilder: (context, index) {
          final tarif = _tarifs[index];
          final prix = tarif['montant'] ?? tarif['prix'] ?? 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.local_offer, color: Colors.green.shade700),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tarif['nom'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (tarif['description'] != null)
                          Text(tarif['description'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (tarif['duree_jours'] != null || tarif['duree'] != null)
                              Text('${tarif['duree_jours'] ?? tarif['duree']}j  ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            if (tarif['trajets_inclus'] != null || tarif['nombre_trajets'] != null)
                              Text('${tarif['trajets_inclus'] ?? tarif['nombre_trajets']} trajets', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_formatPrice(prix)}\nFCFA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade700),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    final n = price is int ? price : int.tryParse(price.toString()) ?? 0;
    return n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }
}
