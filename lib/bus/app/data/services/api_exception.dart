/// Erreur remontée par l'API, déjà traduite en message affichable.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.reason,
    this.errors = const {},
  });

  /// Message prêt à être montré à l'utilisateur.
  final String message;

  final int? statusCode;

  /// Code métier renvoyé par le backend (`code_expire`, `code_incorrect`…).
  final String? reason;

  /// Erreurs de validation, par champ.
  final Map<String, List<String>> errors;

  /// Le serveur est injoignable : ni réseau, ni backend démarré.
  const ApiException.offline()
    : message =
          'Impossible de joindre le serveur. '
          'Vérifie ta connexion et réessaie.',
      statusCode = null,
      reason = 'hors_ligne',
      errors = const {};

  /// Le token n'est plus valide : la session doit être fermée.
  bool get isUnauthenticated => statusCode == 401;

  /// Trop de requêtes : le backend impose un délai.
  bool get isThrottled => statusCode == 429;

  /// Premier message d'erreur du champ demandé, s'il y en a un.
  String? errorFor(String field) => errors[field]?.firstOrNull;

  @override
  String toString() => message;
}
