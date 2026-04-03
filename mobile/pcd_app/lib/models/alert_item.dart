import 'status_type.dart';

class AlertItem {
  const AlertItem({
    required this.id,
    required this.type,
    required this.patientName,
    required this.message,
    required this.dateLabel,
    this.tone = BadgeTone.warning,
  });

  final int id;
  final String type;
  final String patientName;
  final String message;
  final String dateLabel;
  final BadgeTone tone;
}
