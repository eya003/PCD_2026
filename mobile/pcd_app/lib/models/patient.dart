class Patient {
  const Patient({
    required this.id,
    required this.patientCode,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    this.lastVisitAt,
    this.status,
  });

  final int id;
  final String patientCode;
  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final DateTime? lastVisitAt;
  final String? status;

  String get fullName => '$firstName $lastName';
  String get appBarTitle => '$lastName $firstName';

  Patient copyWith({
    int? id,
    String? patientCode,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    DateTime? lastVisitAt,
    String? status,
  }) {
    return Patient(
      id: id ?? this.id,
      patientCode: patientCode ?? this.patientCode,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      birthDate: birthDate ?? this.birthDate,
      lastVisitAt: lastVisitAt ?? this.lastVisitAt,
      status: status ?? this.status,
    );
  }
}
