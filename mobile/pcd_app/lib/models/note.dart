class PatientNote {
  const PatientNote({
    required this.id,
    required this.createdAt,
    required this.content,
  });

  final int id;
  final DateTime createdAt;
  final String content;
}
