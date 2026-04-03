class Prescription {
  const Prescription({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.prescriptionDate,
    this.notes,
    this.status = statusActive,
    this.createdAt,
  });

  static const statusActive = 'active';
  static const statusCompleted = 'completed';
  static const statusCancelled = 'cancelled';

  final int id;
  final int patientId;
  final int doctorId;
  final DateTime prescriptionDate;
  final String? notes;
  final String status;
  final DateTime? createdAt;

  factory Prescription.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final patientId = _parseInt(json['patient_id']);
    final doctorId = _parseInt(json['doctor_id']);
    final prescriptionDateRaw = json['prescription_date']?.toString();
    final prescriptionDate = prescriptionDateRaw == null
        ? null
        : DateTime.tryParse(prescriptionDateRaw);
    final createdAtRaw = json['created_at']?.toString();
    final createdAt = createdAtRaw == null
        ? null
        : DateTime.tryParse(createdAtRaw);

    if (id == null ||
        patientId == null ||
        doctorId == null ||
        prescriptionDate == null) {
      throw const FormatException(
        'Prescription payload is missing required fields',
      );
    }

    return Prescription(
      id: id,
      patientId: patientId,
      doctorId: doctorId,
      prescriptionDate: prescriptionDate.toLocal(),
      notes: _nullableText(json['notes']),
      status: normalizeStatus(json['status']?.toString()),
      createdAt: createdAt?.toLocal(),
    );
  }

  String get normalizedStatus => normalizeStatus(status);

  String get statusLabelFr {
    switch (normalizedStatus) {
      case statusCompleted:
        return 'Terminee';
      case statusCancelled:
        return 'Annulee';
      case statusActive:
      default:
        return 'Active';
    }
  }

  static String normalizeStatus(String? rawStatus) {
    final value = (rawStatus ?? '').trim().toLowerCase();
    if (value == statusCompleted || value == 'done' || value == 'termine') {
      return statusCompleted;
    }
    if (value == statusCancelled ||
        value == 'cancel' ||
        value == 'annule') {
      return statusCancelled;
    }
    return statusActive;
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
