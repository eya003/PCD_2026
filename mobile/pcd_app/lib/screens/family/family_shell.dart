import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/family_permissions.dart';
import '../../models/patient_summary.dart';
import '../../models/user_role.dart';
import '../../services/family_service.dart';
import '../../widgets/empty_state.dart';
import '../profile/profile_screen.dart';
import 'family_appointments_screen.dart';
import 'family_patient_screen.dart';
import 'family_treatments_screen.dart';

/// Authenticated shell for family users.
/// Four-tab nav: Accueil | Medicaments | Rendez-vous | Profil.
class FamilyShell extends StatefulWidget {
  const FamilyShell({
    super.key,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.familyRole,
    required this.onLogout,
  });

  final int userId;
  final String email;
  final String firstName;
  final String lastName;
  /// 'admin', 'viewer', or '' (unknown - resolved from backend at load time).
  final String familyRole;
  final Future<void> Function() onLogout;

  @override
  State<FamilyShell> createState() => _FamilyShellState();
}

class _FamilyShellState extends State<FamilyShell> {
  static const _familyRoleKey = 'auth_family_role';

  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _error;
  List<PatientSummary> _patients = const [];
  late String _familyRole;

  FamilyPermissions get _permissions => FamilyPermissions.fromRole(_familyRole);

  @override
  void initState() {
    super.initState();
    _familyRole = _normalizeFamilyRole(widget.familyRole);
    _loadPatients();
  }

  String _normalizeFamilyRole(String? role) {
    final value = (role ?? '').trim().toLowerCase();
    if (value == 'admin') return 'admin';
    if (value == 'viewer') return 'viewer';
    return '';
  }

  Future<void> _updateFamilyRole(String role) async {
    final normalized = _normalizeFamilyRole(role);
    if (_familyRole == normalized) return;

    setState(() => _familyRole = normalized);

    final prefs = await SharedPreferences.getInstance();
    if (normalized.isEmpty) {
      await prefs.remove(_familyRoleKey);
    } else {
      await prefs.setString(_familyRoleKey, normalized);
    }
  }

  Future<void> _loadPatients() async {
    try {
      final service = FamilyService();
      final previousRole = _familyRole;
      final patients = await service.fetchLinkedPatients();
      var resolvedRole = previousRole;

      if (patients.isNotEmpty) {
        try {
          final apiRole = await service.fetchCurrentFamilyRole(
            patientId: patients.first.id,
          );
          final normalizedRole = _normalizeFamilyRole(apiRole);
          if (normalizedRole.isNotEmpty) {
            resolvedRole = normalizedRole;
          }
        } catch (_) {
          // Keep previously known role if role resolution fails.
        }
      }

      if (!mounted) return;
      setState(() {
        _familyRole = resolvedRole;
        _patients = patients;
        _isLoading = false;
      });

      if (resolvedRole != previousRole) {
        final prefs = await SharedPreferences.getInstance();
        if (resolvedRole.isEmpty) {
          await prefs.remove(_familyRoleKey);
        } else {
          await prefs.setString(_familyRoleKey, resolvedRole);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Impossible de charger vos donnees.';
      });
    }
  }

  void _setTab(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: EmptyState(
          icon: Icons.error_outline,
          title: 'Erreur',
          message: _error!,
        ),
      );
    }
    if (_patients.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accueil famille')),
        body: const EmptyState(
          icon: Icons.person_search_outlined,
          title: 'Aucun patient lie',
          message: 'Aucun patient n est associe a votre compte.',
        ),
      );
    }

    final patient = _patients.first;

    return IndexedStack(
      index: _selectedIndex,
      children: [
        FamilyPatientScreen(
          patient: patient,
          currentUserId: widget.userId,
          isAdmin: _permissions.isAdmin,
          familyFirstName: widget.firstName,
          familyLastName: widget.lastName,
          onFamilyRoleChanged: _updateFamilyRole,
        ),
        FamilyTreatmentsScreen(
          patient: patient,
          isAdmin: _permissions.isAdmin,
        ),
        FamilyAppointmentsScreen(
          patient: patient,
          isAdmin: _permissions.isAdmin,
        ),
        Scaffold(
          appBar: AppBar(title: const Text('Profil')),
          body: ProfileScreen(
            email: widget.email,
            userId: widget.userId,
            role: UserRole.family,
            firstName: widget.firstName,
            lastName: widget.lastName,
            onLogout: widget.onLogout,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _setTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'Medicaments',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Rendez-vous',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
