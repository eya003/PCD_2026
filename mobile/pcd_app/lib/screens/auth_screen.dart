import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authService,
    required this.onAuthenticated,
  });

  final AuthService authService;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginCinController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _registerFirstNameController = TextEditingController();
  final _registerLastNameController = TextEditingController();
  final _registerCinController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  final _registerPatientCinController = TextEditingController();

  UserRole _registerRole = UserRole.doctor;
  String _registerFamilyRole = 'viewer';

  bool _showLoginPassword = false;
  bool _showRegisterPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoginLoading = false;
  bool _isRegisterLoading = false;

  String? _loginError;
  String? _registerError;

  @override
  void dispose() {
    _loginCinController.dispose();
    _loginPasswordController.dispose();
    _registerFirstNameController.dispose();
    _registerLastNameController.dispose();
    _registerCinController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _registerPatientCinController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_loginFormKey.currentState?.validate() ?? false)) {
      setState(() => _loginError = 'Veuillez remplir tous les champs obligatoires.');
      return;
    }

    setState(() {
      _isLoginLoading = true;
      _loginError = null;
    });
    try {
      final session = await widget.authService.login(
        _loginCinController.text.trim(),
        _loginPasswordController.text,
      );
      if (!mounted) return;

      widget.onAuthenticated(session);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loginError = e.message);
      _showError(e.message);
    } catch (_) {
      const message = 'Erreur serveur. Veuillez reessayer.';
      if (!mounted) return;
      setState(() => _loginError = message);
      _showError(message);
    } finally {
      if (mounted) {
        setState(() => _isLoginLoading = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!(_registerFormKey.currentState?.validate() ?? false)) {
      setState(() => _registerError = 'Veuillez remplir tous les champs obligatoires.');
      return;
    }

    setState(() {
      _isRegisterLoading = true;
      _registerError = null;
    });
    try {
      final session = await widget.authService.register(
        firstName: _registerFirstNameController.text.trim(),
        lastName: _registerLastNameController.text.trim(),
        cin: _registerCinController.text.trim(),
        email: _registerEmailController.text.trim(),
        password: _registerPasswordController.text,
        role: _registerRole,
        familyRole: _registerRole == UserRole.family ? _registerFamilyRole : null,
        patientCin: _registerRole == UserRole.family
            ? _registerPatientCinController.text.trim()
            : null,
      );
      if (!mounted) return;

      widget.onAuthenticated(session);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _registerError = e.message);
      _showError(e.message);
    } catch (_) {
      const message = 'Erreur serveur. Veuillez reessayer.';
      if (!mounted) return;
      setState(() => _registerError = message);
      _showError(message);
    } finally {
      if (mounted) {
        setState(() => _isRegisterLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateRequired(String? value, String label) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '$label obligatoire';
    return null;
  }

  String? _validateCin(String? value) {
    final requiredError = _validateRequired(value, 'CIN');
    if (requiredError != null) return requiredError;
    if ((value ?? '').trim().length < 3) return 'CIN invalide';
    return null;
  }

  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Email obligatoire';
    if (!text.contains('@')) return 'Email invalide';
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Mot de passe obligatoire';
    if (text.length < 6) return 'Minimum 6 caracteres';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Authentification'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Se connecter'),
              Tab(text: 'Creer un compte'),
            ],
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              child: Icon(
                                Icons.account_circle_outlined,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Connexion et inscription',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Login via CIN uniquement. Le role est detecte automatiquement a la connexion.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildLoginTab(theme),
                          _buildRegisterTab(theme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginTab(ThemeData theme) {
    return SingleChildScrollView(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _loginFormKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Se connecter',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (_loginError != null) ...[
                  _ErrorBox(message: _loginError!),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _loginCinController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'CIN',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: _validateCin,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _loginPasswordController,
                  obscureText: !_showLoginPassword,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _showLoginPassword = !_showLoginPassword);
                      },
                      icon: Icon(
                        _showLoginPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoginLoading ? null : _handleLogin,
                    child: _isLoginLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Se connecter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterTab(ThemeData theme) {
    final isFamily = _registerRole == UserRole.family;

    return SingleChildScrollView(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _registerFormKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Creer un compte',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (_registerError != null) ...[
                  _ErrorBox(message: _registerError!),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _registerFirstNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Prenom',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => _validateRequired(value, 'Prenom'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _registerLastNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => _validateRequired(value, 'Nom'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _registerCinController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'CIN',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                  validator: _validateCin,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _registerEmailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _registerPasswordController,
                  obscureText: !_showRegisterPassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(
                          () => _showRegisterPassword = !_showRegisterPassword,
                        );
                      },
                      icon: Icon(
                        _showRegisterPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _registerConfirmPasswordController,
                  obscureText: !_showConfirmPassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Confirmer mot de passe',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _showConfirmPassword = !_showConfirmPassword);
                      },
                      icon: Icon(
                        _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final error = _validatePassword(value);
                    if (error != null) return error;
                    if ((value ?? '') != _registerPasswordController.text) {
                      return 'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  value: _registerRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.shield_outlined),
                  ),
                  items: UserRole.values
                      .map(
                        (role) => DropdownMenuItem<UserRole>(
                          value: role,
                          child: Text(role.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _registerRole = value;
                      if (_registerRole != UserRole.family) {
                        _registerPatientCinController.clear();
                        _registerFamilyRole = 'viewer';
                      }
                    });
                  },
                ),
                if (isFamily) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _registerFamilyRole,
                    decoration: const InputDecoration(
                      labelText: 'Family role',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                        value: 'admin',
                        child: Text('admin'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'viewer',
                        child: Text('viewer'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _registerFamilyRole = value);
                    },
                    validator: (value) {
                      if (_registerRole != UserRole.family) return null;
                      if ((value ?? '').trim().isEmpty) {
                        return 'family_role obligatoire';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _registerPatientCinController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Patient CIN',
                      prefixIcon: Icon(Icons.assignment_ind_outlined),
                    ),
                    validator: (value) {
                      if (_registerRole != UserRole.family) return null;
                      final requiredError = _validateRequired(value, 'Patient CIN');
                      if (requiredError != null) return requiredError;
                      if ((value ?? '').trim().length < 3) return 'CIN patient invalide';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isRegisterLoading ? null : _handleRegister,
                    child: _isRegisterLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Creer le compte'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
