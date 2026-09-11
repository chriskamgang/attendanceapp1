/// Un trajet effectué, tel qu'affiché dans l'historique de l'étudiant.
class TripEntry {
  const TripEntry({
    required this.id,
    required this.date,
    required this.pickupName,
    required this.busLabel,
    required this.lineName,
    this.fare = 0,
    this.onTime = true,
  });

  final String id;
  final DateTime date;

  /// Point de ramassage emprunté ce jour-là.
  final String pickupName;
  final String busLabel;
  final String lineName;

  /// Montant débité en FCFA ; 0 quand le trajet est couvert par un pass.
  final int fare;

  /// Faux si le tour a accusé une anomalie de durée.
  final bool onTime;

  factory TripEntry.fromJson(Map<String, dynamic> json) {
    final tournee = json['tournee'] as Map<String, dynamic>?;
    final lieu = tournee?['lieu'] as Map<String, dynamic>?;
    final affectation = tournee?['affectation'] as Map<String, dynamic>?;
    final bus = affectation?['bus'] as Map<String, dynamic>?;
    final ligne = affectation?['ligne'] as Map<String, dynamic>?;
    final abonnement = json['abonnement'] as Map<String, dynamic>?;

    return TripEntry(
      id: json['id'].toString(),
      date:
          DateTime.tryParse(json['embarque_le'] as String? ?? '') ??
          DateTime.now(),
      pickupName: lieu?['nom'] as String? ?? '',
      busLabel: bus?['immatriculation'] as String? ?? '',
      lineName: ligne?['nom'] as String? ?? '',
      fare: (abonnement?['montant_paye_fcfa'] as num?)?.toInt() ?? 0,
      // Une anomalie de durée signale un tour hors des clous.
      onTime: !(tournee?['anomalie_duree'] as bool? ?? false),
    );
  }
}
