import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../screens/ai/ai_module_screen.dart';
import '../screens/create_patient_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/patients/patients_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.email,
    required this.userId,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.onLogout,
  });

  final String email;
  final int userId;
  final UserRole role;
  final String firstName;
  final String lastName;
  final Future<void> Function() onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final ValueNotifier<int> _patientsRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> _appointmentsRevision = ValueNotifier<int>(0);

  late final List<Widget> _pages = [
    DashboardScreen(
      onOpenPatients: () => _setTab(1),
      onOpenAi: () => _setTab(2),
      onAddPatient: _openCreatePatientScreen,
      patientsRevision: _patientsRevision,
      appointmentsRevision: _appointmentsRevision,
      firstName: widget.firstName,
      lastName: widget.lastName,
    ),
    PatientsScreen(
      patientsRevision: _patientsRevision,
      appointmentsRevision: _appointmentsRevision,
      onAddPatient: _openCreatePatientScreen,
    ),
    const AiModuleScreen(),
    ProfileScreen(
      email: widget.email,
      userId: widget.userId,
      role: widget.role,
      firstName: widget.firstName,
      lastName: widget.lastName,
      onLogout: widget.onLogout,
    ),
  ];

  void _setTab(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  Future<void> _openCreatePatientScreen() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const CreatePatientScreen(),
      ),
    );

    if (!mounted) return;
    if (created == true) {
      _patientsRevision.value = _patientsRevision.value + 1;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Patient ajoute avec succes.')),
        );
    }
  }

  @override
  void dispose() {
    _patientsRevision.dispose();
    _appointmentsRevision.dispose();
    super.dispose();
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Patients';
      case 2:
        return 'Module IA';
      case 3:
        return 'Profil';
      case 0:
      default:
        return 'Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(_selectedIndex)),
        leading: Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: GestureDetector(
              onTap: () => _setTab(3),
              child: CircleAvatar(
                radius: 16,
                child: Text(
                  widget.firstName.trim().isNotEmpty
                      ? widget.firstName.trim().substring(0, 1).toUpperCase()
                      : widget.email.trim().isEmpty
                          ? 'D'
                          : widget.email.trim().substring(0, 1).toUpperCase(),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: AppDrawer(
        currentIndex: _selectedIndex,
        email: widget.email,
        onSelectIndex: _setTab,
        onLogout: widget.onLogout,
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: _pages),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _selectedIndex,
        onTap: _setTab,
      ),
    );
  }
}
