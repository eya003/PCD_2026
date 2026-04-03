import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/ai_result_item.dart';
import '../../models/alert_item.dart';
import '../../models/appointment_item.dart';
import '../../models/dashboard_kpi.dart';
import '../../models/patient_summary.dart';
import '../../services/appointments_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/patients_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/ai_result_card.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/kpi_grid.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';
import '../../widgets/secondary_button.dart';
import '../create_appointment_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenPatients,
    required this.onOpenAi,
    required this.onAddPatient,
    required this.patientsRevision,
    required this.appointmentsRevision,
    this.firstName = '',
    this.lastName = '',
  });

  final VoidCallback onOpenPatients;
  final VoidCallback onOpenAi;
  final VoidCallback onAddPatient;
  final ValueListenable<int> patientsRevision;
  final ValueNotifier<int> appointmentsRevision;
  final String firstName;
  final String lastName;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardService _service;
  late final AppointmentsService _appointmentsService;
  late final VoidCallback _patientsRevisionListener;
  late final VoidCallback _appointmentsRevisionListener;

  bool _isLoading = true;
  String? _loadError;

  List<DashboardKpi> _kpis = const [];
  List<PatientSummary> _patients = const [];
  List<AppointmentItem> _appointments = const [];
  List<AlertItem> _alerts = const [];
  List<AiResultItem> _aiResults = const [];

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _service = DashboardService();
    _appointmentsService = AppointmentsService();
    _patientsRevisionListener = _onPatientsRevisionChanged;
    _appointmentsRevisionListener = _onAppointmentsRevisionChanged;
    widget.patientsRevision.addListener(_patientsRevisionListener);
    widget.appointmentsRevision.addListener(_appointmentsRevisionListener);
    _load();
  }

  @override
  void dispose() {
    widget.patientsRevision.removeListener(_patientsRevisionListener);
    widget.appointmentsRevision.removeListener(_appointmentsRevisionListener);
    super.dispose();
  }

  void _onPatientsRevisionChanged() {
    _load();
  }

  void _onAppointmentsRevisionChanged() {
    _reloadAppointmentsOnly();
  }

  Future<void> _reloadAppointmentsOnly() async {
    try {
      final patientsById = <int, PatientSummary>{
        for (final p in _patients) p.id: p,
      };
      final appointments = await _appointmentsService.fetchDoctorAppointments(
        patientsById: patientsById,
      );
      if (!mounted) return;
      setState(() {
        _appointments = appointments;
      });
    } on AppointmentsException catch (_) {
      // Keep existing appointments on error.
    } catch (_) {
      // Keep existing appointments on error.
    }
  }

  void _notifyAppointmentsChanged() {
    widget.appointmentsRevision.value = widget.appointmentsRevision.value + 1;
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final dashboardData = await _service.fetchDashboardData();
      final alerts = await _service.fetchRecentAlerts();
      final ai = await _service.fetchLatestAiResults();

      if (!mounted) return;
      setState(() {
        _kpis = dashboardData.kpis;
        _patients = dashboardData.patients;
        _appointments = dashboardData.appointments;
        _alerts = alerts;
        _aiResults = ai;
        _isLoading = false;
        _loadError = null;
      });
    } on PatientsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.message;
      });
    } on AppointmentsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Impossible de charger les donnees du dashboard.';
      });
    }
  }

  Future<void> _openCreateAppointmentFromCalendar({DateTime? initialDate}) async {
    if (_patients.isEmpty) {
      _showSnackBar(
        'Ajoutez d abord un patient avant de creer un rendez-vous.',
      );
      return;
    }

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateAppointmentScreen(
          selectablePatients: _patients,
          initialDate: initialDate,
        ),
      ),
    );

    if (!mounted) return;
    if (created == true) {
      _notifyAppointmentsChanged();
      _showSnackBar('Rendez-vous ajoute avec succes.');
    }
  }

  Future<void> _openEditAppointmentFromCalendar(AppointmentItem item) async {
    final patient = _findPatientById(item.patientId);
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateAppointmentScreen(
          initialPatient: patient,
          selectablePatients: _patients,
          initialAppointment: item,
        ),
      ),
    );

    if (!mounted) return;
    if (updated == true) {
      _notifyAppointmentsChanged();
      _showSnackBar('Rendez-vous modifie avec succes.');
    }
  }

  Future<void> _deleteAppointment(AppointmentItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer rendez-vous'),
        content: Text(
          'Supprimer le rendez-vous de ${item.patientName} '
          'le ${item.dateLabel} a ${item.timeLabel} ?',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marquer comme termine'),
        content: Text(
          'Confirmer que le rendez-vous de ${item.patientName} '
          '(${item.dateLabel} ${item.timeLabel}) est termine ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _appointmentsService.markAppointmentCompleted(appointment: item);
      if (!mounted) return;
      _notifyAppointmentsChanged();
      _showSnackBar('Rendez-vous marque comme termine.');
    } on AppointmentsException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Impossible de marquer ce rendez-vous comme termine.');
    }
  }

  Future<void> _showAppointmentDetails(AppointmentItem item) async {
    final statusColor = _statusColorForStatus(item.effectiveStatus, context);
    final action = await showDialog<_AppointmentDialogAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail rendez-vous'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${item.patientName}'),
            const SizedBox(height: 8),
            Text('Date: ${item.dateLabel}'),
            const SizedBox(height: 8),
            Text('Heure: ${item.timeLabel}'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Statut: '),
                Text(
                  item.statusLabelFr,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if ((item.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes: ${item.notes!.trim()}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_AppointmentDialogAction.edit);
            },
            child: const Text('Modifier'),
          ),
          if (item.canMarkCompleted)
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).pop(_AppointmentDialogAction.markCompleted);
              },
              child: const Text('Marquer termine'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(_AppointmentDialogAction.delete);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == _AppointmentDialogAction.edit) {
      await _openEditAppointmentFromCalendar(item);
    } else if (action == _AppointmentDialogAction.markCompleted) {
      await _markAppointmentCompleted(item);
    } else if (action == _AppointmentDialogAction.delete) {
      await _deleteAppointment(item);
    }
  }

  PatientSummary? _findPatientById(int patientId) {
    for (final patient in _patients) {
      if (patient.id == patientId) {
        return patient;
      }
    }
    return null;
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

  Color _statusColorForStatus(String status, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (AppointmentItem.normalizeStatus(status)) {
      case AppointmentItem.statusDone:
        return Colors.green.shade700;
      case AppointmentItem.statusCancelled:
        return Colors.orange.shade700;
      case AppointmentItem.statusMissed:
        return Colors.red.shade700;
      case AppointmentItem.statusScheduled:
      default:
        return colorScheme.primary;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToPreviousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
    });
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Janvier',
      'Fevrier',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Aout',
      'Septembre',
      'Octobre',
      'Novembre',
      'Decembre',
    ];
    final monthName = months[date.month - 1];
    return '$monthName ${date.year}';
  }

  List<DateTime> _buildCalendarDays(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final offset = firstDayOfMonth.weekday - DateTime.monday;
    final firstVisibleDay = firstDayOfMonth.subtract(Duration(days: offset));
    return List<DateTime>.generate(
      42,
      (index) => DateTime(
        firstVisibleDay.year,
        firstVisibleDay.month,
        firstVisibleDay.day + index,
      ),
    );
  }

  Map<DateTime, List<AppointmentItem>> _groupAppointmentsByDay() {
    final grouped = <DateTime, List<AppointmentItem>>{};
    for (final appointment in _appointments) {
      final key = DateTime(
        appointment.dateTime.year,
        appointment.dateTime.month,
        appointment.dateTime.day,
      );
      grouped.putIfAbsent(key, () => <AppointmentItem>[]).add(appointment);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }
    return grouped;
  }

  List<AppointmentItem> _todayAppointments() {
    final today = DateTime.now();
    return _appointments.where((item) {
      return item.dateTime.year == today.year &&
          item.dateTime.month == today.month &&
          item.dateTime.day == today.day;
    }).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final todayAppointments = _todayAppointments();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 760;
              if (!isCompact) {
                final greetTitle = (widget.firstName.trim().isNotEmpty || widget.lastName.trim().isNotEmpty)
                    ? 'Bonjour Dr. ${widget.firstName} ${widget.lastName}'.trim()
                    : 'Bonjour Docteur';
                return AppHeader(
                  title: greetTitle,
                  subtitle:
                      'Vue rapide patients, rendez-vous, alertes et module IA.',
                  actions: [
                    PrimaryButton(
                      label: 'Voir patient',
                      icon: Icons.groups_outlined,
                      fullWidth: false,
                      onPressed: widget.onOpenPatients,
                    ),
                    SecondaryButton(
                      label: 'Ajouter patient',
                      icon: Icons.person_add_alt_1_outlined,
                      fullWidth: false,
                      onPressed: widget.onAddPatient,
                    ),
                    SecondaryButton(
                      label: 'Module IA',
                      icon: Icons.psychology_alt_outlined,
                      fullWidth: false,
                      onPressed: widget.onOpenAi,
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppHeader(
                    title: (widget.firstName.trim().isNotEmpty || widget.lastName.trim().isNotEmpty)
                        ? 'Bonjour Dr. ${widget.firstName} ${widget.lastName}'.trim()
                        : 'Bonjour Docteur',
                    subtitle:
                        'Vue rapide patients, rendez-vous, alertes et module IA.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    label: 'Voir patient',
                    icon: Icons.groups_outlined,
                    onPressed: widget.onOpenPatients,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SecondaryButton(
                    label: 'Ajouter patient',
                    icon: Icons.person_add_alt_1_outlined,
                    onPressed: widget.onAddPatient,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SecondaryButton(
                    label: 'Module IA',
                    icon: Icons.psychology_alt_outlined,
                    onPressed: widget.onOpenAi,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loadError != null) ...[
            _DashboardErrorBanner(
              message: _loadError!,
              onRetry: _load,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          KpiGrid(items: _kpis),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Rendez-vous aujourd hui',
            action: Text(
              '${todayAppointments.length}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            child: _buildTodayAppointmentsSection(
              context,
              todayAppointments: todayAppointments,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Calendrier mensuel',
            action: TextButton.icon(
              onPressed: _openCreateAppointmentFromCalendar,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            ),
            child: _buildCalendarSection(context),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Alertes recentes',
            child: Column(
              children: _alerts
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AlertCard(alert: item),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Derniers resultats IA',
            child: Column(
              children: _aiResults
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AiResultCard(result: item),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection(BuildContext context) {
    final theme = Theme.of(context);
    final groupedByDay = _groupAppointmentsByDay();
    final visibleDays = _buildCalendarDays(_visibleMonth);
    final today = DateTime.now();
    const weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mois precedent',
              onPressed: _goToPreviousMonth,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                _monthLabel(_visibleMonth),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mois suivant',
              onPressed: _goToNextMonth,
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: _goToCurrentMonth,
              child: const Text('Aujourd hui'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 700.0;
            final calendarWidth = viewportWidth < 700 ? 700.0 : viewportWidth;
            final dayCellWidth = calendarWidth / 7;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: calendarWidth,
                child: Column(
                  children: [
                    Row(
                      children: weekDays
                          .map(
                            (label) => SizedBox(
                              width: dayCellWidth,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Center(
                                  child: Text(
                                    label,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    GridView.builder(
                      itemCount: visibleDays.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.92,
                      ),
                      itemBuilder: (context, index) {
                        final day = visibleDays[index];
                        final dayKey = DateTime(day.year, day.month, day.day);
                        final dayAppointments = groupedByDay[dayKey] ?? const [];

                        return _CalendarDayCell(
                          day: day,
                          isCurrentMonth:
                              day.month == _visibleMonth.month &&
                              day.year == _visibleMonth.year,
                          isToday:
                              day.day == today.day &&
                              day.month == today.month &&
                              day.year == today.year,
                          appointments: dayAppointments,
                          onTapAppointment: _showAppointmentDetails,
                          onTapDay: (d) => _openCreateAppointmentFromCalendar(initialDate: d),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_appointments.isEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          const EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Aucun rendez-vous',
            message: 'Aucun rendez-vous planifie pour le moment.',
          ),
        ],
      ],
    );
  }

  Widget _buildTodayAppointmentsSection(
    BuildContext context, {
    required List<AppointmentItem> todayAppointments,
  }) {
    if (todayAppointments.isEmpty) {
      return const EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Aucun rendez-vous aujourd hui',
        message: 'Aucun rendez-vous planifie pour cette journee.',
      );
    }

    return Column(
      children: todayAppointments
          .map(
            (item) => _TodayAppointmentRow(
              item: item,
              statusLabel: _statusLabel(item.effectiveStatus),
              statusColor: _statusColorForStatus(item.effectiveStatus, context),
              onTap: () => _showAppointmentDetails(item),
            ),
          )
          .toList(),
    );
  }
}

class _DashboardErrorBanner extends StatelessWidget {
  const _DashboardErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final messageText = Text(
      message,
      softWrap: true,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onErrorContainer,
      ),
    );
    final retryButton = TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onRetry,
      child: Text(
        'Reessayer',
        style: TextStyle(color: colorScheme.onErrorContainer),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 460;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: messageText),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: retryButton,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: messageText),
                    const SizedBox(width: 8),
                    retryButton,
                  ],
                ),
        );
      },
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
    required this.appointments,
    required this.onTapAppointment,
    this.onTapDay,
  });

  final DateTime day;
  final bool isCurrentMonth;
  final bool isToday;
  final List<AppointmentItem> appointments;
  final ValueChanged<AppointmentItem> onTapAppointment;
  final ValueChanged<DateTime>? onTapDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bgColor = isCurrentMonth
        ? colorScheme.surface
        : colorScheme.surfaceVariant.withOpacity(0.25);

    final borderColor = isToday
        ? colorScheme.primary.withOpacity(0.8)
        : colorScheme.outlineVariant.withOpacity(0.75);

    final visibleAppointments = appointments.take(2).toList();
    final remainingCount = appointments.length - visibleAppointments.length;

    return GestureDetector(
      onTap: onTapDay != null ? () => onTapDay!(day) : null,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${day.day}',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: isCurrentMonth
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          ...visibleAppointments.map(
            (appointment) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onTapAppointment(appointment),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _statusColor(context, appointment.effectiveStatus),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${appointment.timeLabel} ${appointment.patientName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (remainingCount > 0)
            Text(
              '+$remainingCount',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    ),
    );
  }

  Color _statusColor(BuildContext context, String status) {
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
}

class _TodayAppointmentRow extends StatelessWidget {
  const _TodayAppointmentRow({
    required this.item,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  final AppointmentItem item;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(
          item.timeLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        item.patientName,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        'Statut: $statusLabel',
        style: theme.textTheme.bodySmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

enum _AppointmentDialogAction { edit, markCompleted, delete }
