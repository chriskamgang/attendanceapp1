import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class MoratoireScreen extends StatefulWidget {
  const MoratoireScreen({super.key});

  @override
  State<MoratoireScreen> createState() => _MoratoireScreenState();
}

class _MoratoireScreenState extends State<MoratoireScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _moratoriums = [];
  bool _isLoading = true;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMoratoriums();
  }

  Future<void> _loadMoratoriums() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getMoratoriums();
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() => _moratoriums = result['data']);
      }
    } catch (e) {
      debugPrint('Erreur moratoires: $e');
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _submitRequest() async {
    if (_reasonController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez détailler votre motivation (min. 10 caractères)')),
      );
      return;
    }

    Navigator.pop(context); // Fermer le modal

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final result = await _apiService.requestMoratorium(_reasonController.text.trim());
      if (!mounted) return;
      if (result['success']) {
        _reasonController.clear();
        _loadMoratoriums();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Demande envoyée'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Erreur'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showRequestModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nouvelle Demande de Moratoire',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Décrivez votre situation (motivation)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ENVOYER LA DEMANDE'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moratoires'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMoratoriums),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _moratoriums.isEmpty
              ? _buildEmptyState()
              : _buildList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showRequestModal,
        backgroundColor: const Color(0xFF0D47A1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Aucune demande de moratoire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Cliquez sur le bouton + pour en soumettre une.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _moratoriums.length,
      itemBuilder: (context, index) {
        final item = _moratoriums[index];
        return _buildMoratoriumCard(item);
      },
    );
  }

  Widget _buildMoratoriumCard(dynamic item) {
    final status = item['status'];
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.highlight_off;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Demande du ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(item['created_at']))}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        item['status_label'],
                        style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Ma Motivation :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(item['reason'], style: const TextStyle(fontSize: 14)),
            
            if (item['observation'] != null && item['observation'].toString().isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Réponse de l\'Administration :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
              const SizedBox(height: 4),
              Text(
                item['observation'],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (item['validator_name'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Par: ${item['validator_name']}',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
