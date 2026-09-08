import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/api_service.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _certificates = [];
  bool _isLoading = true;

  static const _types = {
    'work': {'label': 'Attestation de travail', 'icon': Icons.work_outline, 'color': Colors.blue},
    'salary': {'label': 'Attestation de salaire', 'icon': Icons.account_balance_wallet, 'color': Colors.green},
    'employment': {'label': 'Certificat de travail', 'icon': Icons.badge_outlined, 'color': Colors.orange},
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await _apiService.getCertificates();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) _certificates = result['certificates'] as List;
      });
    }
  }

  Future<void> _requestCertificate() async {
    String selectedType = 'work';
    final purposeController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Demander une attestation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type d\'attestation',
                  border: OutlineInputBorder(),
                ),
                items: _types.entries.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value['label'] as String),
                )).toList(),
                onChanged: (v) => setDialogState(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: purposeController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Motif (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Demander'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final response = await _apiService.requestCertificate(
      type: selectedType,
      purpose: purposeController.text.trim().isEmpty ? null : purposeController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? ''),
          backgroundColor: response['success'] ? Colors.green : Colors.red,
        ),
      );
      if (response['success']) _loadData();
    }
  }

  Future<void> _downloadCertificate(int id) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Telechargement en cours...')),
    );

    final path = await _apiService.downloadCertificate(id);
    if (path != null && mounted) {
      await OpenFilex.open(path);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du telechargement'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attestations'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _requestCertificate,
        icon: const Icon(Icons.add),
        label: const Text('Demander'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _certificates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('Aucune attestation', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Cliquez sur + pour en demander une', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _certificates.length,
                    itemBuilder: (context, index) {
                      final cert = _certificates[index];
                      final type = cert['type'] as String;
                      final typeInfo = _types[type] ?? _types['work']!;
                      final status = cert['status'] as String;

                      final statusColor = status == 'generated' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
                      final statusLabel = status == 'generated' ? 'Generee' : (status == 'rejected' ? 'Rejetee' : 'En attente');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (typeInfo['color'] as Color?)?.withAlpha(25),
                            child: Icon(typeInfo['icon'] as IconData, color: typeInfo['color'] as Color?, size: 22),
                          ),
                          title: Text(cert['type_label'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (cert['purpose'] != null)
                                Text(cert['purpose'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              Text('Demande le ${cert['created_at']}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            ],
                          ),
                          trailing: status == 'generated'
                              ? IconButton(
                                  icon: const Icon(Icons.download, color: Colors.green),
                                  onPressed: () => _downloadCertificate(cert['id']),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                                ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
