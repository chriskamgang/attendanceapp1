import 'package:flutter/material.dart';

/// Profil de l'utilisateur connecté.
///
/// Il n'est jamais choisi dans l'application : le backend renvoie un flag
/// `is_driver` après vérification de l'OTP. Les chauffeurs sont créés
/// depuis le back-office admin, jamais par inscription publique.
enum UserRole { student, driver }

extension UserRoleX on UserRole {
  bool get isDriver => this == UserRole.driver;

  String get label => switch (this) {
    UserRole.student => 'Étudiant',
    UserRole.driver => 'Chauffeur',
  };

  IconData get icon => switch (this) {
    UserRole.student => Icons.school_rounded,
    UserRole.driver => Icons.directions_bus_filled_rounded,
  };

  /// Rôle renvoyé par l'API (`etudiant`, `chauffeur`).
  ///
  /// Toute autre valeur — gestionnaire, admin — n'a pas d'espace mobile :
  /// elle est ramenée au profil étudiant, le plus restreint.
  static UserRole fromApi(String? value) => switch (value) {
    'chauffeur' => UserRole.driver,
    _ => UserRole.student,
  };
}
