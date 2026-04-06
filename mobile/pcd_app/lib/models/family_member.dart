/// Represents a family member linked to a patient.
/// Maps to the backend `FamilyPatientMember` schema.
class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.patientId,
    required this.familyRole,
    required this.relationToPatient,
    required this.firstName,
    required this.lastName,
    required this.cin,
    required this.email,
  });

  final int userId;
  final int patientId;
  final String familyRole; // 'admin' or 'viewer'
  final String relationToPatient;
  final String firstName;
  final String lastName;
  final String cin;
  final String email;

  bool get isAdmin => familyRole == 'admin';
  bool get isViewer => familyRole == 'viewer';

  String get fullName => '$firstName $lastName'.trim();

  String get roleLabelFr => isAdmin ? 'Administrateur' : 'Spectateur';

  String get relationLabelFr {
    final r = relationToPatient.trim().toLowerCase();
    if (r.isEmpty || r == 'unspecified') return 'Non précisé';
    // Capitalize first letter
    return relationToPatient.trim().substring(0, 1).toUpperCase() +
        relationToPatient.trim().substring(1);
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      userId: _parseInt(json['user_id']) ?? 0,
      patientId: _parseInt(json['patient_id']) ?? 0,
      familyRole: json['family_role']?.toString().trim().toLowerCase() ?? 'viewer',
      relationToPatient: json['relation_to_patient']?.toString().trim() ?? '',
      firstName: json['first_name']?.toString().trim() ?? '',
      lastName: json['last_name']?.toString().trim() ?? '',
      cin: json['cin']?.toString().trim().toUpperCase() ?? '',
      email: json['email']?.toString().trim() ?? '',
    );
  }

  FamilyMember copyWith({String? familyRole}) {
    return FamilyMember(
      userId: userId,
      patientId: patientId,
      familyRole: familyRole ?? this.familyRole,
      relationToPatient: relationToPatient,
      firstName: firstName,
      lastName: lastName,
      cin: cin,
      email: email,
    );
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
