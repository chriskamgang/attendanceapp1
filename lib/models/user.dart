import 'role.dart';
import 'department.dart';
import 'campus.dart';

class User {
  final int id;
  final String? employeeId;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String? phone;
  final String? photo;
  final String employeeType;
  final String? specialite;
  final String? niveau;
  final double? hourlyRate;
  final double? monthlySalary;
  final double? volumeHoraireHebdomadaire;
  final List<String>? joursTravail;
  final Role? role;
  final Department? department;
  final List<Campus> campuses;
  final bool isActive;
  final DateTime? createdAt;

  User({
    required this.id,
    this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    this.phone,
    this.photo,
    required this.employeeType,
    this.specialite,
    this.niveau,
    this.hourlyRate,
    this.monthlySalary,
    this.volumeHoraireHebdomadaire,
    this.joursTravail,
    this.role,
    this.department,
    this.campuses = const [],
    this.isActive = true,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      employeeId: json['employee_id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      photo: json['photo'],
      employeeType: json['employee_type'] ?? '',
      specialite: json['specialite'],
      niveau: json['niveau'],
      hourlyRate: json['hourly_rate'] != null
          ? double.tryParse(json['hourly_rate'].toString())
          : null,
      monthlySalary: json['monthly_salary'] != null
          ? double.tryParse(json['monthly_salary'].toString())
          : null,
      volumeHoraireHebdomadaire: json['volume_horaire_hebdomadaire'] != null
          ? double.tryParse(json['volume_horaire_hebdomadaire'].toString())
          : null,
      joursTravail: json['jours_travail'] != null
          ? List<String>.from(json['jours_travail'])
          : null,
      role: json['role'] != null ? Role.fromJson(json['role']) : null,
      department: json['department'] != null
          ? Department.fromJson(json['department'])
          : null,
      campuses: json['campuses'] != null
          ? (json['campuses'] as List)
              .map((campus) => Campus.fromJson(campus))
              .toList()
          : [],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'photo': photo,
      'employee_type': employeeType,
      'specialite': specialite,
      'niveau': niveau,
      'hourly_rate': hourlyRate,
      'monthly_salary': monthlySalary,
      'volume_horaire_hebdomadaire': volumeHoraireHebdomadaire,
      'jours_travail': joursTravail,
      'role': role?.toJson(),
      'department': department?.toJson(),
      'campuses': campuses.map((c) => c.toJson()).toList(),
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String getPhotoUrl(String baseUrl) {
    if (photo == null || photo!.isEmpty) return '';
    if (photo!.startsWith('http')) return photo!;
    return '$baseUrl/storage/$photo';
  }

  bool isVacataire() => employeeType == 'enseignant_vacataire';
  bool isSemiPermanent() => employeeType == 'semi_permanent';
  bool isTitulaire() => employeeType == 'enseignant_titulaire';
  bool isAdministratif() => employeeType == 'administratif';
  bool isTechnique() => employeeType == 'technique';
  bool isDirection() => employeeType == 'direction';
  bool isStudent() => employeeType == 'etudiant';

  String getJoursTravailFormatted() {
    if (joursTravail == null || joursTravail!.isEmpty) {
      return 'Non défini';
    }
    return joursTravail!.map((j) => j[0].toUpperCase() + j.substring(1)).join(', ');
  }

  bool travailleAujourdhui() {
    if (joursTravail == null || joursTravail!.isEmpty) return true;

    final aujourdhui = DateTime.now().weekday;
    final joursFr = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
    final jourActuel = joursFr[aujourdhui - 1];

    return joursTravail!.map((j) => j.toLowerCase()).contains(jourActuel);
  }
}
