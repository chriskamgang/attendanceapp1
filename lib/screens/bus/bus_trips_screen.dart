import 'package:flutter/material.dart';
import '../../services/bus_service.dart';

class BusTripsScreen extends StatefulWidget {
  const BusTripsScreen({super.key});

  @override
  State<BusTripsScreen> createState() => _BusTripsScreenState();
}

class _BusTripsScreenState extends State<BusTripsScreen> {
  final BusService _busService = BusService();
  bool _isLoading = true;
  List<dynamic> _trajets = [];
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadTrajets();
  }

  Future<void> _loadTrajets({bool loadMore = false}) async {
    if (loadMore) {
      _currentPage++;
    } else {
      _currentPage = 1;
      setState(() => _isLoading = true);
    }

    final result = await _busService.getMesTrajets(page: _currentPage);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        final data = result['data'] as List? ?? [];
        if (loadMore) {
          _trajets.addAll(data);
        } else {
          _trajets = data;
        }
        _hasMore = data.length >= 20;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mes Trajets'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trajets.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: () => _loadTrajets(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trajets.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _trajets.length) {
                        return Center(
                          child: TextButton(
                            onPressed: () => _loadTrajets(loadMore: true),
                            child: const Text('Charger plus'),
                          ),
                        );
                      }
                      return _buildTrajetCard(_trajets[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildTrajetCard(Map<String, dynamic> trajet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.directions_bus, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trajet['ligne']?['nom'] ?? trajet['tournee']?['parcours']?['ligne']?['nom'] ?? 'Trajet',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  if (trajet['embarque_le'] != null || trajet['created_at'] != null)
                    Text(
                      trajet['embarque_le'] ?? trajet['created_at'] ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  if (trajet['arret']?['nom'] != null)
                    Text(
                      'Arret: ${trajet['arret']['nom']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
            if (trajet['sens'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trajet['sens'] == 'aller' ? Colors.green.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trajet['sens'] ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: trajet['sens'] == 'aller' ? Colors.green.shade700 : Colors.blue.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Aucun trajet enregistre', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('Vos trajets apparaitront ici apres chaque embarquement.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
