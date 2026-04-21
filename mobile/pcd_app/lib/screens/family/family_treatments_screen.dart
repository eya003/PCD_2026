import 'package:flutter/material.dart';

import '../../models/family_permissions.dart';
import '../../models/medication.dart';
import '../../models/medication_calendar.dart';
import '../../models/patient_summary.dart';
import '../../services/medication_calendar_service.dart';
import '../../services/treatments_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';
import 'family_medication_calendar_screen.dart';
import 'family_medication_detail_screen.dart';

/// Dedicated treatments screen for family users.
/// Shows active and archived medications in two tabs.
class FamilyTreatmentsScreen extends StatefulWidget {
  const FamilyTreatmentsScreen({
    super.key,
    required this.patient,
    required this.isAdmin,
  });

  final PatientSummary patient;
  final bool isAdmin;

  @override
  State<FamilyTreatmentsScreen> createState() => _FamilyTreatmentsScreenState();
}

class _FamilyTreatmentsScreenState extends State<FamilyTreatmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TreatmentsService _service;
  late final MedicationCalendarService _calendarService;
  late final TabController _tabController;
  FamilyPermissions get _permissions =>
      FamilyPermissions(isAdmin: widget.isAdmin);

  bool _isLoading = true;
  String? _error;
  PatientTreatmentData? _data;
  Map<int, ScheduledMedicationDose?> _nextDoseByMedicationId = const {};

  @override
  void initState() {
    super.initState();
    _service = TreatmentsService();
    _calendarService = MedicationCalendarService();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchPatientTreatmentData(
        patientId: widget.patient.id,
      );
      final nextDoseByMedicationId = await _loadNextDoses(
        data.activeMedications,
      );

      if (!mounted) return;
      setState(() {
        _data = data;
        _nextDoseByMedicationId = nextDoseByMedicationId;
        _isLoading = false;
      });
    } on TreatmentsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Impossible de charger les traitements.';
      });
    }
  }

  Future<Map<int, ScheduledMedicationDose?>> _loadNextDoses(
    List<Medication> medications,
  ) async {
    if (medications.isEmpty) return const {};

    final now = DateTime.now();
    final end = now.add(const Duration(days: 30));

    final entries = await Future.wait(
      medications.map((medication) async {
        try {
          final doses = await _calendarService.fetchMedicationScheduledDoses(
            medicationId: medication.id,
            startDate: now,
            endDate: end,
          );
          return MapEntry(medication.id, _pickNextDose(doses));
        } catch (_) {
          return MapEntry<int, ScheduledMedicationDose?>(medication.id, null);
        }
      }),
    );

    return Map<int, ScheduledMedicationDose?>.fromEntries(entries);
  }

  ScheduledMedicationDose? _pickNextDose(List<ScheduledMedicationDose> doses) {
    final now = DateTime.now();
    final sorted = List<ScheduledMedicationDose>.from(doses)
      ..sort(
        (a, b) => a.effectiveScheduledFor.compareTo(b.effectiveScheduledFor),
      );

    for (final dose in sorted) {
      if (dose.normalizedStatus == ScheduledMedicationDose.statusPending &&
          !dose.effectiveScheduledFor.isBefore(now)) {
        return dose;
      }
    }
    return null;
  }

  Future<void> _openMedication(Medication medication) async {
    final intakes =
        _data?.intakes.where((i) => i.medicationId == medication.id).toList() ??
        [];

    final refreshNeeded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FamilyMedicationDetailScreen(
          medication: medication,
          patientId: widget.patient.id,
          intakes: intakes,
          isAdmin: _permissions.isAdmin,
        ),
      ),
    );

    if (refreshNeeded == true && mounted) {
      _load();
    }
  }

  Future<void> _openMedicationCalendar() async {
    final refreshNeeded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FamilyMedicationCalendarScreen(
          patientId: widget.patient.id,
          patientName: widget.patient.fullName,
          isAdmin: _permissions.isAdmin,
        ),
      ),
    );
    if (refreshNeeded == true && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Calendrier medicaments',
            onPressed: _openMedicationCalendar,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
        title: Text('Traitements - ${widget.patient.firstName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Actifs'),
            Tab(text: 'Termines'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorBody(message: _error!, onRetry: _load)
          : TabBarView(
              controller: _tabController,
              children: [
                _MedicationList(
                  medications: _data?.activeMedications ?? [],
                  emptyIcon: Icons.medication_outlined,
                  emptyTitle: 'Aucun traitement actif',
                  emptyMessage: 'Aucun medicament en cours pour ce patient.',
                  isActive: true,
                  nextDoseByMedicationId: _nextDoseByMedicationId,
                  onTap: _openMedication,
                ),
                _MedicationList(
                  medications: _data?.archivedMedications ?? [],
                  emptyIcon: Icons.history_outlined,
                  emptyTitle: 'Aucun traitement termine',
                  emptyMessage: 'Aucun medicament archive pour ce patient.',
                  isActive: false,
                  nextDoseByMedicationId: _nextDoseByMedicationId,
                  onTap: _openMedication,
                ),
              ],
            ),
    );
  }
}

class _MedicationList extends StatelessWidget {
  const _MedicationList({
    required this.medications,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.isActive,
    required this.nextDoseByMedicationId,
    required this.onTap,
  });

  final List<Medication> medications;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final bool isActive;
  final Map<int, ScheduledMedicationDose?> nextDoseByMedicationId;
  final Future<void> Function(Medication) onTap;

  @override
  Widget build(BuildContext context) {
    if (medications.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: medications.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final medication = medications[index];
        return _MedicationCard(
          medication: medication,
          isActive: isActive,
          nextDose: nextDoseByMedicationId[medication.id],
          onTap: () => onTap(medication),
        );
      },
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.medication,
    required this.isActive,
    required this.nextDose,
    required this.onTap,
  });

  final Medication medication;
  final bool isActive;
  final ScheduledMedicationDose? nextDose;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = isActive
        ? Colors.green.shade700
        : colorScheme.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _MetaChip(
                          icon: Icons.science_outlined,
                          text: medication.dosage,
                        ),
                        _MetaChip(
                          icon: Icons.repeat_outlined,
                          text: medication.frequency,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _nextDoseLabel(nextDose, isActive),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: nextDose == null
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dateRange(medication),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  String _dateRange(Medication med) {
    final start = _fmt(med.startDate);
    final end = med.endDate != null ? _fmt(med.endDate!) : '...';
    return 'Du $start au $end';
  }

  String _nextDoseLabel(
    ScheduledMedicationDose? dose,
    bool isActiveMedication,
  ) {
    if (!isActiveMedication) {
      return 'Traitement archive';
    }
    if (dose == null) {
      return 'Prochaine prise: non planifiee';
    }
    return 'Prochaine prise: ${_fmtDateTime(dose.effectiveScheduledFor)}';
  }

  String _fmt(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  String _fmtDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m $hh:$mm';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Reessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
