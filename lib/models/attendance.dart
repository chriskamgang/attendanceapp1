import 'campus.dart';
import 'unite_enseignement.dart';

class Attendance {
  final int id;
  final int userId;
  final int campusId;
  final int? uniteEnseignementId;
  final String type; // check_in ou check_out
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final bool isLate;
  final int lateMinutes;
  final String status;
  final Campus? campus;
  final UniteEnseignement? uniteEnseignement;

  Attendance({
    required this.id,
    required this.userId,
    required this.campusId,
    this.uniteEnseignementId,
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.isLate = false,
    this.lateMinutes = 0,
    this.status = 'verified',
    this.campus,
    this.uniteEnseignement,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      userId: json['user_id'],
      campusId: json['campus_id'],
      uniteEnseignementId: json['unite_enseignement_id'],
      type: json['type'] ?? 'check-in',
      timestamp: DateTime.parse(json['timestamp']),
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      accuracy: json['accuracy'] != null
          ? double.parse(json['accuracy'].toString())
          : null,
      isLate: json['is_late'] ?? false,
      lateMinutes: json['late_minutes'] ?? 0,
      status: json['status'] ?? 'verified',
      campus: json['campus'] != null ? Campus.fromJson(json['campus']) : null,
      uniteEnseignement: json['unite_enseignement'] != null
          ? UniteEnseignement.fromJson(json['unite_enseignement'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'campus_id': campusId,
      'unite_enseignement_id': uniteEnseignementId,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'is_late': isLate,
      'late_minutes': lateMinutes,
      'status': status,
      'campus': campus?.toJson(),
      'unite_enseignement': uniteEnseignement?.toJson(),
    };
  }

  bool isCheckIn() => type == 'check-in';
  bool isCheckOut() => type == 'check-out';

  String getFormattedTime() {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  String getFormattedDate() {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
