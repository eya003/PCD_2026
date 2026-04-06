class PatientLocation {
  const PatientLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });

  final int id;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;

  factory PatientLocation.fromJson(Map<String, dynamic> json) {
    final raw =
        json['recorded_at']?.toString() ??
        json['created_at']?.toString() ??
        json['timestamp']?.toString() ??
        '';
    return PatientLocation(
      id: _parseInt(json['id']) ?? 0,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      recordedAt: DateTime.tryParse(raw)?.toLocal() ?? DateTime.now(),
    );
  }

  /// Returns latitude and longitude formatted to 6 decimal places.
  String get formattedCoords =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  String get formattedDateTime {
    final d = recordedAt.day.toString().padLeft(2, '0');
    final m = recordedAt.month.toString().padLeft(2, '0');
    final h = recordedAt.hour.toString().padLeft(2, '0');
    final min = recordedAt.minute.toString().padLeft(2, '0');
    return '$d/$m/${recordedAt.year} $h:$min';
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
