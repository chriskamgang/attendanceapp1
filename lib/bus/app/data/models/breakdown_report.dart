import 'package:flutter/material.dart';

/// Nature de la panne déclarée par le chauffeur (CDC §3.3).
enum BreakdownKind { mechanical, tyre, fuel, accident, other }

extension BreakdownKindX on BreakdownKind {
  String get label => switch (this) {
    BreakdownKind.mechanical => 'Panne moteur',
    BreakdownKind.tyre => 'Crevaison',
    BreakdownKind.fuel => 'Panne de carburant',
    BreakdownKind.accident => 'Accident',
    BreakdownKind.other => 'Autre',
  };

  IconData get icon => switch (this) {
    BreakdownKind.mechanical => Icons.build_rounded,
    BreakdownKind.tyre => Icons.tire_repair_rounded,
    BreakdownKind.fuel => Icons.local_gas_station_rounded,
    BreakdownKind.accident => Icons.car_crash_rounded,
    BreakdownKind.other => Icons.report_problem_rounded,
  };

  /// Valeur attendue par l'API (`type_panne`).
  String get apiValue => switch (this) {
    BreakdownKind.mechanical => 'mecanique',
    BreakdownKind.tyre => 'pneu',
    BreakdownKind.fuel => 'carburant',
    BreakdownKind.accident => 'accident',
    BreakdownKind.other => 'autre',
  };

  static BreakdownKind fromApi(String? value) => switch (value) {
    'mecanique' => BreakdownKind.mechanical,
    'pneu' => BreakdownKind.tyre,
    'carburant' => BreakdownKind.fuel,
    'accident' => BreakdownKind.accident,
    _ => BreakdownKind.other,
  };
}

/// Suivi d'une panne déclarée, du signalement à la prise en charge.
enum BreakdownStatus { reported, rescueAssigned, resolved, cancelled }

extension BreakdownStatusX on BreakdownStatus {
  String get label => switch (this) {
    BreakdownStatus.reported => 'Signalée — en attente de secours',
    BreakdownStatus.rescueAssigned => 'Secours affecté',
    BreakdownStatus.resolved => 'Résolue',
    BreakdownStatus.cancelled => 'Annulée',
  };

  static BreakdownStatus fromApi(String? value) => switch (value) {
    'prise_en_charge' => BreakdownStatus.rescueAssigned,
    'resolue' => BreakdownStatus.resolved,
    'annulee' => BreakdownStatus.cancelled,
    _ => BreakdownStatus.reported,
  };
}

/// Déclaration de panne émise par le chauffeur en difficulté.
class BreakdownReport {
  const BreakdownReport({
    required this.id,
    required this.kind,
    required this.status,
    required this.reportedAt,
    required this.studentsOnBoard,
    this.note = '',
    this.rescueDriverName = '',
    this.busPlate = '',
  });

  final String id;
  final BreakdownKind kind;
  final BreakdownStatus status;
  final DateTime reportedAt;

  /// Étudiants immobilisés à bord — dimensionne le bus de secours.
  final int studentsOnBoard;
  final String note;

  /// Chauffeur envoyé en renfort, une fois la mission affectée.
  final String rescueDriverName;

  final String busPlate;

  factory BreakdownReport.fromApi(Map<String, dynamic> json) {
    final bus = json['bus'] as Map<String, dynamic>?;

    return BreakdownReport(
      id: '${json['id'] ?? ''}',
      kind: BreakdownKindX.fromApi(json['type_panne'] as String?),
      status: BreakdownStatusX.fromApi(json['statut'] as String?),
      reportedAt:
          DateTime.tryParse(json['declaree_le'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      studentsOnBoard: (json['passagers_immobilises'] as num?)?.toInt() ?? 0,
      note: json['description'] as String? ?? '',
      busPlate: bus?['immatriculation'] as String? ?? '',
    );
  }

  BreakdownReport copyWith({
    BreakdownStatus? status,
    String? rescueDriverName,
  }) => BreakdownReport(
    id: id,
    kind: kind,
    status: status ?? this.status,
    reportedAt: reportedAt,
    studentsOnBoard: studentsOnBoard,
    note: note,
    rescueDriverName: rescueDriverName ?? this.rescueDriverName,
    busPlate: busPlate,
  );
}

/// Étapes d'une mission de secours côté chauffeur secouriste.
enum MissionStage { assigned, accepted, enRoute, done, cancelled }

extension MissionStageX on MissionStage {
  String get label => switch (this) {
    MissionStage.assigned => 'À accepter',
    MissionStage.accepted => 'Acceptée',
    MissionStage.enRoute => 'En route',
    MissionStage.done => 'Terminée',
    MissionStage.cancelled => 'Annulée',
  };

  static MissionStage fromApi(String? value) => switch (value) {
    'acceptee' => MissionStage.accepted,
    'en_route' => MissionStage.enRoute,
    'terminee' => MissionStage.done,
    'annulee' => MissionStage.cancelled,
    _ => MissionStage.assigned,
  };
}

/// Mission de secours proposée par la régulation à un chauffeur disponible
/// (CDC §3.3 — prime forfaitaire de 2 000 FCFA par intervention).
class RescueMission {
  const RescueMission({
    required this.id,
    required this.strandedDriverName,
    required this.lineName,
    required this.location,
    required this.studentsToCollect,
    required this.kind,
    required this.receivedAt,
    required this.reward,
    this.accepted = false,
    this.stage = MissionStage.assigned,
    this.latitude,
    this.longitude,
    this.rescuedCount,
  });

  final String id;
  final String strandedDriverName;
  final String lineName;

  /// Repère du lieu d'immobilisation, tel qu'affiché au chauffeur.
  final String location;
  final int studentsToCollect;
  final BreakdownKind kind;
  final DateTime receivedAt;

  /// Prime versée pour l'intervention, en FCFA.
  final int reward;
  final bool accepted;

  final MissionStage stage;

  /// Position du bus en panne, pour guider le secours.
  final double? latitude;
  final double? longitude;

  /// Passagers effectivement récupérés, une fois la mission close.
  final int? rescuedCount;

  /// La mission est close : ni à accepter, ni à mener.
  bool get isClosed =>
      stage == MissionStage.done || stage == MissionStage.cancelled;

  factory RescueMission.fromApi(Map<String, dynamic> json) {
    final panne = json['panne'] as Map<String, dynamic>? ?? const {};
    final busEnPanne = panne['bus'] as Map<String, dynamic>?;
    final stage = MissionStageX.fromApi(json['statut'] as String?);

    return RescueMission(
      id: '${json['id'] ?? ''}',
      // La régulation n'expose pas l'identité du chauffeur en difficulté :
      // le bus suffit à situer l'intervention.
      strandedDriverName: busEnPanne?['immatriculation'] as String? ?? 'Bus en panne',
      lineName: busEnPanne?['modele'] as String? ?? '',
      location: panne['description'] as String? ?? 'Position transmise par la régulation',
      studentsToCollect: (panne['passagers_immobilises'] as num?)?.toInt() ?? 0,
      kind: BreakdownKindX.fromApi(panne['type_panne'] as String?),
      receivedAt:
          DateTime.tryParse(json['affectee_le'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      reward: BonusRewards.rescue,
      accepted: stage != MissionStage.assigned,
      stage: stage,
      latitude: (panne['latitude'] as num?)?.toDouble(),
      longitude: (panne['longitude'] as num?)?.toDouble(),
      rescuedCount: (json['passagers_recuperes'] as num?)?.toInt(),
    );
  }

  RescueMission copyWith({bool? accepted, MissionStage? stage}) => RescueMission(
    id: id,
    strandedDriverName: strandedDriverName,
    lineName: lineName,
    location: location,
    studentsToCollect: studentsToCollect,
    kind: kind,
    receivedAt: receivedAt,
    reward: reward,
    accepted: accepted ?? this.accepted,
    stage: stage ?? this.stage,
    latitude: latitude,
    longitude: longitude,
    rescuedCount: rescuedCount,
  );
}

/// Montants forfaitaires affichés avec les missions (CDC §3.3).
abstract class BonusRewards {
  BonusRewards._();

  static const int rescue = 2000;
}
