import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'request_leave_screen.dart';

class LeavesScreen extends StatefulWidget {
  const LeavesScreen({super.key});

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  List<dynamic> _leaves = [];
  List<dynamic> _balances = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      _apiService.getLeaves(),
      _apiService.getLeaveBalances(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (results[0]['success'] == true) {
          _leaves = results[0]['leaves'] as List;
        }
        if (results[1]['success'] == true) {
          _balances = results[1]['balances'] as List;
        }
      });
    }
  }

  Future<void> _cancelLeave(int leaveId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la demande'),
        content: const Text('Voulez-vous vraiment annuler cette demande de conge ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await _apiService.cancelLeave(leaveId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? ''), backgroundColor: result['success'] ? Colors.green : Colors.red),
      );
      if (result['success']) _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Conges'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Demandes'),
            Tab(text: 'Soldes'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLeavesTab(),
                _buildBalancesTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RequestLeaveScreen()),
          );
          if (result == true) _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Demander'),
      ),
    );
  }

  Widget _buildLeavesTab() {
    if (_leaves.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aucune demande de conge', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaves.length,
        itemBuilder: (context, index) {
          final leave = _leaves[index];
          return _buildLeaveCard(leave);
        },
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    final status = leave['status'] as String;
    final statusColor = _getStatusColor(status);
    final statusLabel = _getStatusLabel(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    leave['type_label'] ?? '',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '${_formatDate(leave['start_date'])} - ${_formatDate(leave['end_date'])}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.timelapse, size: 14, color: Colors.blue[700]),
                const SizedBox(width: 4),
                Text(
                  '${leave['days_count']} jour(s)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue[700]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              leave['reason'] ?? '',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (leave['review_comment'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.comment, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        leave['review_comment'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancelLeave(leave['id']),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                  label: const Text('Annuler', style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalancesTab() {
    if (_balances.isEmpty) {
      return const Center(child: Text('Aucun solde disponible'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _balances.length,
        itemBuilder: (context, index) {
          final balance = _balances[index];
          final total = balance['total_days'] ?? 0;
          final used = balance['used_days'] ?? 0;
          final remaining = balance['remaining_days'] ?? 0;
          final progress = total > 0 ? used / total : 0.0;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        balance['label'] ?? '',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$remaining j restant(s)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: remaining > 0 ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(
                        progress > 0.8 ? Colors.red : (progress > 0.5 ? Colors.orange : Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$used utilise(s) sur $total',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'approved': return 'Approuve';
      case 'rejected': return 'Rejete';
      case 'cancelled': return 'Annule';
      default: return status;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
