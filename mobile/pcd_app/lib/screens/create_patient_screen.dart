import 'package:flutter/material.dart';

import '../services/patients_service.dart';

class CreatePatientScreen extends StatefulWidget {
  const CreatePatientScreen({super.key, this.service});

  final PatientsService? service;

  @override
  State<CreatePatientScreen> createState() => _CreatePatientScreenState();
}

class _CreatePatientScreenState extends State<CreatePatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _cinController = TextEditingController();

  late final PatientsService _service;

  DateTime? _birthDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PatientsService();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _cinController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
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
    final required = _validateRequired(value, 'CIN');
    if (required != null) return required;
    if ((value ?? '').trim().length < 3) return 'CIN invalide';
    return null;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate = _birthDate ?? DateTime(now.year - 30, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date de naissance',
    );

    if (picked == null) return;

    setState(() {
      _birthDate = DateTime(picked.year, picked.month, picked.day);
      _birthDateController.text = _formatDate(_birthDate!);
    });
  }

  Future<void> _submitCreate() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _birthDate == null) {
      setState(() {
        _errorMessage = 'Veuillez remplir tous les champs obligatoires.';
      });
      _showSnackBar('Veuillez corriger le formulaire.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _service.createPatient(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        birthDate: _birthDate!,
        cin: _cinController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PatientsException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Erreur serveur. Veuillez reessayer.';
      setState(() => _errorMessage = message);
      _showSnackBar(message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un patient')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nouveau patient',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Saisissez les informations obligatoires du patient.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _CreateErrorBox(message: _errorMessage!),
                        ],
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _firstNameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Prenom (first_name)',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) => _validateRequired(value, 'Prenom'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nom (last_name)',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) => _validateRequired(value, 'Nom'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _birthDateController,
                          readOnly: true,
                          onTap: _pickBirthDate,
                          decoration: InputDecoration(
                            labelText: 'Date de naissance (birth_date)',
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            suffixIcon: IconButton(
                              onPressed: _pickBirthDate,
                              icon: const Icon(Icons.event_outlined),
                            ),
                          ),
                          validator: (value) =>
                              _validateRequired(value, 'Date de naissance'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _cinController,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'CIN',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                          validator: _validateCin,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSubmitting ? null : _submitCreate,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_isSubmitting ? 'Creation...' : 'Ajouter'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateErrorBox extends StatelessWidget {
  const _CreateErrorBox({required this.message});

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
