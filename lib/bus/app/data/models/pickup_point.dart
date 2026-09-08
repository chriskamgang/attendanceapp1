/// Point de ramassage proposé à l'étudiant (CDC §3.1).
///
/// C'est la seule attache géographique de son profil : son campus, lui,
/// change d'un jour à l'autre selon l'emploi du temps, et n'est donc pas
/// enregistré.
class PickupPoint {
  const PickupPoint({
    required this.id,
    required this.name,
    this.address = '',
    this.lines = const [],
    this.latitude,
    this.longitude,
  });

  /// Identifiant du lieu (`lieu_ramassage_id` côté API).
  final String id;
  final String name;

  /// Repère affiché sous le nom : « Rond-point Banengo ».
  final String address;

  /// Lignes desservant ce point, telles que renvoyées par l'API.
  ///
  /// L'écran d'inscription ne les affiche pas — l'étudiant choisit un
  /// lieu, pas un itinéraire — mais le suivi du bus s'en sert.
  final List<String> lines;

  final double? latitude;
  final double? longitude;

  factory PickupPoint.fromJson(Map<String, dynamic> json) => PickupPoint(
    id: json['id'].toString(),
    name: json['nom'] as String? ?? '',
    address: json['adresse'] as String? ?? '',
    lines: (json['lignes'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((l) => l['nom'] as String? ?? '')
        .where((nom) => nom.isNotEmpty)
        .toList(),
    latitude: _toDouble(json['latitude']),
    longitude: _toDouble(json['longitude']),
  );

  /// L'API sérialise les décimales en nombre ou en chaîne selon le pilote
  /// de base de données.
  static double? _toDouble(Object? value) => switch (value) {
    num n => n.toDouble(),
    String s => double.tryParse(s),
    _ => null,
  };
}
