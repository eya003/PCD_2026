class PatientAlert {
  const PatientAlert({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  final int id;
  final String type;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  factory PatientAlert.fromJson(Map<String, dynamic> json) {
    final createdRaw =
        json['created_at']?.toString() ?? json['date']?.toString() ?? '';
    return PatientAlert(
      id: _parseInt(json['id']) ?? 0,
      type: json['type']?.toString() ?? 'info',
      message: json['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(createdRaw) ?? DateTime.now(),
      isRead: json['is_read'] == true || json['read'] == true,
    );
  }

  PatientAlert copyWith({bool? isRead}) => PatientAlert(
        id: id,
        type: type,
        message: message,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  String get typeLabelFr {
    switch (type.toLowerCase()) {
      case 'geofence_exit':
      case 'safe_zone_exit':
      case 'location_outside_safe_zone':
        return 'Localisation';
      case 'medication':
      case 'medication_missed':
        return 'Médicament';
      case 'appointment':
        return 'Rendez-vous';
      case 'emergency':
        return 'Urgence';
      case 'warning':
        return 'Avertissement';
      default:
        return 'Information';
    }
  }

  String get formattedDate {
    final d = createdAt.day.toString().padLeft(2, '0');
    final m = createdAt.month.toString().padLeft(2, '0');
    final h = createdAt.hour.toString().padLeft(2, '0');
    final min = createdAt.minute.toString().padLeft(2, '0');
    return '$d/$m/${createdAt.year} $h:$min';
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
