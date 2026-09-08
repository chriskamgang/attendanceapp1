/// Étapes du cycle de pointage d'une tournée (CDC §3.2).
///
/// Le cycle est strictement séquentiel : le chauffeur ne peut valider une
/// étape que si la précédente l'est déjà. Le backend en est seul juge —
/// l'étape lue ici est déduite du statut du tour et de ses horodatages,
/// jamais avancée localement.
enum TourStage {
  /// Service non démarré : le chauffeur n'a pas encore activé sa journée.
  offline,

  /// 1. Démarrage service — GPS diffusé, bus en route vers le ramassage.
  serviceStarted,

  /// 2. Arrivée au point de ramassage — statut « En attente / Embarquement ».
  atPickup,

  /// 3. Effectif saisi — le nombre d'étudiants montés est enregistré.
  headcountDone,

  /// 4. Départ vers le campus — statut « En transit ».
  toCampus,

  /// 5. Arrivée au campus — tour validé, compteur incrémenté.
  finished,
}

extension TourStageX on TourStage {
  /// Rang de l'étape dans le cycle, pour comparer les positions.
  int get step => index;

  String get label => switch (this) {
    TourStage.offline => 'Service non démarré',
    TourStage.serviceStarted => 'En route vers le point',
    TourStage.atPickup => 'À l’arrêt — embarquement',
    TourStage.headcountDone => 'Effectif enregistré',
    TourStage.toCampus => 'En transit vers le campus',
    TourStage.finished => 'Tour terminé',
  };

  /// Libellé du bouton qui fait avancer le cycle depuis cette étape.
  String get nextActionLabel => switch (this) {
    TourStage.offline => 'Démarrer le service',
    TourStage.serviceStarted => 'Arrivé au point',
    TourStage.atPickup => 'Saisir l’effectif',
    TourStage.headcountDone => 'Départ vers le campus',
    TourStage.toCampus => 'Terminé — arrivé au campus',
    TourStage.finished => 'Lancer le tour suivant',
  };

  /// Le service diffuse la position tant que le tour n'est pas clos.
  bool get isLive =>
      this != TourStage.offline && this != TourStage.finished;

  /// Étapes soumises au contrôle de zone géographique (CDC §3.4).
  ///
  /// Démarrer le service et saisir l'effectif n'en dépendent pas : le
  /// premier se fait au dépôt, le second dans le bus une fois à l'arrêt.
  /// Le contrôle reste tranché par le backend ; ce drapeau ne sert qu'à
  /// prévenir le chauffeur avant qu'il n'appuie.
  bool get requiresGeofence =>
      this == TourStage.serviceStarted ||
      this == TourStage.headcountDone ||
      this == TourStage.toCampus;

  /// Cible du contrôle de zone : l'arrêt tant que le bus embarque, le
  /// terminus une fois en transit.
  bool get targetsTerminus => this == TourStage.toCampus;

  /// Étape déduite de l'état renvoyé par le backend.
  ///
  /// Le statut seul ne suffit pas : « embarquement » couvre aussi bien
  /// l'arrivée au point que la saisie de l'effectif, que seul le champ
  /// `effectif_embarque` distingue.
  static TourStage fromApi({
    required String statut,
    required bool hasHeadcount,
  }) => switch (statut) {
    'en_attente' => TourStage.serviceStarted,
    'embarquement' => hasHeadcount ? TourStage.headcountDone : TourStage.atPickup,
    'en_transit' => TourStage.toCampus,
    'termine' => TourStage.finished,
    _ => TourStage.offline,
  };
}
