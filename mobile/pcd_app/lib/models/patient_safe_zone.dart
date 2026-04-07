class PatientSafeZone {
  const PatientSafeZone({
    required this.patientId,
    required this.originLatitude,
    required this.originLongitude,
    required this.radiusMeters,
    this.updatedAt,
    this.updatedBy,
  });

  final int patientId;
  final double originLatitude;
  final double originLongitude;
  final double radiusMeters;
  final DateTime? updatedAt;
  final int? updatedBy;

  factory PatientSafeZone.fromJson(Map<String, dynamic> json) {
    return PatientSafeZone(
      patientId: _parseInt(json['patient_id']) ?? 0,
      originLatitude: (json['origin_latitude'] as num).toDouble(),
      originLongitude: (json['origin_longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      updatedAt: _parseDateTime(json['updated_at']),
      updatedBy: _parseInt(json['updated_by']),
    );
  }

  String get formattedOrigin =>
      '${originLatitude.toStringAsFixed(6)}, ${originLongitude.toStringAsFixed(6)}';

  String get formattedRadius {
    final meters = radiusMeters;
    if (meters % 1 == 0) {
      return '${meters.toInt()} m';
    }
    return '${meters.toStringAsFixed(1)} m';
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed?.toLocal();
  }
}
