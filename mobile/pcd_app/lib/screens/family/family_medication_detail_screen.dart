import 'package:flutter/material.dart';

import '../../models/family_permissions.dart';
import '../../models/medication.dart';
import '../../models/medication_calendar.dart';
import '../../models/medication_intake.dart';
import '../../services/medication_calendar_service.dart';
import '../../services/treatments_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/section_card.dart';
import 'family_medication_calendar_screen.dart';

/// Medication detail screen for family users.
/// Shows medication info, schedule follow-up and intake history.
class FamilyMedicationDetailScreen extends StatefulWidget {
  const FamilyMedicationDetailScreen({
    super.key,
    required this.medication,
    required this.patientId,
    required this.intakes,
    required this.isAdmin,
  });

  final Medication medication;
  final int patientId;
  final List<MedicationIntake> intakes;
  final bool isAdmin;

  @override
  State<FamilyMedicationDetailScreen> createState() =>
      _FamilyMedicationDetailScreenState();
}

class _FamilyMedicationDetailScreenState
    extends State<FamilyMedicationDetailScreen> {
  late final TreatmentsService _service;
  late final MedicationCalendarService _calendarService;
  FamilyPermissions get _permissions =>
      FamilyPermissions(isAdmin: widget.isAdmin);

  late List<MedicationIntake> _intakes;
  ScheduledMedicationDose? _nextDose;

  bool _isSubmitting = false;
  bool _isLoadingNextDose = true;
  bool _wasModified = false;

  @override
  void initState() {
    super.initState();
    _service = TreatmentsService();
    _calendarService = MedicationCalendarService();
    _intakes = List.of(widget.intakes)
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    _loadNextScheduledDose();
  }

  Future<void> _loadNextScheduledDose() async {
    setState(() {
      _isLoadingNextDose = true;
    });

    try {
      final now = DateTime.now();
      final doses = await _calendarService.fetchMedicationScheduledDoses(
        medicationId: widget.medication.id,
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
      );

      final sorted = List<ScheduledMedicationDose>.from(doses)
        ..sort(
          (a, b) => a.effectiveScheduledFor.compareTo(b.effectiveScheduledFor),
        );

      ScheduledMedicationDose? nextDose;
      for (final dose in sorted) {
        if (dose.normalizedStatus == ScheduledMedicationDose.statusPending &&
            !dose.effectiveScheduledFor.isBefore(now)) {
          nextDose = dose;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _nextDose = nextDose;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nextDose = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingNextDose = false;
        });
      }
    }
  }

  Future<void> _validateIntake(String status) async {
    setState(() => _isSubmitting = true);
    try {
      final newIntake = await _service.createMedicationIntake(
        medicationId: widget.medication.id,
        status: status,
        takenAt: DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _intakes = [newIntake, ..._intakes];
        _wasModified = true;
      });
      _showSnackBar(
        status == MedicationIntake.statusTaken
            ? 'Prise validee avec succes.'
            : 'Prise manquee enregistree.',
      );
    } on TreatmentsException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Impossible d enregistrer la prise.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openMedicationCalendar() async {
    final refreshNeeded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FamilyMedicationCalendarScreen(
          patientId: widget.patientId,
          patientName: '',
          isAdmin: _permissions.isAdmin,
        ),
      ),
    );

    if (!mounted) return;
    if (refreshNeeded == true) {
      setState(() {
        _wasModified = true;
      });
      await _loadNextScheduledDose();
    }
  }

  Future<void> _showValidateDialog() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider une prise'),
        content: Text('Enregistrer une prise pour ${widget.medication.name} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton.tonal(
            onPressed: () =>
                Navigator.of(context).pop(MedicationIntake.statusMissed),
            child: const Text('Manquee'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(MedicationIntake.statusTaken),
            child: const Text('Prise'),
          ),
        ],
      ),
    );

    if (action != null && mounted) {
      await _validateIntake(action);
      await _loadNextScheduledDose();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final med = widget.medication;

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(med.name),
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(_wasModified),
          ),
          actions: [
            IconButton(
              tooltip: 'Calendrier',
              onPressed: _openMedicationCalendar,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              SectionCard(
                title: 'Informations traitement',
                child: _MedicationInfo(medication: med),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Suivi calendrier',
                action: FilledButton.icon(
                  onPressed: _openMedicationCalendar,
                  icon: const Icon(Icons.today_outlined),
                  label: const Text('Ouvrir'),
                ),
                child: _ScheduleFollowCard(
                  nextDose: _nextDose,
                  isLoading: _isLoadingNextDose,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Instructions',
                child: _InstructionsCardContent(instructions: med.instructions),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_permissions.canValidateMedication && med.isActive) ...[
                _AdminActionCard(
                  isSubmitting: _isSubmitting,
                  onValidate: _showValidateDialog,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              SectionCard(
                title: 'Historique des prises',
                action: _intakes.isEmpty
                    ? null
                    : Text(
                        '${_intakes.length}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                child: _intakes.isEmpty
                    ? const _EmptyIntakes()
                    : Column(
                        children: _intakes
                            .map((intake) => _IntakeRow(intake: intake))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicationInfo extends StatelessWidget {
  const _MedicationInfo({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColor = medication.isActive
        ? Colors.green.shade700
        : colorScheme.onSurfaceVariant;

    Widget row(String label, String? value) {
      if ((value ?? '').trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Text(value!, style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              medication.statusLabelFr,
              style: theme.textTheme.labelMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        row('Nom', medication.name),
        row('Dosage', medication.dosage),
        row('Frequence', medication.frequency),
        row('Forme', medication.form),
        row('Quantite', medication.quantity),
        row('Periode', medication.period),
        row('Debut', _fmt(medication.startDate)),
        row(
          'Fin',
          medication.endDate != null
              ? _fmt(medication.endDate!)
              : 'Non definie',
        ),
      ],
    );
  }

  String _fmt(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }
}

class _ScheduleFollowCard extends StatelessWidget {
  const _ScheduleFollowCard({required this.nextDose, required this.isLoading});

  final ScheduledMedicationDose? nextDose;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: LinearProgressIndicator(),
      );
    }

    if (nextDose == null) {
      return Text(
        'Aucune dose planifiee a venir pour ce traitement.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prochaine prise: ${_fmtDateTime(nextDose!.effectiveScheduledFor)}',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Statut: ${nextDose!.statusLabelFr}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _fmtDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} $hour:$min';
  }
}

class _InstructionsCardContent extends StatelessWidget {
  const _InstructionsCardContent({required this.instructions});

  final String? instructions;

  @override
  Widget build(BuildContext context) {
    final content = (instructions ?? '').trim();
    if (content.isEmpty) {
      return Text(
        'Aucune instruction specifique.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Text(content, style: Theme.of(context).textTheme.bodyMedium);
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.isSubmitting,
    required this.onValidate,
  });

  final bool isSubmitting;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              color: colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Validation rapide des prises (mode administrateur).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: isSubmitting ? null : onValidate,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntakeRow extends StatelessWidget {
  const _IntakeRow({required this.intake});

  final MedicationIntake intake;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTaken = intake.isTaken;
    final statusColor = isTaken
        ? Colors.green.shade700
        : Colors.orange.shade700;
    final statusIcon = isTaken
        ? Icons.check_circle_outline
        : Icons.cancel_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(statusIcon, size: 18, color: statusColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  intake.statusLabelFr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((intake.comment ?? '').trim().isNotEmpty)
                  Text(
                    intake.comment!.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _fmtDateTime(intake.takenAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} $hour:$min';
  }
}

class _EmptyIntakes extends StatelessWidget {
  const _EmptyIntakes();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        'Aucune prise enregistree pour ce medicament.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
