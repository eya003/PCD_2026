import 'status_type.dart';

class PatientSummary {
  const PatientSummary({
    required this.id,
    required this.code,
    required this.firstName,
    required this.lastName,
    required this.cin,
    required this.birthDate,
    required this.status,
  });

  final int id;
  final String code;
  final String firstName;
  final String lastName;
  final String cin;
  final DateTime birthDate;
  final PatientStatus status;

  String get fullName => '$firstName $lastName'.trim();

  int get age {
    final now = DateTime.now();
    var years = now.year - birthDate.year;
    final hasHadBirthdayThisYear =
        now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hasHadBirthdayThisYear) {
      years -= 1;
    }
    return years < 0 ? 0 : years;
  }
}
