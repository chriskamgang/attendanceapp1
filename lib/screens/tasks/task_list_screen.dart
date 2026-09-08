import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/task.dart';
import '../../services/api_service.dart';
import '../../shared/rh_ui.dart';

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
        return AppColors.danger;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'in_progress':
        return AppColors.blue;
      case 'completed':
        return AppColors.success;
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
          backgroundColor: AppColors.success,
        ),
      );
      _loadTasks();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erreur'),
          backgroundColor: AppColors.danger,
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
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(Brutal.radiusSmall),
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
                    _buildBadge('En retard', AppColors.danger),
                ],
              ),
              const SizedBox(height: 16),

              // Penalty warning
              if (task.hasPenalty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: task.penaltyApproved ? AppColors.danger : AppColors.warning,
                    borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                    border: Border.all(
                      color: task.penaltyApproved ? AppColors.danger : AppColors.warning,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        task.penaltyApproved ? Icons.warning : Icons.info_outline,
                        color: task.penaltyApproved ? AppColors.danger : AppColors.warning,
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
                                color: task.penaltyApproved ? AppColors.danger : AppColors.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (task.penaltyApproved)
                              Text(
                                'Ce montant sera deduit de votre salaire',
                                style: TextStyle(
                                  color: AppColors.danger,
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
                    Icon(Icons.calendar_today, size: 16, color: task.isOverdue ? AppColors.danger : Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Echeance: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                      style: TextStyle(
                        color: task.isOverdue ? AppColors.danger : AppColors.inkMuted,
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
                      style: TextStyle(color: AppColors.inkMuted),
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
                            backgroundColor: AppColors.blue,
                            foregroundColor: AppColors.white,
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
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // Fond clair : l'encre verte disparaissait sur un vert
                    // plein de la même teinte.
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success),
                      const SizedBox(width: 8),
                      const Text(
                        'Tache terminee',
                        style: TextStyle(
                          color: AppColors.success,
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
        borderRadius: BorderRadius.circular(Brutal.radius),
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
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.blueDark,
            surfaceTintColor: Colors.transparent,
            // Icônes de la barre d'état en clair : le bandeau est sombre.
            systemOverlayStyle: SystemUiOverlayStyle.light,
            // Le titre est posé dans le fond plutôt que dans la barre :
            // `FlexibleSpaceBar` le recentre en se repliant, ce qui le
            // faisait déborder à gauche sur les écrans étroits.
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.blueDark,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Mes Tâches',
                          style: TextStyle(
                            fontSize: 26,
                            height: 1.1,
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    Icon(Icons.task_alt, size: 64, color: AppColors.line),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFilter == 'all'
                          ? 'Aucune tache assignee'
                          : 'Aucune tache dans cette categorie',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.inkMuted,
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
          color: isSelected ? AppColors.blue : AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(
            color: isSelected ? AppColors.blue : AppColors.line,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? AppColors.white : AppColors.inkMuted,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Brutal.radius)),
        child: InkWell(
          onTap: () => _showTaskDetail(task),
          borderRadius: BorderRadius.circular(Brutal.radius),
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
                    borderRadius: BorderRadius.circular(Brutal.radius),
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
                              color: AppColors.inkMuted,
                            ),
                          ),
                          if (task.hasPenalty) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.monetization_on,
                              size: 12,
                              color: task.penaltyApproved ? AppColors.danger : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              task.formattedPenalty,
                              style: TextStyle(
                                fontSize: 12,
                                color: task.penaltyApproved ? AppColors.danger : AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (task.dueDate != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: task.isOverdue ? AppColors.danger : AppColors.inkMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${task.dueDate!.day}/${task.dueDate!.month}',
                              style: TextStyle(
                                fontSize: 12,
                                color: task.isOverdue ? AppColors.danger : AppColors.inkMuted,
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
                Icon(Icons.chevron_right, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
