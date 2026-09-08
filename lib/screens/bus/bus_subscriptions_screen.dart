import 'package:flutter/material.dart';
import '../../services/bus_service.dart';

class BusSubscriptionsScreen extends StatefulWidget {
  const BusSubscriptionsScreen({super.key});

  @override
  State<BusSubscriptionsScreen> createState() => _BusSubscriptionsScreenState();
}

class _BusSubscriptionsScreenState extends State<BusSubscriptionsScreen> {
  final BusService _busService = BusService();
  bool _isLoading = true;
  Map<String, dynamic>? _activePass;
  List<dynamic> _abonnements = [];
  List<dynamic> _tarifs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _busService.getAbonnementActif(),
      _busService.getAbonnements(),
      _busService.getTarifs(),
    ]);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (results[0]['success'] == true) {
        _activePass = results[0];
      }
      if (results[1]['success'] == true) {
        _abonnements = results[1]['data'] ?? [];
      }
      if (results[2]['success'] == true) {
        _tarifs = results[2]['data'] ?? [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mes Abonnements'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Abonnement actif
                  if (_activePass != null && (_activePass!['abonnement'] != null || (_activePass!['pass'] as List?)?.isNotEmpty == true))
                    _buildActiveCard(),

                  // Acheter un abonnement
                  if (_tarifs.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Acheter un abonnement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._tarifs.map((tarif) => _buildTarifCard(tarif)),
                  ],

                  // Historique
                  if (_abonnements.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Historique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._abonnements.map((abo) => _buildAbonnementCard(abo)),
                  ],

                  if (_tarifs.isEmpty && _abonnements.isEmpty && _activePass == null)
                    _buildEmptyState(),
                ],
              ),
            ),
    );
  }

  Widget _buildActiveCard() {
    final abonnement = _activePass!['abonnement'];
    final pass = _activePass!['pass'] as List? ?? [];
    final totalTrajets = _activePass!['total_trajets'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_membership, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              const Text('Abonnement Actif', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: const Text('Actif', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
          if (abonnement != null) ...[
            const SizedBox(height: 12),
            Text(
              abonnement['tarif']?['nom'] ?? 'Abonnement',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 8),
            Text(
              '$totalTrajets trajet(s) effectues',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          if (pass.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${pass.length} pass actif(s)',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTarifCard(Map<String, dynamic> tarif) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.local_offer, color: Colors.blue.shade700),
        ),
        title: Text(tarif['nom'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tarif['description'] != null)
              Text(tarif['description'], style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              '${_formatPrice(tarif['montant'] ?? tarif['prix'] ?? 0)} FCFA',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 15),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _showSubscribeDialog(tarif),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Souscrire'),
        ),
      ),
    );
  }

  Widget _buildAbonnementCard(Map<String, dynamic> abo) {
    final statut = abo['statut'] ?? 'inconnu';
    final Color statusColor;
    switch (statut) {
      case 'actif':
        statusColor = Colors.green;
        break;
      case 'en_attente':
        statusColor = Colors.orange;
        break;
      case 'expire':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(Icons.receipt_long, color: statusColor),
        title: Text(abo['tarif']?['nom'] ?? 'Abonnement', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(abo['date_debut'] ?? ''),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(statut, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.card_membership, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Aucun abonnement', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    final n = price is int ? price : int.tryParse(price.toString()) ?? 0;
    return n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }

  void _showSubscribeDialog(Map<String, dynamic> tarif) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Souscrire: ${tarif['nom']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prix: ${_formatPrice(tarif['montant'] ?? tarif['prix'] ?? 0)} FCFA'),
            if (tarif['description'] != null) ...[
              const SizedBox(height: 8),
              Text(tarif['description'], style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
            const SizedBox(height: 16),
            const Text('Confirmer la souscription ?', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _subscribe(tarif);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _subscribe(Map<String, dynamic> tarif) async {
    final tarifId = tarif['id'];
    if (tarifId == null) return;

    setState(() => _isLoading = true);
    final result = await _busService.createAbonnement(tarifId: tarifId);

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abonnement cree avec succes !'), backgroundColor: Colors.green),
      );
      _loadData();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Erreur'), backgroundColor: Colors.red),
      );
    }
  }
}
