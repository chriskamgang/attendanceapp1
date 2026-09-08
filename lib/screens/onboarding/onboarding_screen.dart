import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _processes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProcesses();
  }

  Future<void> _loadProcesses() async {
    final result = await _apiService.getOnboardingProcesses();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) _processes = result['processes'];
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'not_started':
        return 'Non demarre';
      case 'in_progress':
        return 'En cours';
      case 'completed':
        return 'Termine';
      case 'cancelled':
        return 'Annule';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding / Offboarding'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _processes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aucun processus en cours', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProcesses,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _processes.length,
                    itemBuilder: (context, index) => _buildProcessCard(_processes[index]),
                  ),
                ),
    );
  }

  Widget _buildProcessCard(Map<String, dynamic> process) {
    final progress = process['progress'] ?? 0;
    final status = process['status'] ?? 'not_started';
    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openDetail(process['id']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: process['type'] == 'onboarding' ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      process['type_label'] ?? process['type'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: process['type'] == 'onboarding' ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
                    child: Text(_statusLabel(status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                process['template_name'] ?? 'Processus',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Debut: ${process['start_date'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  if (process['target_date'] != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.flag, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('Objectif: ${process['target_date']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress == 100 ? Colors.green : Colors.blue,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$progress%',
                    style: TextStyle(fontWeight: FontWeight.bold, color: progress == 100 ? Colors.green : Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${process['completed_tasks'] ?? 0}/${process['total_tasks'] ?? 0} taches completees',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OnboardingDetailScreen(processId: id)),
    ).then((_) => _loadProcesses());
  }
}

// ===== ONBOARDING DETAIL SCREEN =====

class OnboardingDetailScreen extends StatefulWidget {
  final int processId;
  const OnboardingDetailScreen({super.key, required this.processId});

  @override
  State<OnboardingDetailScreen> createState() => _OnboardingDetailScreenState();
}

class _OnboardingDetailScreenState extends State<OnboardingDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _process;
  List<dynamic> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final result = await _apiService.getOnboardingDetail(widget.processId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _process = result['process'];
          _tasks = result['tasks'];
        }
      });
    }
  }

  Future<void> _completeTask(int taskId) async {
    final result = await _apiService.completeOnboardingTask(widget.processId, taskId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? (result['success'] ? 'Tache completee' : 'Erreur'))),
      );
      if (result['success']) {
        _loadDetail();
        if (result['process_completed'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Processus termine !'), backgroundColor: Colors.green),
          );
        }
      }
    }
  }

  Color _taskStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'skipped':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _taskStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.play_circle;
      case 'skipped':
        return Icons.skip_next;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_process?['template_name'] ?? 'Processus'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDetail,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress card
                    if (_process != null)
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: const Color(0xFF00695C),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Progression', style: TextStyle(color: Colors.white70)),
                                  Text('${_process!['progress'] ?? 0}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (_process!['progress'] ?? 0) / 100,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),
                    const Text('Taches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    if (_tasks.isEmpty)
                      const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune tache'))))
                    else
                      ..._tasks.map((t) => _buildTaskCard(t)),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final status = task['status'] ?? 'pending';
    final isEmployee = task['assigned_to'] == 'employee';
    final canComplete = isEmployee && status != 'completed' && status != 'skipped';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_taskStatusIcon(status), color: _taskStatusColor(status), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: status == 'completed' ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isEmployee ? Colors.blue[50] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              task['assigned_label'] ?? task['assigned_to'] ?? '',
                              style: TextStyle(fontSize: 11, color: isEmployee ? Colors.blue[700] : Colors.grey[600]),
                            ),
                          ),
                          if (task['due_date'] != null) ...[
                            const SizedBox(width: 8),
                            Text('Echeance: ${task['due_date']}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(task['description'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
            if (task['completed_date'] != null) ...[
              const SizedBox(height: 4),
              Text('Complete le ${task['completed_date']}', style: TextStyle(color: Colors.green[600], fontSize: 12)),
            ],
            if (canComplete) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _completeTask(task['id']),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Marquer comme termine'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
