import 'student_pass.dart';

/// Jeton QR d'un pass, présenté au chauffeur à la montée (CDC §3.1).
///
/// Le jeton est signé par le backend et tourne toutes les 30 secondes :
/// l'application ne le fabrique pas, elle l'affiche et le renouvelle.
///
/// Chaque pass porte le sien : l'étudiant qui en détient plusieurs montre
/// celui qu'il veut voir débité, et le scan ne peut pas se tromper de titre.
class PassQr {
  const PassQr({
    required this.token,
    required this.expiresAt,
    required this.validitySeconds,
    this.pass,
  });

  final String token;
  final DateTime expiresAt;
  final int validitySeconds;

  /// Le pass que ce QR désigne ; `null` sur une réponse sans détail.
  final StudentPass? pass;

  /// Temps restant avant que le jeton ne devienne caduc, jamais négatif.
  Duration get remaining {
    final reste = expiresAt.difference(DateTime.now());
    return reste.isNegative ? Duration.zero : reste;
  }

  bool get isExpired => remaining == Duration.zero;

  /// Part de la durée de vie encore devant nous, pour l'anneau de progression.
  double get progress {
    if (validitySeconds <= 0) return 0;
    return (remaining.inMilliseconds / (validitySeconds * 1000)).clamp(0.0, 1.0);
  }

  factory PassQr.fromJson(Map<String, dynamic> json) => PassQr(
    token: json['jeton'] as String? ?? '',
    expiresAt:
        DateTime.tryParse(json['expire_le'] as String? ?? '') ??
        DateTime.now(),
    validitySeconds: (json['validite_secondes'] as num?)?.toInt() ?? 30,
    pass: json['abonnement'] is Map<String, dynamic>
        ? StudentPass.fromJson(json['abonnement'] as Map<String, dynamic>)
        : null,
  );

  /// Les QR renvoyés par `pass/qr`, un par pass utilisable.
  ///
  /// L'échéance et la durée de validité sont communes à tous : ils sont
  /// émis dans le même créneau et tournent ensemble.
  static List<PassQr> listFromJson(Map<String, dynamic> json) {
    final expire =
        DateTime.tryParse(json['expire_le'] as String? ?? '') ?? DateTime.now();
    final validite = (json['validite_secondes'] as num?)?.toInt() ?? 30;

    return (json['pass'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => PassQr(
            token: e['jeton'] as String? ?? '',
            expiresAt: expire,
            validitySeconds: validite,
            pass: e['abonnement'] is Map<String, dynamic>
                ? StudentPass.fromJson(e['abonnement'] as Map<String, dynamic>)
                : null,
          ),
        )
        .toList();
  }
}
