class Complaint {
  final int id;
  final int userId;
  final String subject;
  final String content;
  final String status;
  final String? adminResponse;
  final DateTime createdAt;
  final DateTime updatedAt;

  Complaint({
    required this.id,
    required this.userId,
    required this.subject,
    required this.content,
    required this.status,
    this.adminResponse,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'],
      userId: json['user_id'],
      subject: json['subject'],
      content: json['content'],
      status: json['status'],
      adminResponse: json['admin_response'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'subject': subject,
      'content': content,
      'status': status,
      'admin_response': adminResponse,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
