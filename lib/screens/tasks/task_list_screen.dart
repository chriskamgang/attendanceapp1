import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../services/api_service.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final ApiService _apiService = ApiService();
  List<Task> _tasks = [];
  List<Task> _filteredTasks = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  static const Color _primaryDark = Color(0xFF1A237E);
  static const Color _primaryMid = Color(0xFF283593);
  static const Color _accentBlue = Color(0xFF42A5F5);

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    final result = await _apiService.getMyTasks();
    if (result['success']) {
      _tasks = (result['data'] as List)
          .map((t) => Task.fromJson(t))
          .toList();
      _applyFilter();
    }

    setState(() => _isLoading = false);
  }

  void _applyFilter() {
    if (_selectedFilter == 'all') {
      _filteredTasks = _tasks;
    } else {
      _filteredTasks = _tasks.where((t) => t.myStatus == _selectedFilter).toList();
    }
  }

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'in_progress':
        return Icons.play_circle_outline;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _updateTaskStatus(Task task, String newStatus) async {
    final result = await _apiService.updateTaskStatus(task.id, newStatus);
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Statut mis a jour'),
          backgroundColor: Colors.green,
        ),
      );
      _loadTasks();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erreur'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTaskDetail(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Text(
                task.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Badges row
              Wrap(
                spacing: 8,
                children: [
                  _buildBadge(task.priorityLabel, _priorityColor(task.priority)),
                  _buildBadge(task.myStatusLabel, _statusColor(task.myStatus)),
                  if (task.isOverdue)
                    _buildBadge('En retard', Colors.red),
                ],
              ),
              const SizedBox(height: 16),

              // Penalty warning
              if (task.hasPenalty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: task.penaltyApproved ? Colors.red[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: task.penaltyApproved ? Colors.red[200]! : Colors.orange[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        task.penaltyApproved ? Icons.warning : Icons.info_outline,
                        color: task.penaltyApproved ? Colors.red : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.penaltyApproved
                                  ? 'Coupure approuvee: ${task.formattedPenalty}'
                                  : 'Penalite si non faite: ${task.formattedPenalty}',
                              style: TextStyle(
                                color: task.penaltyApproved ? Colors.red[800] : Colors.orange[800],
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (task.penaltyApproved)
                              Text(
                                'Ce montant sera deduit de votre salaire',
                                style: TextStyle(
                                  color: Colors.red[600],
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Details
              if (task.description != null && task.description!.isNotEmpty) ...[
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
              ],

              if (task.dueDate != null) ...[
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: task.isOverdue ? Colors.red : Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Echeance: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                      style: TextStyle(
                        color: task.isOverdue ? Colors.red : Colors.grey[700],
                        fontWeight: task.isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              if (task.creatorName != null) ...[
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Assignee par: ${task.creatorName}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Action buttons
              if (task.myStatus != 'completed') ...[
                const Text(
                  'Changer le statut',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (task.myStatus == 'pending')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateTaskStatus(task, 'in_progress');
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Commencer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    if (task.myStatus == 'pending')
                      const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _updateTaskStatus(task, 'completed');
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Terminer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Tache terminee',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_primaryDark, _primaryMid],
                  ),
                ),
              ),
              title: const Text(
                'Mes Taches',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Toutes', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('En attente', 'pending'),
                    const SizedBox(width: 8),
                    _buildFilterChip('En cours', 'in_progress'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Terminees', 'completed'),
                  ],
                ),
              ),
            ),
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredTasks.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.task_alt, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFilter == 'all'
                          ? 'Aucune tache assignee'
                          : 'Aucune tache dans cette categorie',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final task = _filteredTasks[index];
                  return _buildTaskCard(task);
                },
                childCount: _filteredTasks.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    final count = value == 'all'
        ? _tasks.length
        : _tasks.where((t) => t.myStatus == value).length;

    return GestureDetector(
      onTap: () => _setFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _accentBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _accentBlue : Colors.grey[300]!,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _showTaskDetail(task),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _statusColor(task.myStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _statusIcon(task.myStatus),
                    color: _statusColor(task.myStatus),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          decoration: task.myStatus == 'completed'
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Priority dot
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _priorityColor(task.priority),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            task.priorityLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (task.hasPenalty) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.monetization_on,
                              size: 12,
                              color: task.penaltyApproved ? Colors.red : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              task.formattedPenalty,
                              style: TextStyle(
                                fontSize: 12,
                                color: task.penaltyApproved ? Colors.red : Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (task.dueDate != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: task.isOverdue ? Colors.red : Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${task.dueDate!.day}/${task.dueDate!.month}',
                              style: TextStyle(
                                fontSize: 12,
                                color: task.isOverdue ? Colors.red : Colors.grey[600],
                                fontWeight: task.isOverdue ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
