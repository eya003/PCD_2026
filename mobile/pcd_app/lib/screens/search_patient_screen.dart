import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models/patient.dart';
import '../patient_model.dart' as api_models;
import 'patient_detail_screen.dart';

class SearchPatientScreen extends StatefulWidget {
  const SearchPatientScreen({super.key});

  @override
  State<SearchPatientScreen> createState() => _SearchPatientScreenState();
}

class _SearchPatientScreenState extends State<SearchPatientScreen> {
  final _apiClient = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();

  DateTime? _birthDate;
  bool _isSearching = false;
  _SearchPlaceholderResult? _result;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate =
        _birthDate ?? DateTime(now.year - 30, now.month, now.day);

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

  Future<void> _submitSearch() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _showSnackBar('Veuillez corriger le formulaire.');
      return;
    }

    setState(() {
      _isSearching = true;
      _result = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final birthDate = _birthDate;
    if (birthDate == null) {
      setState(() {
        _isSearching = false;
      });
      _showSnackBar('Date de naissance invalide.');
      return;
    }

    try {
      final apiPatient = await _apiClient.searchPatient(
        firstName: firstName,
        lastName: lastName,
        birthDate: birthDate,
      );
      if (!mounted) return;

      if (apiPatient == null) {
        setState(() {
          _isSearching = false;
          _result = _SearchPlaceholderResult.notFound('Patient introuvable.');
        });
        _showSnackBar('Aucun patient trouve.');
        return;
      }

      final patient = _mapApiPatientToUiPatient(apiPatient);
      setState(() {
        _isSearching = false;
        _result = _SearchPlaceholderResult.found(
          message: 'Patient trouve',
          details:
              '${patient.firstName} ${patient.lastName} - ${_formatDate(patient.birthDate)}\nCode: ${patient.patientCode}',
          patient: patient,
        );
      });

      _showSnackBar('Patient trouve. Ouverture de la fiche...');
      await _openPatientDetail(patient);
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _result = _SearchPlaceholderResult.notFound(
          'Erreur de recherche API: ${error.message}',
        );
      });
      _showSnackBar('Erreur API (${error.statusCode ?? '-'})');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _result = _SearchPlaceholderResult.notFound(
          'Erreur reseau lors de la recherche patient.',
        );
      });
      _showSnackBar('Erreur reseau lors de la recherche.');
    }
  }

  Future<void> _openPatientDetail(Patient patient) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientDetailScreen(patient: patient),
      ),
    );
  }

  String? _validateRequired(String? value, String label) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '$label obligatoire';
    return null;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Patient _mapApiPatientToUiPatient(api_models.Patient apiPatient) {
    return Patient(
      id: apiPatient.id,
      patientCode: apiPatient.patientCode,
      firstName: apiPatient.firstName,
      lastName: apiPatient.lastName,
      birthDate: DateTime(
        apiPatient.birthDate.year,
        apiPatient.birthDate.month,
        apiPatient.birthDate.day,
      ),
      lastVisitAt: null,
      status: 'Dossier charge',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Rechercher un patient')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
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
                              'Recherche patient',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Renseignez les informations ci-dessous pour lancer une recherche.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _firstNameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Prenom (first_name)',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) =>
                                  _validateRequired(value, 'Prenom'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _lastNameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nom (last_name)',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: (value) =>
                                  _validateRequired(value, 'Nom'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _birthDateController,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Date de naissance (birth_date)',
                                prefixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: _pickBirthDate,
                                  icon: const Icon(Icons.event_outlined),
                                ),
                              ),
                              onTap: _pickBirthDate,
                              validator: (value) =>
                                  _validateRequired(value, 'Date de naissance'),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isSearching ? null : _submitSearch,
                                icon: _isSearching
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.search),
                                label: Text(
                                  _isSearching ? 'Recherche...' : 'Rechercher',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    _SearchResultCard(
                      result: _result!,
                      onOpenPatient: _result!.patient == null
                          ? null
                          : () => _openPatientDetail(_result!.patient!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.result, this.onOpenPatient});

  final _SearchPlaceholderResult result;
  final VoidCallback? onOpenPatient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final background = result.found
        ? colorScheme.secondaryContainer
        : colorScheme.surfaceContainerHighest;
    final foreground = result.found
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    result.found
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: foreground,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      result.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (result.details != null) ...[
              const SizedBox(height: 12),
              Text(result.details!, style: theme.textTheme.bodyMedium),
            ],
            if (result.patient != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onOpenPatient,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Ouvrir la fiche patient'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchPlaceholderResult {
  const _SearchPlaceholderResult({
    required this.found,
    required this.message,
    this.details,
    this.patient,
  });

  final bool found;
  final String message;
  final String? details;
  final Patient? patient;

  factory _SearchPlaceholderResult.found({
    required String message,
    String? details,
    Patient? patient,
  }) {
    return _SearchPlaceholderResult(
      found: true,
      message: message,
      details: details,
      patient: patient,
    );
  }

  factory _SearchPlaceholderResult.notFound(String message) {
    return _SearchPlaceholderResult(found: false, message: message);
  }
}
