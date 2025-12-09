class Role {
  final int id;
  final String name;
  final String displayName;
  final String? description;

  Role({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'],
      name: json['name'] ?? '',
      displayName: json['display_name'] ?? '',
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'description': description,
    };
  }
}
