import 'pickup_point.dart';
import 'user_role.dart';

/// Utilisateur connecté, tel que le renvoie l'API.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.matricule = '',
    this.pickup,
    this.profileComplete = false,
  });

  /// Identifiant côté backend ; 0 tant que le compte n'existe pas.
  final int id;
  final String email;
  final UserRole role;
  final String firstName;
  final String lastName;
  final String phone;

  /// Vide si l'étudiant a coché « j'ai oublié mon matricule ».
  final String matricule;
  final PickupPoint? pickup;

  /// Verdict du backend : lui seul décide si le profil est exploitable.
  ///
  /// L'application n'en juge pas elle-même, pour que la règle reste au
  /// même endroit des deux côtés.
  final bool profileComplete;

  String get fullName => '$firstName $lastName'.trim();

  bool get needsProfileCompletion => !profileComplete;

  /// Construit l'utilisateur depuis `{"profil_complet": …, "utilisateur": …}`.
  factory AppUser.fromApi(Map<String, dynamic> json) {
    final user = (json['utilisateur'] as Map<String, dynamic>?) ?? json;
    final etudiant = user['etudiant'] as Map<String, dynamic>?;
    final lieu = etudiant?['lieu_ramassage'] as Map<String, dynamic>?;

    return AppUser(
      id: (user['id'] as num?)?.toInt() ?? 0,
      email: user['email'] as String? ?? '',
      role: UserRoleX.fromApi(user['role'] as String?),
      firstName: user['prenom'] as String? ?? '',
      lastName: user['nom'] as String? ?? '',
      phone: user['telephone'] as String? ?? '',
      matricule: etudiant?['matricule_insam'] as String? ?? '',
      pickup: lieu == null ? null : PickupPoint.fromJson(lieu),
      profileComplete: json['profil_complet'] as bool? ?? false,
    );
  }

  AppUser copyWith({
    int? id,
    String? email,
    UserRole? role,
    String? firstName,
    String? lastName,
    String? phone,
    String? matricule,
    PickupPoint? pickup,
    bool? profileComplete,
  }) => AppUser(
    id: id ?? this.id,
    email: email ?? this.email,
    role: role ?? this.role,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    phone: phone ?? this.phone,
    matricule: matricule ?? this.matricule,
    pickup: pickup ?? this.pickup,
    profileComplete: profileComplete ?? this.profileComplete,
  );
}
