class AppointmentItem {
  const AppointmentItem({
    required this.id,
    required this.patientId,
    required this.patientFirstName,
    required this.patientLastName,
    required this.dateTime,
    required this.status,
    this.notes,
  });

  final int id;
  final int patientId;
  final String patientFirstName;
  final String patientLastName;
  final DateTime dateTime;
  final String status;
  final String? notes;

  static const statusScheduled = 'scheduled';
  static const statusDone = 'done';
  static const statusCancelled = 'cancelled';
  static const statusMissed = 'missed';
  static const statusCompleted = statusDone;

  String get patientName {
    final fullName = '$patientFirstName $patientLastName'.trim();
    return fullName.isEmpty ? 'Patient #$patientId' : fullName;
  }

  String get timeLabel {
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get dateLabel {
    final d = dateTime.day.toString().padLeft(2, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    return '$d/$m/${dateTime.year}';
  }

  String get normalizedStatus => normalizeStatus(status);

  // Fallback business rule in UI: if backend did not compute "missed" yet.
  String get effectiveStatus {
    final normalized = normalizedStatus;
    if (
        normalized == statusDone ||
        normalized == statusCancelled ||
        normalized == statusMissed
    ) {
      return normalized;
    }

    final missedThreshold = dateTime.add(const Duration(days: 1));
    final now = DateTime.now();
    if (!now.isBefore(missedThreshold)) {
      return statusMissed;
    }
    return statusScheduled;
  }

  bool get canMarkCompleted =>
      effectiveStatus == statusScheduled || effectiveStatus == statusMissed;

  String get statusLabelFr {
    switch (effectiveStatus) {
      case statusDone:
        return 'Termine';
      case statusCancelled:
        return 'Annule';
      case statusMissed:
        return 'Manque';
      case statusScheduled:
      default:
        return 'Planifie';
    }
  }

  static String normalizeStatus(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'done' || value == 'completed' || value == 'termine') {
      return statusDone;
    }
    if (value == 'cancelled' || value == 'canceled' || value == 'annule') {
      return statusCancelled;
    }
    if (value == 'missed' || value == 'manque') {
      return statusMissed;
    }
    return statusScheduled;
  }
}
