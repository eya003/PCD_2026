import 'package:flutter/material.dart';

import '../../models/patient_summary.dart';
import '../../services/treatments_service.dart';
import '../../theme/app_spacing.dart';

class CreatePrescriptionScreen extends StatefulWidget {
  const CreatePrescriptionScreen({super.key, required this.patient});

  final PatientSummary patient;

  @override
  State<CreatePrescriptionScreen> createState() =>
      _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState extends State<CreatePrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _prescriptionDateController = TextEditingController();

  late final TreatmentsService _service;
  late DateTime _prescriptionDate;
  final List<_MedicationDraft> _medications = [_MedicationDraft()];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _service = TreatmentsService();
    _prescriptionDate = _normalizeDate(DateTime.now());
    _prescriptionDateController.text = _formatDate(_prescriptionDate);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _prescriptionDateController.dispose();
    for (final medication in _medications) {
      medication.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPrescriptionDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _prescriptionDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Date de prescription',
    );
    if (picked == null) return;

    setState(() {
      _prescriptionDate = _normalizeDate(picked);
      _prescriptionDateController.text = _formatDate(_prescriptionDate);
    });
  }

  void _addMedication() {
    setState(() {
      _medications.add(_MedicationDraft());
    });
  }

  void _removeMedication(int index) {
    if (_medications.length <= 1) {
      return;
    }
    setState(() {
      final removed = _medications.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _pickMedicationDate({
    required _MedicationDraft draft,
    required bool isStartDate,
  }) async {
    final now = DateTime.now();
    final current = isStartDate ? draft.startDate : draft.endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: isStartDate ? 'Date de debut' : 'Date de fin',
    );
    if (picked == null) return;

    setState(() {
      final normalized = _normalizeDate(picked);
      if (isStartDate) {
        draft.startDate = normalized;
        draft.startDateController.text = _formatDate(normalized);
        final currentEnd = draft.endDate;
        if (currentEnd != null && currentEnd.isBefore(normalized)) {
          draft.endDate = null;
          draft.endDateController.clear();
        }
      } else {
        draft.endDate = normalized;
        draft.endDateController.text = _formatDate(normalized);
      }
    });
  }

  String? _validateRequired(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label obligatoire';
    }
    return null;
  }

  String? _validateEndDate(_MedicationDraft draft) {
    final end = draft.endDate;
    final start = draft.startDate;
    if (end == null) return null;
    if (start == null) return 'Date de debut obligatoire';
    if (end.isBefore(start)) {
      return 'Date de fin >= date de debut';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackBar('Veuillez corriger le formulaire.');
      return;
    }

    final medicationsPayload = <_MedicationPayload>[];
    for (final draft in _medications) {
      final startDate = draft.startDate;
      if (startDate == null) {
        _showSnackBar('Date de debut obligatoire pour chaque medicament.');
        return;
      }
      medicationsPayload.add(
        _MedicationPayload(
          name: draft.nameController.text.trim(),
          dosage: draft.dosageController.text.trim(),
          form: draft.formController.text.trim(),
          quantity: draft.quantityController.text.trim(),
          frequency: draft.frequencyController.text.trim(),
          period: draft.periodController.text.trim(),
          startDate: startDate,
          endDate: draft.endDate,
          instructions: draft.instructionsController.text.trim(),
        ),
      );
    }

    setState(() => _isSubmitting = true);
    try {
      final prescription = await _service.createPrescription(
        patientId: widget.patient.id,
        prescriptionDate: _prescriptionDate,
        notes: _notesController.text.trim(),
      );

      for (final medication in medicationsPayload) {
        await _service.createMedication(
          patientId: widget.patient.id,
          prescriptionId: prescription.id,
          name: medication.name,
          dosage: medication.dosage,
          form: medication.form,
          quantity: medication.quantity,
          frequency: medication.frequency,
          period: medication.period,
          startDate: medication.startDate,
          endDate: medication.endDate,
          instructions: medication.instructions,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TreatmentsException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Impossible de creer l ordonnance.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  DateTime _normalizeDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle ordonnance')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.patient.fullName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Code: ${widget.patient.code}  -  CIN: ${widget.patient.cin}',
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _prescriptionDateController,
                              readOnly: true,
                              onTap: _pickPrescriptionDate,
                              decoration: InputDecoration(
                                labelText: 'Date de prescription',
                                prefixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: _pickPrescriptionDate,
                                  icon: const Icon(Icons.event_outlined),
                                ),
                              ),
                              validator: (value) => _validateRequired(
                                value,
                                'Date de prescription',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              controller: _notesController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Notes ordonnance',
                                alignLabelWithHint: true,
                                prefixIcon: Icon(Icons.sticky_note_2_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Medicaments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...List.generate(_medications.length, (index) {
                      final draft = _medications[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Medicament ${index + 1}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    if (_medications.length > 1)
                                      IconButton(
                                        onPressed: _isSubmitting
                                            ? null
                                            : () => _removeMedication(index),
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: 'Supprimer',
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                _MedicationFormFields(
                                  draft: draft,
                                  isSubmitting: _isSubmitting,
                                  onPickStartDate: () => _pickMedicationDate(
                                    draft: draft,
                                    isStartDate: true,
                                  ),
                                  onPickEndDate: () => _pickMedicationDate(
                                    draft: draft,
                                    isStartDate: false,
                                  ),
                                  validateRequired: _validateRequired,
                                  validateEndDate: _validateEndDate,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: _isSubmitting ? null : _addMedication,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un medicament'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _isSubmitting
                              ? 'Creation en cours...'
                              : 'Creer ordonnance et medicaments',
                        ),
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
}

class _MedicationFormFields extends StatelessWidget {
  const _MedicationFormFields({
    required this.draft,
    required this.isSubmitting,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.validateRequired,
    required this.validateEndDate,
  });

  final _MedicationDraft draft;
  final bool isSubmitting;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final String? Function(String? value, String label) validateRequired;
  final String? Function(_MedicationDraft draft) validateEndDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: draft.nameController,
          enabled: !isSubmitting,
          decoration: const InputDecoration(
            labelText: 'Nom du medicament',
            prefixIcon: Icon(Icons.medication_outlined),
          ),
          validator: (value) => validateRequired(value, 'Nom du medicament'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: draft.dosageController,
          enabled: !isSubmitting,
          decoration: const InputDecoration(
            labelText: 'Dosage',
            prefixIcon: Icon(Icons.science_outlined),
          ),
          validator: (value) => validateRequired(value, 'Dosage'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: draft.formController,
          enabled: !isSubmitting,
          decoration: const InputDecoration(
            labelText: 'Forme (optionnel)',
            prefixIcon: Icon(Icons.category_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: draft.quantityController,
          enabled: !isSubmitting,
          decoration: const InputDecoration(
            labelText: 'Quantite',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
          validator: (value) => validateRequired(value, 'Quantite'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: draft.frequencyController,
          enabled: !isSubmitting,
          decoration: const InputDecoration(
            labelText: 'Frequence',
            prefixIcon: Icon(Icons.schedule_outlined),
          ),
          validator: (value) => validateRequired(value, 'Frequence'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: draft.periodController,
          enabled: !isSubmitting,
          decoration: const InputDecoration(
            labelText: 'Periode / duree',
            prefixIcon: Icon(Icons.timelapse_outlined),
          ),
          validator: (value) => validateRequired(value, 'Periode / duree'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: draft.startDateController,
          enabled: !isSubmitting,
          readOnly: true,
          onTap: onPickStartDate,
          decoration: InputDecoration(
            labelText: 'Date debut',
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            suffixIcon: IconButton(
              onPressed: isSubmitting ? null : onPickStartDate,
              icon: const Icon(Icons.event_outlined),
            ),
          ),
          validator: (value) => validateRequired(value, 'Date debut'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: draft.endDateController,
          enabled: !isSubmitting,
          readOnly: true,
          onTap: onPickEndDate,
          decoration: InputDecoration(
            labelText: 'Date fin (optionnel)',
            prefixIcon: const Icon(Icons.event_available_outlined),
            suffixIcon: IconButton(
              onPressed: isSubmitting ? null : onPickEndDate,
              icon: const Icon(Icons.event_outlined),
            ),
          ),
          validator: (_) => validateEndDate(draft),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: draft.instructionsController,
          enabled: !isSubmitting,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Instructions',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.description_outlined),
          ),
          validator: (value) => validateRequired(value, 'Instructions'),
        ),
      ],
    );
  }
}

class _MedicationDraft {
  _MedicationDraft()
    : nameController = TextEditingController(),
      dosageController = TextEditingController(),
      formController = TextEditingController(),
      quantityController = TextEditingController(),
      frequencyController = TextEditingController(),
      periodController = TextEditingController(),
      startDateController = TextEditingController(),
      endDateController = TextEditingController(),
      instructionsController = TextEditingController();

  final TextEditingController nameController;
  final TextEditingController dosageController;
  final TextEditingController formController;
  final TextEditingController quantityController;
  final TextEditingController frequencyController;
  final TextEditingController periodController;
  final TextEditingController startDateController;
  final TextEditingController endDateController;
  final TextEditingController instructionsController;

  DateTime? startDate;
  DateTime? endDate;

  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    formController.dispose();
    quantityController.dispose();
    frequencyController.dispose();
    periodController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    instructionsController.dispose();
  }
}

class _MedicationPayload {
  const _MedicationPayload({
    required this.name,
    required this.dosage,
    required this.form,
    required this.quantity,
    required this.frequency,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.instructions,
  });

  final String name;
  final String dosage;
  final String form;
  final String quantity;
  final String frequency;
  final String period;
  final DateTime startDate;
  final DateTime? endDate;
  final String instructions;
}
