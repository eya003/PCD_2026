class MedicationIntake {
  const MedicationIntake({
    required this.id,
    required this.medicationId,
    required this.validatedBy,
    required this.takenAt,
    required this.status,
    this.comment,
  });

  static const statusTaken = 'taken';
  static const statusMissed = 'missed';

  final int id;
  final int medicationId;
  final int validatedBy;
  final DateTime takenAt;
  final String status;
  final String? comment;

  factory MedicationIntake.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final medicationId = _parseInt(json['medication_id']);
    final validatedBy = _parseInt(json['validated_by']);
    final takenAtRaw = json['taken_at']?.toString();
    final takenAt = takenAtRaw == null ? null : DateTime.tryParse(takenAtRaw);
    final status = normalizeStatus(json['status']?.toString());

    if (id == null ||
        medicationId == null ||
        validatedBy == null ||
        takenAt == null) {
      throw const FormatException('Medication intake payload is invalid');
    }

    return MedicationIntake(
      id: id,
      medicationId: medicationId,
      validatedBy: validatedBy,
      takenAt: takenAt.toLocal(),
      status: status,
      comment: _nullableText(json['comment']),
    );
  }

  String get normalizedStatus => normalizeStatus(status);
  bool get isTaken => normalizedStatus == statusTaken;
  bool get isMissed => normalizedStatus == statusMissed;

  String get statusLabelFr {
    switch (normalizedStatus) {
      case statusMissed:
        return 'Manque';
      case statusTaken:
      default:
        return 'Pris';
    }
  }

  static String normalizeStatus(String? rawStatus) {
    final value = (rawStatus ?? '').trim().toLowerCase();
    if (value == statusMissed || value == 'manque') {
      return statusMissed;
    }
    return statusTaken;
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
