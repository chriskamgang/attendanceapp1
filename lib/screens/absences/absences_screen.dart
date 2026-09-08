import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AbsencesScreen extends StatefulWidget {
  const AbsencesScreen({super.key});

  @override
  State<AbsencesScreen> createState() => _AbsencesScreenState();
}

class _AbsencesScreenState extends State<AbsencesScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  Map<String, dynamic>? _summary;
  List<dynamic> _absences = [];
  List<dynamic> _tardiness = [];
  List<dynamic> _requests = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

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
      _apiService.getAbsenceSummary(month: _selectedMonth.month, year: _selectedMonth.year),
      _apiService.getAbsences(month: _selectedMonth.month, year: _selectedMonth.year),
      _apiService.getTardiness(month: _selectedMonth.month, year: _selectedMonth.year),
      _apiService.getMyJustificationRequests(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (results[0]['success'] == true) _summary = results[0]['summary'];
        if (results[1]['success'] == true) _absences = results[1]['absences'] as List;
        if (results[2]['success'] == true) _tardiness = results[2]['tardiness'] as List;
        if (results[3]['success'] == true) _requests = results[3]['requests'] as List;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
    _loadData();
  }

  Future<void> _submitJustification(String type, String date) async {
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Justifier ${type == 'absence' ? "l\'absence" : "le retard"}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Date : ${_formatDate(date)}', style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Motif de la justification...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (result != true || reasonController.text.trim().isEmpty) return;

    final response = await _apiService.submitJustification(
      type: type,
      date: date,
      reason: reasonController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final months = ['Jan', 'Fev', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aou', 'Sep', 'Oct', 'Nov', 'Dec'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Absences & Retards'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Absences'),
            Tab(text: 'Retards'),
            Tab(text: 'Demandes'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Selecteur de mois
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                Text(
                  '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),

          // Resume
          if (_summary != null && !_isLoading) _buildSummaryCards(),

          // Contenu
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAbsencesList(),
                      _buildTardinessList(),
                      _buildRequestsList(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final absences = _summary!['absences'];
    final tardiness = _summary!['tardiness'];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              'Absences',
              '${absences['unjustified']}',
              'non justifiees',
              Colors.red,
              subtitle2: '${absences['justified']} justifiee(s)',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryCard(
              'Retards',
              '${tardiness['total']}',
              '${tardiness['total_late_minutes']} min',
              Colors.orange,
              subtitle2: '${tardiness['justified']} justifie(s)',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryCard(
              'En attente',
              '${_summary!['pending_requests']}',
              'demande(s)',
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, String subtitle, Color color, {String? subtitle2}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          if (subtitle2 != null)
            Text(subtitle2, style: TextStyle(fontSize: 10, color: Colors.green[700])),
        ],
      ),
    );
  }

  Widget _buildAbsencesList() {
    if (_absences.isEmpty) {
      return const Center(child: Text('Aucune absence ce mois', style: TextStyle(color: Colors.grey)));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _absences.length,
        itemBuilder: (context, index) {
          final a = _absences[index];
          final isJustified = a['is_justified'] == true;
          final hasPending = a['justification_status'] == 'pending';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isJustified ? Colors.green[100] : Colors.red[100],
                child: Icon(
                  isJustified ? Icons.check : Icons.close,
                  color: isJustified ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              title: Text(_formatDate(a['date']), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a['type_label'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if (a['campus'] != null)
                    Text(a['campus'], style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
              trailing: isJustified
                  ? const Chip(label: Text('Justifiee', style: TextStyle(fontSize: 10)), backgroundColor: Color(0xFFE8F5E9))
                  : hasPending
                      ? const Chip(label: Text('En cours', style: TextStyle(fontSize: 10)), backgroundColor: Color(0xFFFFF3E0))
                      : TextButton(
                          onPressed: () => _submitJustification('absence', a['date']),
                          child: const Text('Justifier', style: TextStyle(fontSize: 12)),
                        ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTardinessList() {
    if (_tardiness.isEmpty) {
      return const Center(child: Text('Aucun retard ce mois', style: TextStyle(color: Colors.grey)));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _tardiness.length,
        itemBuilder: (context, index) {
          final t = _tardiness[index];
          final isJustified = t['status'] == 'justified';
          final hasPending = t['justification_status'] == 'pending';
          final lateMin = t['late_minutes'] ?? 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange[100],
                child: Text(
                  '${lateMin}m',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                ),
              ),
              title: Text(_formatDate(t['date']), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prevu: ${t['scheduled_time'] ?? '-'} → Arrive: ${t['actual_time'] ?? '-'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (t['campus'] != null)
                    Text(t['campus'], style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
              trailing: isJustified
                  ? const Chip(label: Text('Justifie', style: TextStyle(fontSize: 10)), backgroundColor: Color(0xFFE8F5E9))
                  : hasPending
                      ? const Chip(label: Text('En cours', style: TextStyle(fontSize: 10)), backgroundColor: Color(0xFFFFF3E0))
                      : TextButton(
                          onPressed: () => _submitJustification('tardiness', t['date']),
                          child: const Text('Justifier', style: TextStyle(fontSize: 12)),
                        ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_requests.isEmpty) {
      return const Center(child: Text('Aucune demande soumise', style: TextStyle(color: Colors.grey)));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final r = _requests[index];
          final status = r['status'] as String;
          final statusColor = status == 'approved' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: r['type'] == 'absence' ? Colors.red[50] : Colors.orange[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r['type_label'] ?? '',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: r['type'] == 'absence' ? Colors.red[800] : Colors.orange[800]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatDate(r['date']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status == 'approved' ? 'Approuve' : (status == 'rejected' ? 'Rejete' : 'En attente'),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(r['reason'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  if (r['review_comment'] != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                      child: Text(r['review_comment'], style: TextStyle(fontSize: 11, color: Colors.grey[700], fontStyle: FontStyle.italic)),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text('Soumis le ${r['created_at']}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return '${days[date.weekday - 1]} ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
