import 'package:flutter/material.dart';

import 'models/user_role.dart';
import 'navigation/main_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/family/family_shell.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();
  final initialSession = await authService.restoreSession();
  runApp(PcdApp(authService: authService, initialSession: initialSession));
}

class PcdApp extends StatefulWidget {
  const PcdApp({
    super.key,
    required this.authService,
    required this.initialSession,
  });

  final AuthService authService;
  final AuthSession? initialSession;

  @override
  State<PcdApp> createState() => _PcdAppState();
}

class _PcdAppState extends State<PcdApp> {
  AuthSession? _session;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
  }

  Future<void> _logout() async {
    await widget.authService.clearSession();
    if (!mounted) return;
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PCD',
      theme: AppTheme.light(),
      home: _session == null
          ? AuthScreen(
              authService: widget.authService,
              onAuthenticated: (session) {
                setState(() => _session = session);
              },
            )
          : _session!.role == UserRole.family
              ? FamilyShell(
                  userId: _session!.userId,
                  email: _session!.email,
                  firstName: _session!.firstName,
                  lastName: _session!.lastName,
                  familyRole: _session!.familyRole,
                  onLogout: _logout,
                )
              : MainShell(
                  email: _session!.email,
                  userId: _session!.userId,
                  role: _session!.role,
                  firstName: _session!.firstName,
                  lastName: _session!.lastName,
                  onLogout: _logout,
                ),
    );
  }
}
