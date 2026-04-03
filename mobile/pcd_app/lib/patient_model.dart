class Patient {
  const Patient({
    required this.id,
    required this.patientCode,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
  });

  final int id;
  final String patientCode;
  final String firstName;
  final String lastName;
  final DateTime birthDate;

  String get fullName => '$firstName $lastName';

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as int,
      patientCode: json['patient_code'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      birthDate: DateTime.parse(json['birth_date'] as String),
    );
  }
}
