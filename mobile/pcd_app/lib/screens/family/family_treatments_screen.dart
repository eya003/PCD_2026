import 'package:flutter/material.dart';

import '../../models/family_permissions.dart';
import '../../models/medication.dart';
import '../../models/patient_summary.dart';
import '../../services/treatments_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';
import 'family_medication_detail_screen.dart';

/// Dedicated treatments screen for family users.
/// Shows active and archived medications in two tabs.
/// Extracted from FamilyPatientScreen to keep the dashboard focused.
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
  late final TabController _tabController;
  FamilyPermissions get _permissions => FamilyPermissions(isAdmin: widget.isAdmin);

  bool _isLoading = true;
  String? _error;
  PatientTreatmentData? _data;

  @override
  void initState() {
    super.initState();
    _service = TreatmentsService();
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
      if (!mounted) return;
      setState(() {
        _data = data;
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

  Future<void> _openMedication(Medication medication) async {
    final intakes = _data?.intakes
            .where((i) => i.medicationId == medication.id)
            .toList() ??
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Traitements — ${widget.patient.firstName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Actifs'),
            Tab(text: 'Terminés'),
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
                      emptyMessage: 'Aucun médicament en cours pour ce patient.',
                      isActive: true,
                      onTap: _openMedication,
                    ),
                    _MedicationList(
                      medications: _data?.archivedMedications ?? [],
                      emptyIcon: Icons.history_outlined,
                      emptyTitle: 'Aucun traitement terminé',
                      emptyMessage: 'Aucun médicament archivé pour ce patient.',
                      isActive: false,
                      onTap: _openMedication,
                    ),
                  ],
                ),
    );
  }
}

// ── Medication list ───────────────────────────────────────────────────────────

class _MedicationList extends StatelessWidget {
  const _MedicationList({
    required this.medications,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.isActive,
    required this.onTap,
  });

  final List<Medication> medications;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final bool isActive;
  final Future<void> Function(Medication) onTap;

  @override
  Widget build(BuildContext context) {
    if (medications.isEmpty) {
      return EmptyState(icon: emptyIcon, title: emptyTitle, message: emptyMessage);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: medications.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _MedicationCard(
        medication: medications[index],
        isActive: isActive,
        onTap: () => onTap(medications[index]),
      ),
    );
  }
}

// ── Medication card ───────────────────────────────────────────────────────────

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.medication,
    required this.isActive,
    required this.onTap,
  });

  final Medication medication;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor =
        isActive ? Colors.green.shade700 : colorScheme.onSurfaceVariant;

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
                    const SizedBox(height: 2),
                    Text(
                      '${medication.dosage}  •  ${medication.frequency}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (medication.startDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _dateRange(medication),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
    final start = _fmt(med.startDate!);
    final end = med.endDate != null ? _fmt(med.endDate!) : '...';
    return 'Du $start au $end';
  }

  String _fmt(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

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
            Icon(Icons.cloud_off_outlined,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: AppSpacing.sm),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
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
