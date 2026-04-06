/// Centralized family permission checks.
///
/// Usage:
///   final perms = FamilyPermissions.fromRole('admin');
///   if (perms.canValidateMedication) { ... }
class FamilyPermissions {
  const FamilyPermissions({required this.isAdmin});

  factory FamilyPermissions.fromRole(String? role) {
    return FamilyPermissions(
      isAdmin: (role ?? '').trim().toLowerCase() == 'admin',
    );
  }

  final bool isAdmin;

  bool get isViewer => !isAdmin;
  String get roleLabelFr => isAdmin ? 'Administrateur' : 'Spectateur';
  String get roleValue => isAdmin ? 'admin' : 'viewer';

  bool get canValidateMedication => isAdmin;
  bool get canManageAppointments => isAdmin;
  bool get canMarkAlertsRead => isAdmin;
  bool get canManageFamilyMembers => isAdmin;
  bool get canTransferAdmin => isAdmin;
  bool get canWrite => isAdmin;
}
