class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.patientId = 0,
    this.doctorId = 0,
    this.prescriptionId,
    this.form,
    this.quantity,
    this.period,
    this.instructions,
    this.status = statusActive,
  });

  static const statusActive = 'active';
  static const statusCompleted = 'completed';
  static const statusCancelled = 'cancelled';

  final int id;
  final int patientId;
  final int doctorId;
  final int? prescriptionId;
  final String name;
  final String dosage;
  final String? form;
  final String? quantity;
  final String frequency;
  final String? period;
  final DateTime startDate;
  final DateTime? endDate;
  final String? instructions;
  final String status;

  factory Medication.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final patientId = _parseInt(json['patient_id']) ?? 0;
    final doctorId = _parseInt(json['doctor_id']) ?? 0;
    final prescriptionId = _parseInt(json['prescription_id']);
    final name = json['name']?.toString().trim() ?? '';
    final dosage = json['dosage']?.toString().trim() ?? '';
    final frequency = json['frequency']?.toString().trim() ?? '';
    final startDateRaw = json['start_date']?.toString();
    final startDate = startDateRaw == null
        ? null
        : DateTime.tryParse(startDateRaw);
    final endDateRaw = json['end_date']?.toString();
    final endDate = endDateRaw == null ? null : DateTime.tryParse(endDateRaw);

    if (id == null ||
        startDate == null ||
        name.isEmpty ||
        dosage.isEmpty ||
        frequency.isEmpty) {
      throw const FormatException(
        'Medication payload is missing required fields',
      );
    }

    return Medication(
      id: id,
      patientId: patientId,
      doctorId: doctorId,
      prescriptionId: prescriptionId,
      name: name,
      dosage: dosage,
      form: _nullableText(json['form']),
      quantity: _nullableText(json['quantity']),
      frequency: frequency,
      period: _nullableText(json['period']),
      startDate: startDate.toLocal(),
      endDate: endDate?.toLocal(),
      instructions: _nullableText(json['instructions']),
      status: normalizeStatus(json['status']?.toString()),
    );
  }

  bool get isActive {
    if (normalizedStatus != statusActive) {
      return false;
    }
    final end = endDate;
    if (end == null) {
      return true;
    }
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    return !normalizedEnd.isBefore(normalizedToday);
  }

  bool get isCompleted => normalizedStatus == statusCompleted;
  bool get isCancelled => normalizedStatus == statusCancelled;
  bool get isArchived => isCompleted || isCancelled;
  bool get canMarkCompleted => isActive;
  bool get canCancel => isActive;

  String get normalizedStatus => normalizeStatus(status);

  String get statusLabelFr {
    switch (normalizedStatus) {
      case statusCompleted:
        return 'Termine';
      case statusCancelled:
        return 'Annule';
      case statusActive:
      default:
        return 'Actif';
    }
  }

  static String normalizeStatus(String? rawStatus) {
    final value = (rawStatus ?? '').trim().toLowerCase();
    if (value == statusCompleted || value == 'done' || value == 'termine') {
      return statusCompleted;
    }
    if (value == statusCancelled || value == 'cancel' || value == 'annule') {
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
