import 'campus.dart';

class PresenceCheck {
  final int id;
  final int userId;
  final int campusId;
  final DateTime checkTime;
  final String? response; // 'present' ou 'absent'
  final DateTime? responseTime;
  final double? latitude;
  final double? longitude;
  final bool? isInZone;
  final Campus? campus;

  PresenceCheck({
    required this.id,
    required this.userId,
    required this.campusId,
    required this.checkTime,
    this.response,
    this.responseTime,
    this.latitude,
    this.longitude,
    this.isInZone,
    this.campus,
  });

  factory PresenceCheck.fromJson(Map<String, dynamic> json) {
    return PresenceCheck(
      id: json['id'],
      userId: json['user_id'],
      campusId: json['campus_id'],
      checkTime: DateTime.parse(json['check_time']),
      response: json['response'],
      responseTime: json['response_time'] != null
          ? DateTime.parse(json['response_time'])
          : null,
      latitude: json['latitude'] != null
          ? double.parse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.parse(json['longitude'].toString())
          : null,
      isInZone: json['is_in_zone'],
      campus: json['campus'] != null ? Campus.fromJson(json['campus']) : null,
    );
  }

  bool isPending() => response == null;
  bool isResponded() => response != null;
}
