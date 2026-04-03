class PatientAllergy {
  const PatientAllergy({
    required this.id,
    required this.patientId,
    this.doctorId,
    required this.allergen,
    this.reaction,
    this.severity = severityModerate,
    this.notes,
    this.createdAt,
  });

  static const severityLow = 'low';
  static const severityModerate = 'moderate';
  static const severityHigh = 'high';
  static const severityCritical = 'critical';

  final int id;
  final int patientId;
  final int? doctorId;
  final String allergen;
  final String? reaction;
  final String severity;
  final String? notes;
  final DateTime? createdAt;

  factory PatientAllergy.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final patientId = _parseInt(json['patient_id']);
    final doctorId = _parseInt(json['doctor_id']);
    final allergen = json['allergen']?.toString().trim() ?? '';
    final createdAtRaw = json['created_at']?.toString();
    final createdAt = createdAtRaw == null
        ? null
        : DateTime.tryParse(createdAtRaw);

    if (id == null || patientId == null || allergen.isEmpty) {
      throw const FormatException('Allergy payload is missing required fields');
    }

    return PatientAllergy(
      id: id,
      patientId: patientId,
      doctorId: doctorId,
      allergen: allergen,
      reaction: _nullableText(json['reaction']),
      severity: normalizeSeverity(json['severity']?.toString()),
      notes: _nullableText(json['notes']),
      createdAt: createdAt?.toLocal(),
    );
  }

  String get normalizedSeverity => normalizeSeverity(severity);

  String get severityLabelFr {
    switch (normalizedSeverity) {
      case severityLow:
        return 'Faible';
      case severityHigh:
        return 'Elevee';
      case severityCritical:
        return 'Critique';
      case severityModerate:
      default:
        return 'Moderee';
    }
  }

  static String normalizeSeverity(String? rawSeverity) {
    final value = (rawSeverity ?? '').trim().toLowerCase();
    switch (value) {
      case severityLow:
      case severityHigh:
      case severityCritical:
      case severityModerate:
        return value;
      default:
        return severityModerate;
    }
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
