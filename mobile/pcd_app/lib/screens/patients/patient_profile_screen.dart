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
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/prescription_print_models.dart';
import '../../utils/prescription_printer.dart';
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
      // Role fallback comes from _loadTreatments() when available.
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

      if (!mounted) return;
      setState(() {
        _appointments = appointments;
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
    final payload = await showDialog<_AllergyDialogPayload>(
      context: context,
      builder: (_) => const _AddAllergyDialog(),
    );

    if (!mounted || payload == null) return;

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

  Future<void> _openPrescriptionDetails(Prescription prescription) async {
    final medications = _medicationsForPrescription(prescription.id);
    final doctorName =
        _doctorNameForId(prescription.doctorId) ??
        'Medecin #${prescription.doctorId}';

    await showDialog<void>(
      context: context,
      builder: (context) => _PrescriptionDetailsDialog(
        prescription: prescription,
        medications: medications,
        patient: widget.patient,
        doctorName: doctorName,
        canPrint: _isDoctor,
        onPrint: () => _printPrescriptionDetails(prescription, medications),
        formatDate: _formatDate,
      ),
    );
  }

  Future<void> _openMedicationDetails({
    required Medication medication,
    Prescription? prescription,
    MedicationIntake? latestIntake,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _MedicationDetailsDialog(
        medication: medication,
        prescription: prescription,
        latestIntake: latestIntake,
        prescriberName: _doctorNameForId(medication.doctorId),
        formatDate: _formatDate,
        formatDateTime: _formatDateTime,
      ),
    );
  }

  Future<void> _printPrescriptionDetails(
    Prescription prescription,
    List<Medication> medications,
  ) async {
    final doctorName =
        _doctorNameForId(prescription.doctorId) ??
        'Medecin #${prescription.doctorId}';
    final payload = PrescriptionPrintPayload(
      doctorDisplayName: _formatDoctorForPrint(doctorName),
      patientFullName: widget.patient.fullName,
      patientCode: widget.patient.code,
      patientCin: widget.patient.cin,
      patientAgeLabel: '${widget.patient.age} ans',
      prescriptionNumber: '#${prescription.id}',
      prescriptionDate: _formatDate(prescription.prescriptionDate),
      prescriptionStatus: prescription.statusLabelFr,
      prescriptionNotes: prescription.notes,
      medications: medications
          .map(
            (item) => PrescriptionPrintMedication(
              name: item.name,
              dosage: item.dosage,
              frequency: item.frequency,
              quantity: item.quantity,
              period: item.period,
              form: item.form,
              startDate: _formatDate(item.startDate),
              endDate: item.endDate == null ? null : _formatDate(item.endDate!),
              instructions: item.instructions,
            ),
          )
          .toList(),
    );

    final printed = await printPrescription(payload);
    if (!mounted) return;
    if (!printed) {
      _showSnackBar(
        'Impression indisponible sur cette plateforme. Utilisez la version web.',
      );
    }
  }

  String _formatDoctorForPrint(String name) {
    final clean = name.trim();
    if (clean.toLowerCase().startsWith('dr')) {
      return clean;
    }
    return 'Dr. $clean';
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

  Color _appointmentStatusColor(String status) {
    switch (AppointmentItem.normalizeStatus(status)) {
      case AppointmentItem.statusDone:
        return Colors.green.shade700;
      case AppointmentItem.statusCancelled:
        return Colors.orange.shade700;
      case AppointmentItem.statusMissed:
        return AppColors.statusRed;
      case AppointmentItem.statusScheduled:
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  BadgeTone _medicationBadgeTone(Medication medication) {
    if (medication.isCompleted) return BadgeTone.success;
    if (medication.isCancelled) return BadgeTone.warning;
    return BadgeTone.primary;
  }

  BadgeTone _prescriptionBadgeTone(Prescription prescription) {
    switch (prescription.normalizedStatus) {
      case Prescription.statusCompleted:
        return BadgeTone.success;
      case Prescription.statusCancelled:
        return BadgeTone.warning;
      case Prescription.statusActive:
      default:
        return BadgeTone.primary;
    }
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

  Map<int, Medication> _allMedicationsById() {
    final merged = <int, Medication>{};
    for (final item in [..._activeMedications, ..._archivedMedications]) {
      merged[item.id] = item;
    }
    return merged;
  }

  List<Medication> _medicationsForPrescription(int prescriptionId) {
    final medications = _allMedicationsById().values
        .where((item) => item.prescriptionId == prescriptionId)
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return medications;
  }

  Map<int, MedicationIntake> _latestIntakesByMedication() {
    final latest = <int, MedicationIntake>{};
    for (final intake in _medicationIntakes) {
      final existing = latest[intake.medicationId];
      if (existing == null || intake.takenAt.isAfter(existing.takenAt)) {
        latest[intake.medicationId] = intake;
      }
    }
    return latest;
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
    final medicationById = _allMedicationsById();
    final medicationsByPrescription = <int, List<Medication>>{};
    for (final medication in medicationById.values) {
      final prescriptionId = medication.prescriptionId;
      if (prescriptionId == null) continue;
      medicationsByPrescription
          .putIfAbsent(prescriptionId, () => <Medication>[])
          .add(medication);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Fiche patient')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _buildPatientHeaderCard(),
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
                child: _buildHistorySection(
                  prescriptionsById: prescriptionsById,
                  medicationsByPrescription: medicationsByPrescription,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Allergies',
                action: _isDoctor
                    ? TextButton.icon(
                        onPressed: _openAddAllergyDialog,
                        icon: const Icon(Icons.add_alert_outlined),
                        label: const Text('Ajouter allergie'),
                      )
                    : null,
                child: _buildAllergiesSection(),
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
                child: _buildIntakesSection(medicationById: medicationById),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientHeaderCard() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.patient.fullName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          StatusBadge(label: widget.patient.status.label),
                          _HeaderFactChip(
                            icon: Icons.badge_outlined,
                            text: 'ID ${widget.patient.code}',
                          ),
                          _HeaderFactChip(
                            icon: Icons.cake_outlined,
                            text: '${widget.patient.age} ans',
                          ),
                          _HeaderFactChip(
                            icon: Icons.credit_card_outlined,
                            text: 'CIN ${widget.patient.cin}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreatmentsSection({
    required Map<int, Prescription> prescriptionsById,
  }) {
    if (_isLoadingTreatments) {
      return const _LoadingList(itemCount: 3);
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

    final latestIntakes = _latestIntakesByMedication();

    return Column(
      children: _activeMedications
          .map(
            (medication) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _MedicationOverviewCard(
                medication: medication,
                prescription: medication.prescriptionId == null
                    ? null
                    : prescriptionsById[medication.prescriptionId],
                latestIntake: latestIntakes[medication.id],
                prescriberName: _doctorNameForId(medication.doctorId),
                statusTone: _medicationBadgeTone(medication),
                onTap: () => _openMedicationDetails(
                  medication: medication,
                  prescription: medication.prescriptionId == null
                      ? null
                      : prescriptionsById[medication.prescriptionId],
                  latestIntake: latestIntakes[medication.id],
                ),
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

  Widget _buildHistorySection({
    required Map<int, Prescription> prescriptionsById,
    required Map<int, List<Medication>> medicationsByPrescription,
  }) {
    if (_isLoadingTreatments) {
      return const _LoadingList(itemCount: 3);
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
        _SubSectionHeader(
          icon: Icons.receipt_long_outlined,
          title: 'Ordonnances',
          subtitle: 'Historique des prescriptions',
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_prescriptions.isEmpty)
          const _InlineEmptyMessage(
            message: 'Aucune ordonnance disponible pour ce patient.',
          )
        else
          ..._prescriptions.map((prescription) {
            final medications = medicationsByPrescription[prescription.id] ?? [];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PrescriptionHistoryCard(
                prescription: prescription,
                medicationsCount: medications.length,
                doctorName:
                    _doctorNameForId(prescription.doctorId) ??
                    'Medecin #${prescription.doctorId}',
                statusTone: _prescriptionBadgeTone(prescription),
                formatDate: _formatDate,
                onTap: () => _openPrescriptionDetails(prescription),
              ),
            );
          }),
        const SizedBox(height: AppSpacing.lg),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.lg),
        _SubSectionHeader(
          icon: Icons.history_toggle_off_outlined,
          title: 'Medicaments termines et annules',
          subtitle: 'Fin ou interruption des traitements',
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_archivedMedications.isEmpty)
          const _InlineEmptyMessage(
            message: 'Aucun medicament termine ou annule dans l historique.',
          )
        else
          ..._archivedMedications.map((medication) {
            final prescription = medication.prescriptionId == null
                ? null
                : prescriptionsById[medication.prescriptionId];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ArchivedMedicationCard(
                medication: medication,
                prescriberName: _doctorNameForId(medication.doctorId),
                formatDate: _formatDate,
                onTap: () => _openMedicationDetails(
                  medication: medication,
                  prescription: prescription,
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAllergiesSection() {
    if (_isLoadingTreatments) {
      return const _LoadingList(itemCount: 2);
    }

    if (_treatmentsError != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Chargement impossible',
        message: _treatmentsError!,
      );
    }

    if (_allergies.isEmpty) {
      return const EmptyState(
        icon: Icons.shield_outlined,
        title: 'Aucune allergie',
        message: 'Aucune allergie enregistree pour ce patient.',
      );
    }

    return Column(
      children: _allergies
          .map(
            (allergy) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AllergyCard(
                allergy: allergy,
                doctorName: _doctorNameForId(allergy.doctorId),
                formatDate: _formatDate,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAppointmentsSection() {
    if (_isLoadingAppointments) {
      return const _LoadingList(itemCount: 2);
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
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AppointmentListTile(
                item: item,
                statusLabel: _appointmentStatusLabel(item.effectiveStatus),
                statusColor: _appointmentStatusColor(item.effectiveStatus),
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

  Widget _buildIntakesSection({required Map<int, Medication> medicationById}) {
    if (_isLoadingTreatments) {
      return const _LoadingList(itemCount: 2);
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

    return Column(
      children: _medicationIntakes.take(12).map((intake) {
        final medicationName =
            medicationById[intake.medicationId]?.name ??
            'Medicament #${intake.medicationId}';
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _IntakeCard(
            medicationName: medicationName,
            intake: intake,
            formatDateTime: _formatDateTime,
          ),
        );
      }).toList(),
    );
  }
}

class _HeaderFactChip extends StatelessWidget {
  const _HeaderFactChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubSectionHeader extends StatelessWidget {
  const _SubSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryBlue, size: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineEmptyMessage extends StatelessWidget {
  const _InlineEmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(itemCount, (index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == itemCount - 1 ? 0 : AppSpacing.sm,
          ),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      }),
    );
  }
}

class _MedicationOverviewCard extends StatelessWidget {
  const _MedicationOverviewCard({
    required this.medication,
    required this.prescription,
    required this.latestIntake,
    required this.prescriberName,
    required this.statusTone,
    required this.onTap,
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
  final VoidCallback onTap;
  final VoidCallback? onMarkCompleted;
  final VoidCallback? onCancel;
  final VoidCallback? onMarkTaken;
  final VoidCallback? onMarkMissed;
  final String Function(DateTime date) formatDate;
  final String Function(DateTime date) formatDateTime;

  @override
  Widget build(BuildContext context) {
    final hasActions =
        onMarkCompleted != null ||
        onCancel != null ||
        onMarkTaken != null ||
        onMarkMissed != null;
    final form = (medication.form ?? '').trim();
    final quantity = (medication.quantity ?? '').trim();
    final period = (medication.period ?? '').trim();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dosage: ${medication.dosage}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (hasActions)
                    PopupMenuButton<_MedicationMenuAction>(
                      onSelected: (action) {
                        switch (action) {
                          case _MedicationMenuAction.markCompleted:
                            onMarkCompleted?.call();
                            return;
                          case _MedicationMenuAction.cancel:
                            onCancel?.call();
                            return;
                          case _MedicationMenuAction.markTaken:
                            onMarkTaken?.call();
                            return;
                          case _MedicationMenuAction.markMissed:
                            onMarkMissed?.call();
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
                    ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  StatusBadge(label: medication.statusLabelFr, tone: statusTone),
                  _InfoPill(
                    icon: Icons.schedule_outlined,
                    text: medication.frequency,
                  ),
                  if (form.isNotEmpty)
                    _InfoPill(icon: Icons.category_outlined, text: form),
                  if (quantity.isNotEmpty)
                    _InfoPill(icon: Icons.format_list_numbered, text: quantity),
                  if (period.isNotEmpty)
                    _InfoPill(icon: Icons.date_range_outlined, text: period),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Debut: ${formatDate(medication.startDate)}'
                '${medication.endDate == null ? '' : '  -  Fin: ${formatDate(medication.endDate!)}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if ((prescriberName ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Prescripteur: ${prescriberName!.trim()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (prescription != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Ordonnance #${prescription!.id} - ${formatDate(prescription!.prescriptionDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (latestIntake != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Derniere prise: ${latestIntake!.statusLabelFr} (${formatDateTime(latestIntake!.takenAt)})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: latestIntake!.isTaken
                        ? AppColors.statusGreen
                        : AppColors.statusOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PrescriptionHistoryCard extends StatelessWidget {
  const _PrescriptionHistoryCard({
    required this.prescription,
    required this.medicationsCount,
    required this.doctorName,
    required this.statusTone,
    required this.formatDate,
    required this.onTap,
  });

  final Prescription prescription;
  final int medicationsCount;
  final String doctorName;
  final BadgeTone statusTone;
  final String Function(DateTime date) formatDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final notes = (prescription.notes ?? '').trim();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Ordonnance #${prescription.id}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusBadge(
                    label: prescription.statusLabelFr,
                    tone: statusTone,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _InfoPill(
                    icon: Icons.event_outlined,
                    text: formatDate(prescription.prescriptionDate),
                  ),
                  _InfoPill(icon: Icons.person_outline, text: doctorName),
                  _InfoPill(
                    icon: Icons.medication_outlined,
                    text: '$medicationsCount medicament(s)',
                  ),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchivedMedicationCard extends StatelessWidget {
  const _ArchivedMedicationCard({
    required this.medication,
    required this.prescriberName,
    required this.formatDate,
    required this.onTap,
  });

  final Medication medication;
  final String? prescriberName;
  final String Function(DateTime date) formatDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCancelled = medication.isCancelled;
    final statusColor = isCancelled ? AppColors.statusOrange : AppColors.statusGreen;
    final statusIcon = isCancelled
        ? Icons.block_rounded
        : Icons.check_circle_outline_rounded;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.name,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dosage: ${medication.dosage}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          medication.statusLabelFr,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Frequence: ${medication.frequency}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Debut: ${formatDate(medication.startDate)}'
                '${medication.endDate == null ? '' : '  -  Fin: ${formatDate(medication.endDate!)}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if ((prescriberName ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Prescripteur: ${prescriberName!.trim()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AllergyCard extends StatelessWidget {
  const _AllergyCard({
    required this.allergy,
    required this.doctorName,
    required this.formatDate,
  });

  final PatientAllergy allergy;
  final String? doctorName;
  final String Function(DateTime date) formatDate;

  @override
  Widget build(BuildContext context) {
    final reaction = (allergy.reaction ?? '').trim();
    final notes = (allergy.notes ?? '').trim();
    final (severityBg, severityFg, severityIcon) = _severityStyle(
      allergy.normalizedSeverity,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    allergy.allergen,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: severityBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(severityIcon, size: 14, color: severityFg),
                      const SizedBox(width: 4),
                      Text(
                        allergy.severityLabelFr,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: severityFg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              reaction.isEmpty ? 'Reaction non precisee' : reaction,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Notes: $notes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (allergy.createdAt != null || (doctorName ?? '').trim().isNotEmpty)
              ...[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (allergy.createdAt != null)
                      _InfoPill(
                        icon: Icons.event_outlined,
                        text: formatDate(allergy.createdAt!),
                      ),
                    if ((doctorName ?? '').trim().isNotEmpty)
                      _InfoPill(
                        icon: Icons.person_outline,
                        text: doctorName!.trim(),
                      ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }

  (Color, Color, IconData) _severityStyle(String severity) {
    switch (severity) {
      case PatientAllergy.severityLow:
        return (
          AppColors.statusGreen.withOpacity(0.12),
          AppColors.statusGreen,
          Icons.shield_outlined,
        );
      case PatientAllergy.severityHigh:
        return (
          AppColors.statusOrange.withOpacity(0.15),
          AppColors.statusOrange,
          Icons.priority_high_rounded,
        );
      case PatientAllergy.severityCritical:
        return (
          AppColors.statusRed.withOpacity(0.12),
          AppColors.statusRed,
          Icons.warning_amber_rounded,
        );
      case PatientAllergy.severityModerate:
      default:
        return (
          AppColors.primaryBlue.withOpacity(0.1),
          AppColors.primaryBlue,
          Icons.report_problem_outlined,
        );
    }
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.event_note_outlined,
                size: 18,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.dateLabel} - ${item.timeLabel}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: statusColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          statusLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      notes,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<_AppointmentMenuAction>(
              onSelected: (action) {
                switch (action) {
                  case _AppointmentMenuAction.edit:
                    onEdit();
                    return;
                  case _AppointmentMenuAction.markCompleted:
                    onMarkCompleted?.call();
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
          ],
        ),
      ),
    );
  }
}

class _IntakeCard extends StatelessWidget {
  const _IntakeCard({
    required this.medicationName,
    required this.intake,
    required this.formatDateTime,
  });

  final String medicationName;
  final MedicationIntake intake;
  final String Function(DateTime date) formatDateTime;

  @override
  Widget build(BuildContext context) {
    final comment = (intake.comment ?? '').trim();
    final isTaken = intake.isTaken;
    final tone = isTaken ? BadgeTone.success : BadgeTone.warning;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    medicationName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusBadge(label: intake.statusLabelFr, tone: tone),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatDateTime(intake.takenAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                comment,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationDetailsDialog extends StatelessWidget {
  const _MedicationDetailsDialog({
    required this.medication,
    required this.prescription,
    required this.latestIntake,
    required this.prescriberName,
    required this.formatDate,
    required this.formatDateTime,
  });

  final Medication medication;
  final Prescription? prescription;
  final MedicationIntake? latestIntake;
  final String? prescriberName;
  final String Function(DateTime date) formatDate;
  final String Function(DateTime date) formatDateTime;

  @override
  Widget build(BuildContext context) {
    final fields = <_DialogFieldData>[
      _DialogFieldData(label: 'Nom', value: medication.name),
      _DialogFieldData(label: 'Dosage', value: medication.dosage),
      _DialogFieldData(label: 'Frequence', value: medication.frequency),
      if ((medication.quantity ?? '').trim().isNotEmpty)
        _DialogFieldData(label: 'Quantite', value: medication.quantity!.trim()),
      if ((medication.period ?? '').trim().isNotEmpty)
        _DialogFieldData(label: 'Periode', value: medication.period!.trim()),
      if ((medication.form ?? '').trim().isNotEmpty)
        _DialogFieldData(label: 'Forme', value: medication.form!.trim()),
      _DialogFieldData(label: 'Date debut', value: formatDate(medication.startDate)),
      if (medication.endDate != null)
        _DialogFieldData(
          label: 'Date fin',
          value: formatDate(medication.endDate!),
        ),
      _DialogFieldData(label: 'Statut', value: medication.statusLabelFr),
      if ((prescriberName ?? '').trim().isNotEmpty)
        _DialogFieldData(label: 'Prescripteur', value: prescriberName!.trim()),
      if (prescription != null)
        _DialogFieldData(
          label: 'Ordonnance',
          value:
              '#${prescription!.id} (${formatDate(prescription!.prescriptionDate)})',
        ),
    ];

    final instructions = (medication.instructions ?? '').trim();
    final intake = latestIntake;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail du traitement',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          medication.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: medication.statusLabelFr,
                    tone: medication.isCompleted
                        ? BadgeTone.success
                        : medication.isCancelled
                        ? BadgeTone.warning
                        : BadgeTone.primary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogSection(
                      title: 'Informations',
                      fields: fields,
                    ),
                    if (intake != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _DialogSection(
                        title: 'Derniere prise',
                        fields: [
                          _DialogFieldData(
                            label: 'Statut',
                            value: intake.statusLabelFr,
                          ),
                          _DialogFieldData(
                            label: 'Date',
                            value: formatDateTime(intake.takenAt),
                          ),
                          if ((intake.comment ?? '').trim().isNotEmpty)
                            _DialogFieldData(
                              label: 'Commentaire',
                              value: intake.comment!.trim(),
                            ),
                        ],
                      ),
                    ],
                    if (instructions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _DialogSection(
                        title: 'Instructions',
                        fields: [
                          _DialogFieldData(
                            label: 'Details',
                            value: instructions,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionDetailsDialog extends StatelessWidget {
  const _PrescriptionDetailsDialog({
    required this.prescription,
    required this.medications,
    required this.patient,
    required this.doctorName,
    required this.canPrint,
    required this.onPrint,
    required this.formatDate,
  });

  final Prescription prescription;
  final List<Medication> medications;
  final PatientSummary patient;
  final String doctorName;
  final bool canPrint;
  final Future<void> Function() onPrint;
  final String Function(DateTime date) formatDate;

  @override
  Widget build(BuildContext context) {
    final notes = (prescription.notes ?? '').trim();

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 780),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ordonnance #${prescription.id}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Date: ${formatDate(prescription.prescriptionDate)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: prescription.statusLabelFr,
                    tone: prescription.normalizedStatus == Prescription.statusCompleted
                        ? BadgeTone.success
                        : prescription.normalizedStatus ==
                              Prescription.statusCancelled
                        ? BadgeTone.warning
                        : BadgeTone.primary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogSection(
                      title: 'Informations patient',
                      fields: [
                        _DialogFieldData(label: 'Nom', value: patient.fullName),
                        _DialogFieldData(label: 'Code', value: patient.code),
                        _DialogFieldData(label: 'CIN', value: patient.cin),
                        _DialogFieldData(
                          label: 'Age',
                          value: '${patient.age} ans',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _DialogSection(
                      title: 'Informations ordonnance',
                      fields: [
                        _DialogFieldData(
                          label: 'Numero',
                          value: '#${prescription.id}',
                        ),
                        _DialogFieldData(
                          label: 'Date ordonnance',
                          value: formatDate(prescription.prescriptionDate),
                        ),
                        _DialogFieldData(label: 'Prescripteur', value: doctorName),
                        _DialogFieldData(
                          label: 'Statut',
                          value: prescription.statusLabelFr,
                        ),
                        if (notes.isNotEmpty)
                          _DialogFieldData(label: 'Notes', value: notes),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Medicaments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (medications.isEmpty)
                      const _InlineEmptyMessage(
                        message: 'Aucun medicament lie a cette ordonnance.',
                      )
                    else
                      ...medications.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _PrescriptionMedicationCard(
                            medication: item,
                            formatDate: formatDate,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                  if (canPrint)
                    OutlinedButton.icon(
                      onPressed: () => onPrint(),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Imprimer'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionMedicationCard extends StatelessWidget {
  const _PrescriptionMedicationCard({
    required this.medication,
    required this.formatDate,
  });

  final Medication medication;
  final String Function(DateTime date) formatDate;

  @override
  Widget build(BuildContext context) {
    final form = (medication.form ?? '').trim();
    final quantity = (medication.quantity ?? '').trim();
    final period = (medication.period ?? '').trim();
    final instructions = (medication.instructions ?? '').trim();

    final fields = <_DialogFieldData>[
      _DialogFieldData(label: 'Dosage', value: medication.dosage),
      _DialogFieldData(label: 'Frequence', value: medication.frequency),
      if (quantity.isNotEmpty) _DialogFieldData(label: 'Quantite', value: quantity),
      if (period.isNotEmpty) _DialogFieldData(label: 'Periode', value: period),
      if (form.isNotEmpty) _DialogFieldData(label: 'Forme', value: form),
      _DialogFieldData(label: 'Date debut', value: formatDate(medication.startDate)),
      if (medication.endDate != null)
        _DialogFieldData(label: 'Date fin', value: formatDate(medication.endDate!)),
      _DialogFieldData(label: 'Statut', value: medication.statusLabelFr),
      if (instructions.isNotEmpty)
        _DialogFieldData(label: 'Instructions', value: instructions),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        color: AppColors.surfaceAlt,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            medication.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...fields.map((field) => _DialogField(data: field)),
        ],
      ),
    );
  }
}

class _DialogSection extends StatelessWidget {
  const _DialogSection({required this.title, required this.fields});

  final String title;
  final List<_DialogFieldData> fields;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...fields.map((field) => _DialogField(data: field)),
        ],
      ),
    );
  }
}

class _DialogFieldData {
  const _DialogFieldData({required this.label, required this.value});

  final String label;
  final String value;
}

class _DialogField extends StatelessWidget {
  const _DialogField({required this.data});

  final _DialogFieldData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
          ),
          children: [
            TextSpan(
              text: '${data.label}: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: data.value),
          ],
        ),
      ),
    );
  }
}

enum _MedicationMenuAction { markCompleted, cancel, markTaken, markMissed }

enum _AppointmentMenuAction { edit, markCompleted, delete }

class _AddAllergyDialog extends StatefulWidget {
  const _AddAllergyDialog();

  @override
  State<_AddAllergyDialog> createState() => _AddAllergyDialogState();
}

class _AddAllergyDialogState extends State<_AddAllergyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _allergenController = TextEditingController();
  final _reactionController = TextEditingController();
  final _notesController = TextEditingController();
  String _severity = PatientAllergy.severityModerate;

  @override
  void dispose() {
    _allergenController.dispose();
    _reactionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = _AllergyDialogPayload(
      allergen: _allergenController.text.trim(),
      reaction: _reactionController.text.trim(),
      severity: _severity,
      notes: _notesController.text.trim(),
    );

    // Keep widget teardown safe by clearing inputs before closing the route.
    _allergenController.clear();
    _reactionController.clear();
    _notesController.clear();

    if (!mounted) return;
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajouter allergie',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _allergenController,
                    decoration: const InputDecoration(
                      labelText: 'Allergene',
                      prefixIcon: Icon(Icons.warning_amber_outlined),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Allergene obligatoire';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _reactionController,
                    decoration: const InputDecoration(
                      labelText: 'Reaction',
                      prefixIcon: Icon(Icons.healing_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: _severity,
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
                      setState(() => _severity = value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Severite',
                      prefixIcon: Icon(Icons.report_problem_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
