import 'package:flutter/material.dart';

/// Nature de l'alerte reçue par l'étudiant (CDC §3.1).
enum NotificationKind {
  /// Le bus a quitté le dépôt.
  departure,

  /// Retard annoncé sur la ligne.
  delay,

  /// Changement de véhicule affecté à la ligne.
  vehicleChange,

  /// Panne signalée sur le réseau (CDC §3.3).
  breakdown,

  /// Mission de secours confiée au chauffeur (CDC §3.3).
  rescue,

  /// Pass arrivant à échéance : à renouveler avant d'être refusé à bord.
  passExpiring,

  /// Information de service (maintenance, message de la régulation…).
  info,
}

extension NotificationKindX on NotificationKind {
  IconData get icon => switch (this) {
    NotificationKind.departure => Icons.play_circle_fill_rounded,
    NotificationKind.delay => Icons.schedule_rounded,
    NotificationKind.vehicleChange => Icons.swap_horiz_rounded,
    NotificationKind.breakdown => Icons.warning_amber_rounded,
    NotificationKind.rescue => Icons.support_agent_rounded,
    NotificationKind.passExpiring => Icons.confirmation_number_rounded,
    NotificationKind.info => Icons.info_rounded,
  };

  /// Type renvoyé par l'API ; toute valeur inconnue devient une information.
  static NotificationKind fromApi(String? value) => switch (value) {
    'depart_bus' => NotificationKind.departure,
    'retard' => NotificationKind.delay,
    'changement_vehicule' => NotificationKind.vehicleChange,
    // Le backend distingue la panne remontée aux gestionnaires (« panne »)
    // de celle annoncée aux étudiants qui attendent (« breakdown ») ; les
    // deux s'affichent de la même façon.
    'panne' || 'breakdown' => NotificationKind.breakdown,
    'mission_secours' => NotificationKind.rescue,
    'pass_expire' => NotificationKind.passExpiring,
    _ => NotificationKind.info,
  };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime time;
  final bool read;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'].toString(),
        kind: NotificationKindX.fromApi(json['type'] as String?),
        title: json['titre'] as String? ?? '',
        body: json['message'] as String? ?? '',
        time:
            DateTime.tryParse(json['cree_le'] as String? ?? '') ??
            DateTime.now(),
        read: json['lue'] as bool? ?? false,
      );

  /// Reconstruit une alerte à partir du message FCM.
  ///
  /// Le push ne transporte que des chaînes : le titre et le corps viennent
  /// du bloc `notification`, l'identifiant et le type du bloc `data`. Une
  /// alerte reçue en push n'a par définition pas encore été lue.
  factory AppNotification.fromPush({
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) => AppNotification(
    id: data['notification_id']?.toString() ?? '',
    kind: NotificationKindX.fromApi(data['type'] as String?),
    title: title ?? '',
    body: body ?? '',
    time: DateTime.now(),
  );

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    time: time,
    read: read ?? this.read,
  );
}
