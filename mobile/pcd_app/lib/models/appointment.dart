enum AppointmentStatus { scheduled, done, cancelled }

class Appointment {
  const Appointment({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.status,
    this.location,
  });

  final int id;
  final String title;
  final DateTime dateTime;
  final AppointmentStatus status;
  final String? location;
}
