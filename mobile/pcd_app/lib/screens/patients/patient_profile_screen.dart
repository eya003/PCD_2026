import 'package:flutter/material.dart';

import '../../models/appointment_item.dart';
import '../../models/medication.dart';
import '../../models/medication_intake.dart';
import '../../models/patient_allergy.dart';
import '../../models/patient_summary.dart';
import '../../models/prescription.dart';
import '../../models/status_type.dart';
import '../../models/user_role.dart';
import '../../services/appointments_service.dart';
import '../../services/treatments_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_badge.dart';
import '../create_appointment_screen.dart';
import 'create_prescription_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({
    super.key,
    required this.patient,
    this.appointmentsRevision,
  });

  final PatientSummary patient;
  final ValueNotifier<int>? appointmentsRevision;

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  late final AppointmentsService _appointmentsService;
  late final TreatmentsService _treatmentsService;

  bool _isLoadingAppointments = true;
  String? _appointmentsError;
  List<AppointmentItem> _appointments = const [];

  bool _isLoadingTreatments = true;
  String? _treatmentsError;
  List<Medication> _activeMedications = const [];
  List<Medication> _archivedMedications = const [];
  List<MedicationIntake> _medicationIntakes = const [];
  List<Prescription> _prescriptions = const [];
  List<PatientAllergy> _allergies = const [];
  Map<int, String> _doctorNamesById = const {};
  UserRole? _currentRole;

  bool get _isDoctor => _currentRole == UserRole.doctor;

  @override
  void initState() {
    super.initState();
    _appointmentsService = AppointmentsService();
    _treatmentsService = TreatmentsService();
    _loadRoleFromSession();
    _refreshAll();
  }

  Future<void> _loadRoleFromSession() async {
    try {
      final role = await _treatmentsService.getCurrentRole();
      if (!mounted) return;
      setState(() => _currentRole = role);
    } catch (_) {
      // Role will be set by _loadTreatments() if it succeeds.
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadAppointments(), _loadTreatments()]);
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoadingAppointments = true;
      _appointmentsError = null;
    });

    try {
      final appointments = await _appointmentsService.fetchPatientAppointments(
        patientId: widget.patient.id,
        patientsById: {widget.patient.id: widget.patient},
      );
      final patientAppointments = appointments;

      if (!mounted) return;
      setState(() {
        _appointments = patientAppointments;
        _isLoadingAppointments = false;
      });
    } on AppointmentsException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) {
        setState(() {
          _appointments = const [];
          _appointmentsError = null;
          _isLoadingAppointments = false;
        });
        return;
      }
      setState(() {
        _appointmentsError = e.message;
        _isLoadingAppointments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appointmentsError = 'Impossible de charger les rendez-vous.';
        _isLoadingAppointments = false;
      });
    }
  }

  Future<void> _loadTreatments() async {
    setState(() {
      _isLoadingTreatments = true;
      _treatmentsError = null;
    });

    try {
      final data = await _treatmentsService.fetchPatientTreatmentData(
        patientId: widget.patient.id,
      );

      if (!mounted) return;
      setState(() {
        _currentRole = data.role;
        _activeMedications = data.activeMedications;
        _archivedMedications = data.archivedMedications;
        _medicationIntakes = data.intakes;
        _prescriptions = data.prescriptions;
        _allergies = data.allergies;
        _doctorNamesById = data.doctorNamesById;
        _isLoadingTreatments = false;
      });
    } on TreatmentsException catch (e) {
      if (!mounted) return;
      setState(() {
        _treatmentsError = e.message;
        _isLoadingTreatments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _treatmentsError = 'Impossible de charger les traitements.';
        _isLoadingTreatments = false;
      });
    }
  }

  Future<void> _openCreateAppointment() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateAppointmentScreen(
          initialPatient: widget.patient,
          selectablePatients: [widget.patient],
          lockPatient: true,
        ),
      ),
    );
    if (!mounted) return;
    if (created == true) {
      _notifyAppointmentsChanged();
      await _loadAppointments();
      _showSnackBar('Rendez-vous ajoute avec succes.');
    }
  }

  Future<void> _openEditAppointment(AppointmentItem item) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateAppointmentScreen(
          initialPatient: widget.patient,
          selectablePatients: [widget.patient],
          lockPatient: true,
          initialAppointment: item,
        ),
      ),
    );

    if (!mounted) return;
    if (updated == true) {
      _notifyAppointmentsChanged();
      await _loadAppointments();
      _showSnackBar('Rendez-vous modifie avec succes.');
    }
  }

  Future<void> _deleteAppointment(AppointmentItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer rendez-vous'),
        content: Text(
          'Supprimer le rendez-vous du ${item.dateLabel} a ${item.timeLabel} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _appointmentsService.deleteAppointment(item.id);
      if (!mounted) return;
      _notifyAppointmentsChanged();
      await _loadAppointments();
      _showSnackBar('Rendez-vous supprime avec succes.');
    } on AppointmentsException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Impossible de supprimer le rendez-vous.');
    }
  }

  Future<void> _markAppointmentCompleted(AppointmentItem item) async {
    try {
      await _appointmentsService.markAppointmentCompleted(appointment: item);
      if (!mounted) return;
      _notifyAppointmentsChanged();
      await _loadAppointments();
      _showSnackBar('Rendez-vous marque comme termine.');
    } on AppointmentsException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Impossible de marquer ce rendez-vous comme termine.');
    }
  }

  Future<void> _openCreatePrescription() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreatePrescriptionScreen(patient: widget.patient),
      ),
    );
    if (!mounted) return;
    if (created == true) {
      await _loadTreatments();
      _showSnackBar('Ordonnance creee avec succes.');
    }
  }

  Future<void> _markMedicationCompleted(Medication medication) async {
    try {
      await _treatmentsService.markMedicationCompleted(medication.id);
      if (!mounted) return;
      await _loadTreatments();
      _showSnackBar('Traitement marque comme termine.');
    } on TreatmentsException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Impossible de marquer le traitement termine.');
    }
  }

  Future<void> _cancelMedication(Medication medication) async {
    try {
      await _treatmentsService.cancelMedication(medication.id);
      if (!mounted) return;
      await _loadTreatments();
      _showSnackBar('Traitement annule.');
    } on TreatmentsException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Impossible d annuler ce traitement.');
    }
  }

  Future<void> _markMedicationTaken(Medication medication) async {
    try {
      await _treatmentsService.createMedicationIntake(
        medicationId: medication.id,
        status: MedicationIntake.statusTaken,
      );
      if (!mounted) return;
      await _loadTreatments();
      _showSnackBar('Prise enregistree: medicament pris.');
    } on TreatmentsException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Impossible d enregistrer cette prise.');
    }
  }

  Future<void> _markMedicationMissed(Medication medication) async {
    try {
      await _treatmentsService.createMedicationIntake(
        medicationId: medication.id,
        status: MedicationIntake.statusMissed,
      );
      if (!mounted) return;
      await _loadTreatments();
      _showSnackBar('Prise enregistree: medicament manque.');
    } on TreatmentsException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Impossible d enregistrer cette prise.');
    }
  }

  Future<void> _openAddAllergyDialog() async {
    final allergenController = TextEditingController();
    final reactionController = TextEditingController();
    final notesController = TextEditingController();
    String? allergenErrorText;
    var severity = PatientAllergy.severityModerate;

    final payload = await showDialog<_AllergyDialogPayload>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Ajouter allergie'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: allergenController,
                      onChanged: (_) {
                        if (allergenErrorText == null) return;
                        if (allergenController.text.trim().isEmpty) return;
                        setLocalState(() => allergenErrorText = null);
                      },
                      decoration: InputDecoration(
                        labelText: 'Substance / medicament',
                        prefixIcon: const Icon(Icons.warning_amber_outlined),
                        errorText: allergenErrorText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: reactionController,
                      decoration: const InputDecoration(
                        labelText: 'Reaction',
                        prefixIcon: Icon(Icons.healing_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      value: severity,
                      items: const [
                        DropdownMenuItem(
                          value: PatientAllergy.severityLow,
                          child: Text('Faible'),
                        ),
                        DropdownMenuItem(
                          value: PatientAllergy.severityModerate,
                          child: Text('Moderee'),
                        ),
                        DropdownMenuItem(
                          value: PatientAllergy.severityHigh,
                          child: Text('Elevee'),
                        ),
                        DropdownMenuItem(
                          value: PatientAllergy.severityCritical,
                          child: Text('Critique'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => severity = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Severite',
                        prefixIcon: Icon(Icons.report_problem_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.note_alt_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    final allergen = allergenController.text.trim();
                    if (allergen.isEmpty) {
                      setLocalState(
                        () => allergenErrorText = 'Substance obligatoire',
                      );
                      return;
                    }
                    Navigator.of(context).pop(
                      _AllergyDialogPayload(
                        allergen: allergen,
                        reaction: reactionController.text.trim(),
                        severity: severity,
                        notes: notesController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );

    allergenController.dispose();
    reactionController.dispose();
    notesController.dispose();

    if (payload == null) return;

    try {
      await _treatmentsService.addAllergy(
        patientId: widget.patient.id,
        allergen: payload.allergen,
        reaction: payload.reaction,
        severity: payload.severity,
        notes: payload.notes,
      );
      if (!mounted) return;
      await _loadTreatments();
      _showSnackBar('Allergie ajoutee avec succes.');
    } on TreatmentsException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Impossible d ajouter cette allergie.');
    }
  }

  void _notifyAppointmentsChanged() {
    final notifier = widget.appointmentsRevision;
    if (notifier == null) return;
    notifier.value = notifier.value + 1;
  }

  String _appointmentStatusLabel(String status) {
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

  Color _appointmentStatusColor(String status, BuildContext context) {
    switch (AppointmentItem.normalizeStatus(status)) {
      case AppointmentItem.statusDone:
        return Colors.green.shade700;
      case AppointmentItem.statusCancelled:
        return Colors.orange.shade700;
      case AppointmentItem.statusMissed:
        return Colors.red.shade700;
      case AppointmentItem.statusScheduled:
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  BadgeTone _medicationBadgeTone(Medication medication) {
    if (medication.isCompleted) {
      return BadgeTone.success;
    }
    if (medication.isCancelled) {
      return BadgeTone.warning;
    }
    return BadgeTone.primary;
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$d/$m/${date.year} $h:$min';
  }

  String? _doctorNameForId(int? doctorId) {
    if (doctorId == null) return null;
    return _doctorNamesById[doctorId] ?? 'Medecin #$doctorId';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final prescriptionsById = {
      for (final prescription in _prescriptions) prescription.id: prescription,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Fiche patient')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.patient.fullName,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Text('ID: ${widget.patient.code}'),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Age: ${widget.patient.age} ans'),
                          const SizedBox(width: AppSpacing.sm),
                          StatusBadge(label: widget.patient.status.label),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text('CIN: ${widget.patient.cin}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Traitements',
                action: _isDoctor
                    ? TextButton.icon(
                        onPressed: _openCreatePrescription,
                        icon: const Icon(Icons.add),
                        label: const Text('Nouvelle ordonnance'),
                      )
                    : null,
                child: _buildTreatmentsSection(
                  prescriptionsById: prescriptionsById,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Historique medical',
                action: _isDoctor
                    ? TextButton.icon(
                        onPressed: _openAddAllergyDialog,
                        icon: const Icon(Icons.add_alert_outlined),
                        label: const Text('Ajouter allergie'),
                      )
                    : null,
                child: _buildHistorySection(),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Rendez-vous',
                action: _isDoctor
                    ? TextButton.icon(
                        onPressed: _openCreateAppointment,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter'),
                      )
                    : null,
                child: _buildAppointmentsSection(),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Suivi des prises',
                child: _buildIntakesSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTreatmentsSection({
    required Map<int, Prescription> prescriptionsById,
  }) {
    if (_isLoadingTreatments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_treatmentsError != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Chargement impossible',
        message: _treatmentsError!,
      );
    }

    if (_activeMedications.isEmpty) {
      return const EmptyState(
        icon: Icons.medication_outlined,
        title: 'Aucun traitement actif',
        message: 'Aucun medicament en cours pour ce patient.',
      );
    }

    final latestIntakeByMedication = <int, MedicationIntake>{};
    for (final intake in _medicationIntakes) {
      final existing = latestIntakeByMedication[intake.medicationId];
      if (existing == null || intake.takenAt.isAfter(existing.takenAt)) {
        latestIntakeByMedication[intake.medicationId] = intake;
      }
    }

    return Column(
      children: _activeMedications
          .map(
            (medication) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _MedicationListTile(
                medication: medication,
                prescription: medication.prescriptionId == null
                    ? null
                    : prescriptionsById[medication.prescriptionId],
                latestIntake: latestIntakeByMedication[medication.id],
                prescriberName: _doctorNameForId(medication.doctorId),
                statusTone: _medicationBadgeTone(medication),
                onMarkCompleted: _isDoctor && medication.canMarkCompleted
                    ? () => _markMedicationCompleted(medication)
                    : null,
                onCancel: _isDoctor && medication.canCancel
                    ? () => _cancelMedication(medication)
                    : null,
                onMarkTaken: !_isDoctor && medication.isActive
                    ? () => _markMedicationTaken(medication)
                    : null,
                onMarkMissed: !_isDoctor && medication.isActive
                    ? () => _markMedicationMissed(medication)
                    : null,
                formatDate: _formatDate,
                formatDateTime: _formatDateTime,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildHistorySection() {
    if (_isLoadingTreatments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_treatmentsError != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Chargement impossible',
        message: _treatmentsError!,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ordonnances',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_prescriptions.isEmpty)
          const Text('Aucune ordonnance pour le moment.')
        else
          ..._prescriptions.map((prescription) {
            final doctorName = _doctorNameForId(prescription.doctorId);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.receipt_long_outlined),
              ),
              title: Text('Ordonnance #${prescription.id}'),
              subtitle: Text(
                'Date: ${_formatDate(prescription.prescriptionDate)}'
                '${doctorName == null ? '' : '\nPrescripteur: $doctorName'}'
                '${(prescription.notes ?? '').trim().isEmpty ? '' : '\n${prescription.notes!.trim()}'}',
              ),
              isThreeLine: true,
            );
          }),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Medicaments termines / annules',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_archivedMedications.isEmpty)
          const Text('Aucun medicament termine dans l historique.')
        else
          ..._archivedMedications.map(
            (medication) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.history_outlined)),
              title: Text('${medication.name} - ${medication.dosage}'),
              subtitle: Text(
                'Statut: ${medication.statusLabelFr}'
                '\nDebut: ${_formatDate(medication.startDate)}'
                '${medication.endDate == null ? '' : '  -  Fin: ${_formatDate(medication.endDate!)}'}',
              ),
              isThreeLine: true,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Allergies',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_allergies.isEmpty)
          const Text('Aucune allergie enregistree.')
        else
          ..._allergies.map((allergy) {
            final doctorName = _doctorNameForId(allergy.doctorId);
            final date = allergy.createdAt;
            final reaction = (allergy.reaction ?? '').trim();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.warning_outlined)),
              title: Text('${allergy.allergen} - ${allergy.severityLabelFr}'),
              subtitle: Text(
                '${reaction.isEmpty ? 'Reaction non precisee' : reaction}'
                '${date == null ? '' : '\nDate: ${_formatDate(date)}'}'
                '${doctorName == null ? '' : '\nNotee par: $doctorName'}',
              ),
              isThreeLine: true,
            );
          }),
      ],
    );
  }

  Widget _buildAppointmentsSection() {
    if (_isLoadingAppointments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_appointmentsError != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Chargement impossible',
        message: _appointmentsError!,
      );
    }

    if (_appointments.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'Aucun rendez-vous',
        message: 'Ce patient n a pas encore de rendez-vous planifie.',
      );
    }

    return Column(
      children: _appointments
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _AppointmentListTile(
                item: item,
                statusLabel: _appointmentStatusLabel(item.effectiveStatus),
                statusColor: _appointmentStatusColor(
                  item.effectiveStatus,
                  context,
                ),
                onEdit: () => _openEditAppointment(item),
                onMarkCompleted: _isDoctor && item.canMarkCompleted
                    ? () => _markAppointmentCompleted(item)
                    : null,
                onDelete: () => _deleteAppointment(item),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildIntakesSection() {
    if (_isLoadingTreatments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_treatmentsError != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Chargement impossible',
        message: _treatmentsError!,
      );
    }

    if (_medicationIntakes.isEmpty) {
      return const EmptyState(
        icon: Icons.fact_check_outlined,
        title: 'Aucune prise enregistree',
        message: 'Les declarations pris/manque apparaitront ici.',
      );
    }

    final medicationNameById = <int, String>{
      for (final medication in [..._activeMedications, ..._archivedMedications])
        medication.id: medication.name,
    };

    return Column(
      children: _medicationIntakes.take(12).map((intake) {
        final medicationName =
            medicationNameById[intake.medicationId] ??
            'Medicament #${intake.medicationId}';
        final comment = (intake.comment ?? '').trim();
        final tone = intake.isTaken ? BadgeTone.success : BadgeTone.warning;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.checklist_outlined)),
          title: Text('$medicationName - ${intake.statusLabelFr}'),
          subtitle: Text(
            '${_formatDateTime(intake.takenAt)}${comment.isEmpty ? '' : '\n$comment'}',
          ),
          isThreeLine: comment.isNotEmpty,
          trailing: StatusBadge(label: intake.statusLabelFr, tone: tone),
        );
      }).toList(),
    );
  }
}

class _MedicationListTile extends StatelessWidget {
  const _MedicationListTile({
    required this.medication,
    required this.prescription,
    required this.latestIntake,
    required this.prescriberName,
    required this.statusTone,
    required this.onMarkCompleted,
    required this.onCancel,
    required this.onMarkTaken,
    required this.onMarkMissed,
    required this.formatDate,
    required this.formatDateTime,
  });

  final Medication medication;
  final Prescription? prescription;
  final MedicationIntake? latestIntake;
  final String? prescriberName;
  final BadgeTone statusTone;
  final VoidCallback? onMarkCompleted;
  final VoidCallback? onCancel;
  final VoidCallback? onMarkTaken;
  final VoidCallback? onMarkMissed;
  final String Function(DateTime date) formatDate;
  final String Function(DateTime date) formatDateTime;

  @override
  Widget build(BuildContext context) {
    final details = <String>[];
    details.add('Frequence: ${medication.frequency}');

    final form = (medication.form ?? '').trim();
    if (form.isNotEmpty) {
      details.add('Forme: $form');
    }

    final quantity = (medication.quantity ?? '').trim();
    if (quantity.isNotEmpty) {
      details.add('Quantite: $quantity');
    }

    final period = (medication.period ?? '').trim();
    if (period.isNotEmpty) {
      details.add('Periode: $period');
    }

    details.add('Debut: ${formatDate(medication.startDate)}');
    if (medication.endDate != null) {
      details.add('Fin: ${formatDate(medication.endDate!)}');
    }

    final prescriptionDate = prescription?.prescriptionDate;
    if (prescriptionDate != null) {
      details.add('Date ordonnance: ${formatDate(prescriptionDate)}');
    }

    if ((prescriberName ?? '').trim().isNotEmpty) {
      details.add('Prescripteur: ${prescriberName!.trim()}');
    }

    final instructions = (medication.instructions ?? '').trim();
    if (instructions.isNotEmpty) {
      details.add('Instructions: $instructions');
    }

    final intake = latestIntake;
    if (intake != null) {
      details.add(
        'Derniere prise: ${intake.statusLabelFr} (${formatDateTime(intake.takenAt)})',
      );
      final intakeComment = (intake.comment ?? '').trim();
      if (intakeComment.isNotEmpty) {
        details.add('Commentaire prise: $intakeComment');
      }
    }

    final hasActions =
        onMarkCompleted != null ||
        onCancel != null ||
        onMarkTaken != null ||
        onMarkMissed != null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.medication_outlined)),
      title: Row(
        children: [
          Expanded(child: Text('${medication.name} - ${medication.dosage}')),
          StatusBadge(label: medication.statusLabelFr, tone: statusTone),
        ],
      ),
      subtitle: Text(details.join('\n')),
      isThreeLine: true,
      trailing: hasActions
          ? PopupMenuButton<_MedicationMenuAction>(
              onSelected: (action) {
                switch (action) {
                  case _MedicationMenuAction.markCompleted:
                    final callback = onMarkCompleted;
                    if (callback != null) {
                      callback();
                    }
                    return;
                  case _MedicationMenuAction.cancel:
                    final callback = onCancel;
                    if (callback != null) {
                      callback();
                    }
                    return;
                  case _MedicationMenuAction.markTaken:
                    final callback = onMarkTaken;
                    if (callback != null) {
                      callback();
                    }
                    return;
                  case _MedicationMenuAction.markMissed:
                    final callback = onMarkMissed;
                    if (callback != null) {
                      callback();
                    }
                    return;
                }
              },
              itemBuilder: (context) => [
                if (onMarkCompleted != null)
                  const PopupMenuItem(
                    value: _MedicationMenuAction.markCompleted,
                    child: Text('Marquer termine'),
                  ),
                if (onCancel != null)
                  const PopupMenuItem(
                    value: _MedicationMenuAction.cancel,
                    child: Text('Annuler traitement'),
                  ),
                if (onMarkTaken != null)
                  const PopupMenuItem(
                    value: _MedicationMenuAction.markTaken,
                    child: Text('Indiquer pris'),
                  ),
                if (onMarkMissed != null)
                  const PopupMenuItem(
                    value: _MedicationMenuAction.markMissed,
                    child: Text('Indiquer manque'),
                  ),
              ],
            )
          : null,
    );
  }
}

class _AppointmentListTile extends StatelessWidget {
  const _AppointmentListTile({
    required this.item,
    required this.statusLabel,
    required this.statusColor,
    required this.onEdit,
    required this.onMarkCompleted,
    required this.onDelete,
  });

  final AppointmentItem item;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback? onMarkCompleted;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final notes = (item.notes ?? '').trim();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.event_note_outlined)),
      title: Text('${item.dateLabel} - ${item.timeLabel}'),
      subtitle: notes.isEmpty
          ? Text(
              'Statut: $statusLabel',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
            )
          : Text('Statut: $statusLabel\n$notes'),
      isThreeLine: notes.isNotEmpty,
      trailing: PopupMenuButton<_AppointmentMenuAction>(
        onSelected: (action) {
          switch (action) {
            case _AppointmentMenuAction.edit:
              onEdit();
              return;
            case _AppointmentMenuAction.markCompleted:
              final callback = onMarkCompleted;
              if (callback != null) {
                callback();
              }
              return;
            case _AppointmentMenuAction.delete:
              onDelete();
              return;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _AppointmentMenuAction.edit,
            child: Text('Modifier'),
          ),
          if (onMarkCompleted != null)
            const PopupMenuItem(
              value: _AppointmentMenuAction.markCompleted,
              child: Text('Marquer termine'),
            ),
          const PopupMenuItem(
            value: _AppointmentMenuAction.delete,
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

enum _MedicationMenuAction { markCompleted, cancel, markTaken, markMissed }

enum _AppointmentMenuAction { edit, markCompleted, delete }

class _AllergyDialogPayload {
  const _AllergyDialogPayload({
    required this.allergen,
    required this.reaction,
    required this.severity,
    required this.notes,
  });

  final String allergen;
  final String reaction;
  final String severity;
  final String notes;
}
