class AcademicResult {
  final int id;
  final int userId;
  final String title;
  final String? description;
  final String filePath;
  final String type;
  final int? semester;
  final String? academicYear;
  final DateTime createdAt;

  AcademicResult({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.filePath,
    required this.type,
    this.semester,
    this.academicYear,
    required this.createdAt,
  });

  factory AcademicResult.fromJson(Map<String, dynamic> json) {
    return AcademicResult(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      filePath: json['file_path'],
      type: json['type'],
      semester: json['semester'],
      academicYear: json['academic_year'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'file_path': filePath,
      'type': type,
      'semester': semester,
      'academic_year': academicYear,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String getFileUrl(String baseUrl) {
    if (filePath.isEmpty) return '';
    if (filePath.startsWith('http')) return filePath;
    return '$baseUrl/storage/$filePath';
  }
}
