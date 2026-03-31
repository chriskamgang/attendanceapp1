class Task {
  final int id;
  final String title;
  final String? description;
  final String priority; // low, medium, high
  final String status; // pending, in_progress, completed, cancelled
  final int penaltyAmount; // montant de la pénalité en FCFA
  final String myStatus; // pivot: pending, in_progress, completed
  final String? myNote;
  final DateTime? completedAt;
  final bool penaltyApproved;
  final DateTime? dueDate;
  final String? creatorName;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    this.penaltyAmount = 0,
    required this.myStatus,
    this.myNote,
    this.completedAt,
    this.penaltyApproved = false,
    this.dueDate,
    this.creatorName,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'pending',
      penaltyAmount: json['penalty_amount'] ?? 0,
      myStatus: json['my_status'] ?? 'pending',
      myNote: json['my_note'],
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at']).toLocal()
          : null,
      penaltyApproved: json['penalty_approved'] ?? false,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : null,
      creatorName: json['creator_name'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      myStatus != 'completed';

  bool get hasPenalty => penaltyAmount > 0;

  String get formattedPenalty =>
      '${penaltyAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} FCFA';

  String get priorityLabel {
    switch (priority) {
      case 'high':
        return 'Haute';
      case 'medium':
        return 'Moyenne';
      case 'low':
        return 'Basse';
      default:
        return priority;
    }
  }

  String get myStatusLabel {
    switch (myStatus) {
      case 'pending':
        return 'En attente';
      case 'in_progress':
        return 'En cours';
      case 'completed':
        return 'Terminee';
      default:
        return myStatus;
    }
  }
}
