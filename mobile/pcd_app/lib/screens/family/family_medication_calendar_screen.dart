import 'package:flutter/material.dart';

import '../../controllers/family_medication_calendar_controller.dart';
import '../../models/medication_calendar.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';

class FamilyMedicationCalendarScreen extends StatefulWidget {
  const FamilyMedicationCalendarScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.isAdmin,
  });

  final int patientId;
  final String patientName;
  final bool isAdmin;

  @override
  State<FamilyMedicationCalendarScreen> createState() =>
      _FamilyMedicationCalendarScreenState();
}

class _FamilyMedicationCalendarScreenState
    extends State<FamilyMedicationCalendarScreen>
    with SingleTickerProviderStateMixin {
  late final FamilyMedicationCalendarController _controller;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _controller = FamilyMedicationCalendarController();
    _tabController = TabController(length: 2, vsync: this);
    _controller.initialize(
      patientId: widget.patientId,
      loadTemplate: widget.isAdmin,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickTodayDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _controller.selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      await _controller.loadToday(day: picked);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _controller.rangeStart,
        end: _controller.rangeEnd,
      ),
    );

    if (picked != null) {
      await _controller.setRange(picked.start, picked.end);
    }
  }

  Future<void> _showDoseDetails(ScheduledMedicationDose dose) async {
    final detail = await _controller.fetchDoseDetail(dose.id);
    if (!mounted || detail == null) return;

    final med = detail.medication;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail dose planifiee'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (med != null) ...[
                Text(
                  med.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${med.dosage ?? '-'} - ${med.frequency ?? '-'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text('Statut: ${detail.statusLabelFr}'),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Date/heure prevue: ${_formatDateTime(detail.scheduledFor)}',
              ),
              if (detail.rescheduledFor != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Replanifiee pour: ${_formatDateTime(detail.rescheduledFor!)}',
                ),
              ],
              if ((detail.skippedReason ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text('Raison skip: ${detail.skippedReason!.trim()}'),
              ],
              if ((detail.notes ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text('Notes: ${detail.notes!.trim()}'),
              ],
              if (detail.intakes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Logs (${detail.intakes.length})',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                ...detail.intakes.map(
                  (intake) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '- ${intake.status} ${intake.takenAt != null ? "(${_formatDateTime(intake.takenAt!)})" : ""}',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDoseAction(
    ScheduledMedicationDose dose,
    _DoseActionMenu action,
  ) async {
    if (_controller.isMutating) return;

    if (action == _DoseActionMenu.details) {
      await _showDoseDetails(dose);
      return;
    }

    if (!widget.isAdmin || !dose.canBeActedOn) {
      _showSnackBar('Lecture seule pour cette dose.');
      return;
    }

    ScheduledDoseActionResult? result;

    switch (action) {
      case _DoseActionMenu.take:
        result = await _controller.takeDose(dose.id);
        break;
      case _DoseActionMenu.miss:
        result = await _controller.missDose(dose.id);
        break;
      case _DoseActionMenu.skip:
        final reason = await _showRequiredReasonDialog(
          title: 'Sauter la dose',
          label: 'Raison',
          hintText: 'Ex: patient refus, naussee...',
        );
        if (reason == null) return;
        result = await _controller.skipDose(
          dose.id,
          payload: ScheduledDoseSkipActionPayload(skippedReason: reason),
        );
        break;
      case _DoseActionMenu.reschedule:
        final newDateTime = await _pickRescheduleDateTime(dose.scheduledFor);
        if (newDateTime == null) return;
        final reason = await _showOptionalReasonDialog(
          title: 'Replanifier la dose',
          label: 'Raison (optionnelle)',
          hintText: 'Ex: patient absent',
        );
        result = await _controller.rescheduleDose(
          dose.id,
          payload: ScheduledDoseRescheduleActionPayload(
            rescheduledFor: newDateTime,
            reason: reason,
          ),
        );
        break;
      case _DoseActionMenu.cancel:
        final reason = await _showOptionalReasonDialog(
          title: 'Annuler la dose',
          label: 'Raison (optionnelle)',
          hintText: 'Ex: instruction medecin',
        );
        result = await _controller.cancelDose(
          dose.id,
          payload: ScheduledDoseCancelActionPayload(reason: reason),
        );
        break;
      case _DoseActionMenu.details:
        break;
    }

    if (!mounted) return;
    if (result != null) {
      _showSnackBar('Dose mise a jour: ${result.dose.statusLabelFr}.');
    } else {
      _showSnackBar(_controller.mutationError ?? 'Action impossible.');
    }
  }

  Future<DateTime?> _pickRescheduleDateTime(DateTime initialDateTime) async {
    final initialDate = initialDateTime.isAfter(DateTime.now())
        ? initialDateTime
        : DateTime.now().add(const Duration(hours: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return null;

    if (!mounted) return null;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null) return null;

    final result = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (result.isBefore(DateTime.now())) {
      _showSnackBar('Nouvelle date/heure invalide (doit etre dans le futur).');
      return null;
    }
    return result;
  }

  Future<String?> _showRequiredReasonDialog({
    required String title,
    required String label,
    required String hintText,
  }) async {
    final controller = TextEditingController();
    String? errorText;

    final value = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: label,
              hintText: hintText,
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  setStateDialog(() {
                    errorText = 'Ce champ est obligatoire.';
                  });
                  return;
                }
                Navigator.of(context).pop(text);
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return value;
  }

  Future<String?> _showOptionalReasonDialog({
    required String title,
    required String label,
    required String hintText,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(labelText: label, hintText: hintText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    controller.dispose();
    return (value ?? '').trim().isEmpty ? null : value!.trim();
  }

  Future<void> _openTemplateEditor() async {
    if (!widget.isAdmin) return;

    if (_controller.template == null && !_controller.isLoadingTemplate) {
      await _controller.loadScheduleTemplate();
    }
    if (!mounted) return;

    final template = _controller.template;
    if (template == null) {
      _showSnackBar(
        _controller.templateError ?? 'Template planning indisponible.',
      );
      return;
    }

    final payload =
        await showModalBottomSheet<MedicationScheduleTemplateUpdate>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _TemplateEditorSheet(template: template),
        );
    if (payload == null) return;

    final updated = await _controller.updateScheduleTemplate(payload);
    if (!mounted) return;
    if (updated != null) {
      _showSnackBar('Template planning mis a jour.');
    } else {
      _showSnackBar(_controller.mutationError ?? 'Mise a jour impossible.');
    }
  }

  Future<void> _refreshCurrentTab() async {
    if (_tabController.index == 0) {
      await _controller.loadToday();
      return;
    }
    await _controller.loadRange();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final titleName = widget.patientName.trim().isEmpty
        ? 'Patient'
        : widget.patientName.trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_controller.hasChanges);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Text('Calendrier medicaments - $titleName'),
            leading: BackButton(
              onPressed: () =>
                  Navigator.of(context).pop(_controller.hasChanges),
            ),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Aujourd hui'),
                Tab(text: 'Calendrier'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Rafraichir',
                onPressed: _refreshCurrentTab,
                icon: const Icon(Icons.refresh),
              ),
              if (widget.isAdmin)
                IconButton(
                  tooltip: 'Template planning',
                  onPressed: _openTemplateEditor,
                  icon: const Icon(Icons.settings_outlined),
                ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [_buildTodayTab(), _buildRangeTab()],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayTab() {
    final planning = _controller.todayPlanning;
    final doses =
        List<ScheduledMedicationDose>.from(planning?.doses ?? const [])..sort(
          (a, b) => a.effectiveScheduledFor.compareTo(b.effectiveScheduledFor),
        );
    final timelineBuckets = _buildTodayTimelineBuckets(doses);
    final nextDose = _nextPendingDose(doses);
    final remainingCount = _remainingDoseCount(doses);

    if (_controller.isLoadingToday && planning == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _controller.loadToday(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _TodayHeader(
            selectedDay: _controller.selectedDay,
            onPreviousDay: () => _controller.shiftSelectedDay(-1),
            onNextDay: () => _controller.shiftSelectedDay(1),
            onPickDate: _pickTodayDate,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_controller.todayError != null)
            _InlineErrorCard(
              message: _controller.todayError!,
              onRetry: () => _controller.loadToday(),
            ),
          if (planning != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _TodayInsightsCard(
              nextDose: nextDose,
              remainingCount: remainingCount,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (doses.isEmpty)
            const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Aucune dose planifiee',
              message: 'Aucune dose trouvee pour cette journee.',
            )
          else
            ...timelineBuckets.map(
              (bucket) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _TimelineSectionCard(
                  title: bucket.label,
                  icon: bucket.icon,
                  doses: bucket.doses,
                  isMutating: _controller.isMutating,
                  canAct: widget.isAdmin,
                  onActionSelected: _handleDoseAction,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRangeTab() {
    final planning = _controller.rangePlanning;
    final dayBuckets = planning?.days ?? const <MedicationPlanningDayBucket>[];

    if (_controller.isLoadingRange && planning == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _controller.loadRange(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _RangeHeader(
            startDate: _controller.rangeStart,
            endDate: _controller.rangeEnd,
            onPickRange: _pickRange,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_controller.rangeError != null)
            _InlineErrorCard(
              message: _controller.rangeError!,
              onRetry: () => _controller.loadRange(),
            ),
          if (planning != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _CountsCard(counts: planning.counts),
          ],
          const SizedBox(height: AppSpacing.md),
          if (dayBuckets.isEmpty)
            const EmptyState(
              icon: Icons.date_range_outlined,
              title: 'Aucune dose sur cette plage',
              message: 'Elargissez la periode pour voir plus de donnees.',
            )
          else
            ...dayBuckets.map(
              (bucket) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _DayBucketCard(
                  bucket: bucket,
                  canAct: widget.isAdmin,
                  isMutating: _controller.isMutating,
                  onActionSelected: _handleDoseAction,
                ),
              ),
            ),
        ],
      ),
    );
  }

  ScheduledMedicationDose? _nextPendingDose(
    List<ScheduledMedicationDose> doses,
  ) {
    final now = DateTime.now();
    for (final dose in doses) {
      if (dose.normalizedStatus == ScheduledMedicationDose.statusPending &&
          !dose.effectiveScheduledFor.isBefore(now)) {
        return dose;
      }
    }
    return null;
  }

  int _remainingDoseCount(List<ScheduledMedicationDose> doses) {
    return doses
        .where(
          (dose) =>
              dose.normalizedStatus == ScheduledMedicationDose.statusPending,
        )
        .length;
  }

  List<_TimelineSectionData> _buildTodayTimelineBuckets(
    List<ScheduledMedicationDose> doses,
  ) {
    final buckets = <_TimelineSectionData>[
      _TimelineSectionData(label: 'Matin', icon: Icons.wb_sunny_outlined),
      _TimelineSectionData(label: 'Midi', icon: Icons.wb_cloudy_outlined),
      _TimelineSectionData(label: 'Soir', icon: Icons.nights_stay_outlined),
    ];

    for (final dose in doses) {
      final hour = dose.effectiveScheduledFor.hour;
      if (hour < 11) {
        buckets[0].doses.add(dose);
      } else if (hour < 16) {
        buckets[1].doses.add(dose);
      } else {
        buckets[2].doses.add(dose);
      }
    }
    return buckets.where((bucket) => bucket.doses.isNotEmpty).toList();
  }
}

enum _DoseActionMenu { details, take, miss, skip, reschedule, cancel }

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.selectedDay,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onPickDate,
  });

  final DateTime selectedDay;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final Future<void> Function() onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final isToday =
        selectedDay.year == today.year &&
        selectedDay.month == today.month &&
        selectedDay.day == today.day;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            IconButton(
              onPressed: onPreviousDay,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Jour precedent',
            ),
            Expanded(
              child: Center(
                child: InkWell(
                  onTap: onPickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        Text(
                          _formatDate(selectedDay),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isToday ? 'Aujourd hui' : 'Choisir une date',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onNextDay,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Jour suivant',
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeHeader extends StatelessWidget {
  const _RangeHeader({
    required this.startDate,
    required this.endDate,
    required this.onPickRange,
  });

  final DateTime startDate;
  final DateTime endDate;
  final Future<void> Function() onPickRange;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Periode: ${_formatDate(startDate)} - ${_formatDate(endDate)}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onPickRange,
              icon: const Icon(Icons.date_range_outlined),
              label: const Text('Changer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayInsightsCard extends StatelessWidget {
  const _TodayInsightsCard({
    required this.nextDose,
    required this.remainingCount,
  });

  final ScheduledMedicationDose? nextDose;
  final int remainingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final nextDoseText = nextDose == null
        ? 'Aucune prise restante'
        : '${_formatHourMinute(nextDose!.effectiveScheduledFor)} - ${nextDose!.medication?.name ?? "Medicament"}';

    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.28),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Essentiel du jour',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _MiniInsightChip(
                    icon: Icons.schedule_outlined,
                    label: 'Prochaine prise',
                    value: nextDoseText,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _MiniInsightChip(
                    icon: Icons.checklist_outlined,
                    label: 'Restantes',
                    value:
                        '$remainingCount dose${remainingCount > 1 ? "s" : ""}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInsightChip extends StatelessWidget {
  const _MiniInsightChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineSectionData {
  _TimelineSectionData({required this.label, required this.icon})
    : doses = <ScheduledMedicationDose>[];

  final String label;
  final IconData icon;
  final List<ScheduledMedicationDose> doses;
}

class _TimelineSectionCard extends StatelessWidget {
  const _TimelineSectionCard({
    required this.title,
    required this.icon,
    required this.doses,
    required this.canAct,
    required this.isMutating,
    required this.onActionSelected,
  });

  final String title;
  final IconData icon;
  final List<ScheduledMedicationDose> doses;
  final bool canAct;
  final bool isMutating;
  final Future<void> Function(
    ScheduledMedicationDose dose,
    _DoseActionMenu action,
  )
  onActionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${doses.length} dose${doses.length > 1 ? "s" : ""}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...doses.map(
              (dose) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _DoseCard(
                  dose: dose,
                  canAct: canAct && dose.canBeActedOn,
                  isMutating: isMutating,
                  onActionSelected: (action) => onActionSelected(dose, action),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountsCard extends StatelessWidget {
  const _CountsCard({required this.counts});

  final DoseStatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final items = <_CountTileData>[
      _CountTileData('Total', counts.total, Colors.blueGrey),
      _CountTileData('En attente', counts.pending, Colors.blue),
      _CountTileData('Pris', counts.taken, Colors.green),
      _CountTileData('Manquees', counts.missed, Colors.orange),
      _CountTileData('Sautees', counts.skipped, Colors.purple),
      _CountTileData('Annulees', counts.cancelled, Colors.red),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: items
              .map(
                (item) => _CountChip(
                  label: item.label,
                  value: item.value,
                  color: item.color,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _CountTileData {
  const _CountTileData(this.label, this.value, this.color);
  final String label;
  final int value;
  final MaterialColor color;
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color.shade800, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.dose,
    required this.canAct,
    required this.isMutating,
    required this.onActionSelected,
  });

  final ScheduledMedicationDose dose;
  final bool canAct;
  final bool isMutating;
  final ValueChanged<_DoseActionMenu> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final med = dose.medication;
    final statusColor = _statusColor(dose.normalizedStatus);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 58,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _formatHourMinute(dose.effectiveScheduledFor),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med?.name ?? 'Medicament #${dose.medicationId}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if ((med?.dosage ?? '').trim().isNotEmpty)
                        Text(
                          med!.dosage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if ((med?.frequency ?? '').trim().isNotEmpty)
                        Text(
                          med!.frequency!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        'Statut: ${dose.statusLabelFr}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusChip(label: dose.statusLabelFr, color: statusColor),
              ],
            ),
            if ((dose.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Notes: ${dose.notes!.trim()}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton.icon(
                  onPressed: isMutating
                      ? null
                      : () => onActionSelected(_DoseActionMenu.details),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Detail'),
                ),
                if (canAct) ...[
                  FilledButton.icon(
                    onPressed: isMutating
                        ? null
                        : () => onActionSelected(_DoseActionMenu.take),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Pris'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isMutating
                        ? null
                        : () => onActionSelected(_DoseActionMenu.miss),
                    icon: const Icon(Icons.report_outlined, size: 16),
                    label: const Text('Manquee'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isMutating
                        ? null
                        : () => onActionSelected(_DoseActionMenu.skip),
                    icon: const Icon(Icons.fast_forward_outlined, size: 16),
                    label: const Text('Sauter'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isMutating
                        ? null
                        : () => onActionSelected(_DoseActionMenu.reschedule),
                    icon: const Icon(Icons.update_outlined, size: 16),
                    label: const Text('Replanifier'),
                  ),
                  TextButton.icon(
                    onPressed: isMutating
                        ? null
                        : () => onActionSelected(_DoseActionMenu.cancel),
                    icon: const Icon(Icons.block_outlined, size: 16),
                    label: const Text('Annuler'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case ScheduledMedicationDose.statusTaken:
        return Colors.green.shade700;
      case ScheduledMedicationDose.statusMissed:
        return Colors.orange.shade700;
      case ScheduledMedicationDose.statusSkipped:
        return Colors.purple.shade700;
      case ScheduledMedicationDose.statusRescheduled:
        return Colors.indigo.shade700;
      case ScheduledMedicationDose.statusCancelled:
        return Colors.red.shade700;
      case ScheduledMedicationDose.statusPending:
      default:
        return Colors.blue.shade700;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DayBucketCard extends StatelessWidget {
  const _DayBucketCard({
    required this.bucket,
    required this.canAct,
    required this.isMutating,
    required this.onActionSelected,
  });

  final MedicationPlanningDayBucket bucket;
  final bool canAct;
  final bool isMutating;
  final Future<void> Function(
    ScheduledMedicationDose dose,
    _DoseActionMenu action,
  )
  onActionSelected;

  @override
  Widget build(BuildContext context) {
    final doses = List<ScheduledMedicationDose>.from(bucket.doses)
      ..sort(
        (a, b) => a.effectiveScheduledFor.compareTo(b.effectiveScheduledFor),
      );

    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          _formatDate(bucket.date),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${bucket.counts.total} dose(s) - ${bucket.counts.pending} en attente',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          0,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        children: [
          if (doses.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Text('Aucune dose pour cette date.'),
            )
          else
            ...doses.map(
              (dose) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _DoseCard(
                  dose: dose,
                  canAct: canAct && dose.canBeActedOn,
                  isMutating: isMutating,
                  onActionSelected: (action) => onActionSelected(dose, action),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineErrorCard extends StatelessWidget {
  const _InlineErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(message)),
            const SizedBox(width: AppSpacing.xs),
            TextButton(onPressed: onRetry, child: const Text('Reessayer')),
          ],
        ),
      ),
    );
  }
}

class _TemplateEditorSheet extends StatefulWidget {
  const _TemplateEditorSheet({required this.template});

  final MedicationScheduleTemplate template;

  @override
  State<_TemplateEditorSheet> createState() => _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends State<_TemplateEditorSheet> {
  late TimeOfDay _morning;
  late TimeOfDay _noon;
  late TimeOfDay _evening;
  late TimeOfDay _dayStart;
  late TimeOfDay _dayEnd;
  late bool _allowFamilyAdjustment;
  late bool _isActive;
  late TextEditingController _reminderController;

  String? _formError;

  @override
  void initState() {
    super.initState();
    _morning = _parseApiTime(widget.template.morningTime);
    _noon = _parseApiTime(widget.template.noonTime);
    _evening = _parseApiTime(widget.template.eveningTime);
    _dayStart = _parseApiTime(widget.template.dayStartTime);
    _dayEnd = _parseApiTime(widget.template.dayEndTime);
    _allowFamilyAdjustment = widget.template.allowFamilyAdjustment;
    _isActive = widget.template.isActive;
    _reminderController = TextEditingController(
      text: widget.template.reminderOffsetMinutes.toString(),
    );
  }

  @override
  void dispose() {
    _reminderController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(
    TimeOfDay value,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(context: context, initialTime: value);
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  void _submit() {
    final reminder = int.tryParse(_reminderController.text.trim());
    if (reminder == null || reminder < 0 || reminder > 1440) {
      setState(() {
        _formError = 'Offset reminder invalide (0 a 1440).';
      });
      return;
    }

    final startMinutes = _dayStart.hour * 60 + _dayStart.minute;
    final endMinutes = _dayEnd.hour * 60 + _dayEnd.minute;
    if (endMinutes <= startMinutes) {
      setState(() {
        _formError = 'day_end_time doit etre strictement apres day_start_time.';
      });
      return;
    }

    Navigator.of(context).pop(
      MedicationScheduleTemplateUpdate(
        morningTime: _toApiTime(_morning),
        noonTime: _toApiTime(_noon),
        eveningTime: _toApiTime(_evening),
        dayStartTime: _toApiTime(_dayStart),
        dayEndTime: _toApiTime(_dayEnd),
        reminderOffsetMinutes: reminder,
        allowFamilyAdjustment: _allowFamilyAdjustment,
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Template planning patient',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              _TimeRow(
                label: 'Matin',
                value: _formatTimeOfDay(_morning),
                onTap: () => _pickTime(_morning, (v) => _morning = v),
              ),
              _TimeRow(
                label: 'Midi',
                value: _formatTimeOfDay(_noon),
                onTap: () => _pickTime(_noon, (v) => _noon = v),
              ),
              _TimeRow(
                label: 'Soir',
                value: _formatTimeOfDay(_evening),
                onTap: () => _pickTime(_evening, (v) => _evening = v),
              ),
              _TimeRow(
                label: 'Debut journee',
                value: _formatTimeOfDay(_dayStart),
                onTap: () => _pickTime(_dayStart, (v) => _dayStart = v),
              ),
              _TimeRow(
                label: 'Fin journee',
                value: _formatTimeOfDay(_dayEnd),
                onTap: () => _pickTime(_dayEnd, (v) => _dayEnd = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _reminderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Offset rappel (minutes)',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Autoriser ajustement famille'),
                value: _allowFamilyAdjustment,
                onChanged: (v) => setState(() => _allowFamilyAdjustment = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Template actif'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              if ((_formError ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    _formError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.schedule_outlined),
      onTap: onTap,
    );
  }
}

String _formatDate(DateTime value) {
  final d = value.day.toString().padLeft(2, '0');
  final m = value.month.toString().padLeft(2, '0');
  return '$d/$m/${value.year}';
}

String _formatHourMinute(DateTime value) {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _formatDateTime(DateTime value) {
  final d = value.day.toString().padLeft(2, '0');
  final m = value.month.toString().padLeft(2, '0');
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '$d/$m/${value.year} $hh:$mm';
}

TimeOfDay _parseApiTime(String raw) {
  final parts = raw.split(':');
  if (parts.length < 2) {
    return const TimeOfDay(hour: 8, minute: 0);
  }
  final hour = int.tryParse(parts[0]) ?? 8;
  final minute = int.tryParse(parts[1]) ?? 0;
  return TimeOfDay(hour: hour, minute: minute);
}

String _toApiTime(TimeOfDay value) {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '$hh:$mm:00';
}

String _formatTimeOfDay(TimeOfDay value) {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
