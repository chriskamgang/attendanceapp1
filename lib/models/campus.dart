class Campus {
  final int id;
  final String name;
  final String? code;
  final String address;
  final double latitude;
  final double longitude;
  final int radius;
  final String startTime;
  final String endTime;
  final int lateTolerance;
  final List<String> workingDays;
  final bool isActive;

  Campus({
    required this.id,
    required this.name,
    this.code,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.startTime,
    required this.endTime,
    required this.lateTolerance,
    this.workingDays = const [],
    this.isActive = true,
  });

  factory Campus.fromJson(Map<String, dynamic> json) {
    return Campus(
      id: json['id'],
      name: json['name'] ?? '',
      code: json['code'],
      address: json['address'] ?? '',
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      radius: json['radius'] ?? 100,
      startTime: json['start_time'] ?? '08:00:00',
      endTime: json['end_time'] ?? '17:00:00',
      lateTolerance: json['late_tolerance'] ?? 15,
      workingDays: json['working_days'] != null
          ? List<String>.from(json['working_days'])
          : [],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'start_time': startTime,
      'end_time': endTime,
      'late_tolerance': lateTolerance,
      'working_days': workingDays,
      'is_active': isActive,
    };
  }

  String getFormattedStartTime() {
    return startTime.substring(0, 5); // HH:mm
  }

  String getFormattedEndTime() {
    return endTime.substring(0, 5); // HH:mm
  }
}
