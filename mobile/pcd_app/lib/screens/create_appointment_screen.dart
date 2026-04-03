import 'package:flutter/material.dart';

import '../models/appointment_item.dart';
import '../models/patient_summary.dart';
import '../services/appointments_service.dart';
import '../theme/app_spacing.dart';

class CreateAppointmentScreen extends StatefulWidget {
  const CreateAppointmentScreen({
    super.key,
    this.patientName,
    this.initialPatient,
    this.selectablePatients = const [],
    this.lockPatient = false,
    this.initialAppointment,
  });

  // Compatibility with legacy usages that only provided a name.
  final String? patientName;
  final PatientSummary? initialPatient;
  final List<PatientSummary> selectablePatients;
  final bool lockPatient;
  final AppointmentItem? initialAppointment;

  @override
  State<CreateAppointmentScreen> createState() =>
      _CreateAppointmentScreenState();
}

class _CreateAppointmentScreenState extends State<CreateAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();

  late final AppointmentsService _appointmentsService;
  late final List<PatientSummary> _patients;

  PatientSummary? _selectedPatient;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _status = 'scheduled';

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditMode => widget.initialAppointment != null;

  @override
  void initState() {
    super.initState();
    _appointmentsService = AppointmentsService();
    _patients = _buildSelectablePatients();
    _selectedPatient = _resolveInitialPatient();

    final existingAppointment = widget.initialAppointment;
    if (existingAppointment != null) {
      final dt = existingAppointment.dateTime;
      _selectedDate = DateTime(dt.year, dt.month, dt.day);
      _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      _dateController.text = _formatDate(_selectedDate!);
      _timeController.text = _formatTime(_selectedTime!);
      _notesController.text = existingAppointment.notes ?? '';
      _status = _normalizeStatus(existingAppointment.status);
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<PatientSummary> _buildSelectablePatients() {
    final ordered = <int, PatientSummary>{};
    for (final patient in widget.selectablePatients) {
      ordered[patient.id] = patient;
    }
    final initialPatient = widget.initialPatient;
    if (initialPatient != null) {
      ordered[initialPatient.id] = initialPatient;
    }
    return ordered.values.toList();
  }

  PatientSummary? _resolveInitialPatient() {
    final existingAppointment = widget.initialAppointment;
    if (existingAppointment != null) {
      for (final patient in _patients) {
        if (patient.id == existingAppointment.patientId) {
          return patient;
        }
      }
    }
    if (widget.initialPatient != null) {
      return widget.initialPatient;
    }
    if (_patients.length == 1) {
      return _patients.first;
    }
    return null;
  }

  String _normalizeStatus(String rawStatus) {
    return AppointmentItem.normalizeStatus(rawStatus);
  }

  String? _validateRequired(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label obligatoire';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: 'Date du rendez-vous',
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _dateController.text = _formatDate(_selectedDate!);
    });
  }

  Future<void> _pickTime() async {
    final initialTime = _selectedTime ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Heure du rendez-vous',
    );

    if (picked == null) return;
    setState(() {
      _selectedTime = picked;
      _timeController.text = _formatTime(picked);
    });
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) {
      setState(() => _errorMessage = 'Veuillez corriger le formulaire.');
      _showSnackBar('Veuillez corriger le formulaire.');
      return;
    }

    if (_selectedPatient == null) {
      setState(() => _errorMessage = 'Patient obligatoire.');
      _showSnackBar('Patient obligatoire.');
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      setState(() => _errorMessage = 'Date et heure obligatoires.');
      _showSnackBar('Date et heure obligatoires.');
      return;
    }

    final appointmentDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final patientsById = <int, PatientSummary>{
      for (final patient in _patients) patient.id: patient,
    };

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_isEditMode) {
        await _appointmentsService.updateAppointment(
          appointmentId: widget.initialAppointment!.id,
          patientId: _selectedPatient!.id,
          appointmentDateTime: appointmentDateTime,
          notes: _notesController.text,
          status: _status,
          patientsById: patientsById,
        );
      } else {
        await _appointmentsService.createAppointment(
          patientId: _selectedPatient!.id,
          appointmentDateTime: appointmentDateTime,
          notes: _notesController.text,
          status: _status,
          patientsById: patientsById,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppointmentsException catch (e) {
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
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _statusLabel(String status) {
    switch (AppointmentItem.normalizeStatus(status)) {
      case AppointmentItem.statusDone:
        return 'Termine';
      case AppointmentItem.statusCancelled:
        return 'Annule';
      case AppointmentItem.statusMissed:
        return 'Manque';
      case AppointmentItem.statusScheduled:
      default:
        return 'Planifie';
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final unavailablePatientSelection =
        _selectedPatient == null && _patients.isEmpty;
    final title = _isEditMode ? 'Modifier rendez-vous' : 'Ajouter rendez-vous';
    final statusItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(
        value: AppointmentItem.statusScheduled,
        child: Text('Planifie'),
      ),
      const DropdownMenuItem<String>(
        value: AppointmentItem.statusDone,
        child: Text('Termine'),
      ),
      const DropdownMenuItem<String>(
        value: AppointmentItem.statusCancelled,
        child: Text('Annule'),
      ),
      const DropdownMenuItem<String>(
        value: AppointmentItem.statusMissed,
        child: Text('Manque'),
      ),
    ];
    final subtitle = _selectedPatient != null
        ? 'Pour ${_selectedPatient!.fullName}'
        : (widget.patientName == null
              ? 'Choisissez un patient, puis la date et l heure.'
              : 'Pour ${widget.patientName}');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(subtitle),
                        const SizedBox(height: AppSpacing.md),
                        if (_errorMessage != null) ...[
                          _ErrorBox(message: _errorMessage!),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        if (widget.lockPatient && _selectedPatient != null)
                          TextFormField(
                            initialValue:
                                '${_selectedPatient!.fullName} (CIN: ${_selectedPatient!.cin})',
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Patient',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          )
                        else
                          DropdownButtonFormField<int>(
                            value: _selectedPatient?.id,
                            decoration: const InputDecoration(
                              labelText: 'Patient',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            items: _patients
                                .map(
                                  (patient) => DropdownMenuItem<int>(
                                    value: patient.id,
                                    child: Text(
                                      '${patient.fullName} (${patient.cin})',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: unavailablePatientSelection
                                ? null
                                : (value) {
                                    PatientSummary? nextPatient;
                                    for (final patient in _patients) {
                                      if (patient.id == value) {
                                        nextPatient = patient;
                                        break;
                                      }
                                    }
                                    setState(() {
                                      _selectedPatient = nextPatient;
                                    });
                                  },
                            validator: (_) {
                              if (_selectedPatient == null) {
                                return 'Patient obligatoire';
                              }
                              return null;
                            },
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          onTap: _pickDate,
                          decoration: InputDecoration(
                            labelText: 'Date',
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            suffixIcon: IconButton(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.event_outlined),
                            ),
                          ),
                          validator: (v) => _validateRequired(v, 'Date'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _timeController,
                          readOnly: true,
                          onTap: _pickTime,
                          decoration: InputDecoration(
                            labelText: 'Heure',
                            prefixIcon: const Icon(Icons.access_time_outlined),
                            suffixIcon: IconButton(
                              onPressed: _pickTime,
                              icon: const Icon(Icons.schedule_outlined),
                            ),
                          ),
                          validator: (v) => _validateRequired(v, 'Heure'),
                        ),
                        if (_isEditMode) ...[
                          const SizedBox(height: AppSpacing.sm),
                          DropdownButtonFormField<String>(
                            value: _status,
                            decoration: const InputDecoration(
                              labelText: 'Statut',
                              prefixIcon: Icon(Icons.flag_outlined),
                            ),
                            items: statusItems,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _status = value);
                            },
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Statut obligatoire';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _notesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optionnel)',
                            prefixIcon: Icon(Icons.sticky_note_2_outlined),
                          ),
                        ),
                        if (unavailablePatientSelection) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Impossible de creer un rendez-vous: aucun patient disponible.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: (_isSubmitting || unavailablePatientSelection)
                                ? null
                                : _submit,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _isEditMode ? Icons.save_outlined : Icons.add,
                                  ),
                            label: Text(
                              _isSubmitting
                                  ? (_isEditMode
                                        ? 'Mise a jour...'
                                        : 'Creation...')
                                  : (_isEditMode
                                        ? 'Enregistrer'
                                        : 'Ajouter rendez-vous'),
                            ),
                          ),
                        ),
                        if (_isEditMode) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Statut actuel: ${_statusLabel(_status)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
