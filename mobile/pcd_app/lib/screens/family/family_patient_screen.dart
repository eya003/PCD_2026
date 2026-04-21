import 'package:flutter/material.dart';

import '../../models/appointment_item.dart';
import '../../models/family_permissions.dart';
import '../../models/medication_calendar.dart';
import '../../models/patient_alert.dart';
import '../../models/patient_location.dart';
import '../../models/patient_summary.dart';
import '../../services/alerts_service.dart';
import '../../services/appointments_service.dart';
import '../../services/location_service.dart';
import '../../services/medication_calendar_service.dart';
import '../../services/treatments_service.dart';
import '../../theme/app_spacing.dart';
import 'family_alerts_screen.dart';
import 'family_appointments_screen.dart';
import 'family_location_screen.dart';
import 'family_medication_calendar_screen.dart';
import 'family_members_screen.dart';
import 'family_patient_record_screen.dart';
import 'family_treatments_screen.dart';

/// Family patient dashboard.
/// Gives a global overview of the patient's status and quick access
/// to treatments, appointments, alerts and location.
class FamilyPatientScreen extends StatefulWidget {
  const FamilyPatientScreen({
    super.key,
    required this.patient,
    required this.currentUserId,
    required this.isAdmin,
    required this.familyFirstName,
    required this.familyLastName,
    required this.onFamilyRoleChanged,
  });

  final PatientSummary patient;
  final int currentUserId;
  final bool isAdmin;
  final String familyFirstName;
  final String familyLastName;
  final ValueChanged<String> onFamilyRoleChanged;

  @override
  State<FamilyPatientScreen> createState() => _FamilyPatientScreenState();
}

class _FamilyPatientScreenState extends State<FamilyPatientScreen> {
  late final TreatmentsService _treatmentsService;
  late final AppointmentsService _appointmentsService;
  late final AlertsService _alertsService;
  late final LocationService _locationService;
  late final MedicationCalendarService _medicationCalendarService;

  bool _isLoading = true;
  String? _loadError; // set only on auth failure (401)

  PatientTreatmentData? _treatmentData;
  List<AppointmentItem> _appointments = const [];
  List<PatientAlert> _alerts = const [];
  PatientLocation? _lastLocation;
  List<ScheduledMedicationDose> _upcomingTodayDoses = const [];
  FamilyPermissions get _permissions =>
      FamilyPermissions(isAdmin: widget.isAdmin);

  int get _activeMedCount => _treatmentData?.activeMedications.length ?? 0;

  int get _unreadAlertCount => _alerts.where((a) => !a.isRead).length;

  List<AppointmentItem> get _upcomingAppointments {
    final now = DateTime.now();
    return _appointments
        .where(
          (a) =>
              a.effectiveStatus == AppointmentItem.statusScheduled &&
              a.dateTime.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  AppointmentItem? get _nextAppointment {
    final list = _upcomingAppointments;
    return list.isEmpty ? null : list.first;
  }

  String get _familyDisplayName {
    final parts = <String>[];
    if (widget.familyFirstName.trim().isNotEmpty) {
      parts.add(widget.familyFirstName.trim());
    }
    if (widget.familyLastName.trim().isNotEmpty) {
      parts.add(widget.familyLastName.trim());
    }
    return parts.join(' ').trim();
  }

  @override
  void initState() {
    super.initState();
    _treatmentsService = TreatmentsService();
    _appointmentsService = AppointmentsService();
    _alertsService = AlertsService();
    _locationService = LocationService();
    _medicationCalendarService = MedicationCalendarService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final id = widget.patient.id;
    PatientTreatmentData? treatmentData;
    List<AppointmentItem> appointments = [];
    List<PatientAlert> alerts = [];
    PatientLocation? lastLocation;
    List<ScheduledMedicationDose> upcomingTodayDoses = [];
    String? authError;

    // All services are called concurrently.
    // A non-auth error leaves that slice empty but does not block the dashboard.
    await Future.wait([
      _treatmentsService
          .fetchPatientTreatmentData(patientId: id)
          .then((d) {
            treatmentData = d;
          })
          .catchError((Object e) {
            if (e is TreatmentsException && e.statusCode == 401) {
              authError = e.message;
            }
          }),
      _appointmentsService
          .fetchPatientAppointments(patientId: id)
          .then((d) {
            appointments = d;
          })
          .catchError((_) {}),
      _alertsService
          .fetchPatientAlerts(patientId: id)
          .then((d) {
            alerts = d;
          })
          .catchError((_) {}),
      _locationService
          .fetchLastLocation(patientId: id)
          .then((d) {
            lastLocation = d;
          })
          .catchError((_) {}),
      _medicationCalendarService
          .fetchTodayPlanning(patientId: id, planningDate: DateTime.now())
          .then((planning) {
            upcomingTodayDoses = _extractUpcomingTodayDoses(planning);
          })
          .catchError((_) {}),
    ]);

    if (!mounted) return;
    setState(() {
      _treatmentData = treatmentData;
      _appointments = appointments;
      _alerts = alerts;
      _lastLocation = lastLocation;
      _upcomingTodayDoses = upcomingTodayDoses;
      _loadError = authError;
      _isLoading = false;
    });
  }

  List<ScheduledMedicationDose> _extractUpcomingTodayDoses(
    MedicationDayPlanning planning,
  ) {
    final now = DateTime.now();
    final result =
        planning.doses
            .where(
              (dose) =>
                  dose.normalizedStatus ==
                      ScheduledMedicationDose.statusPending &&
                  !dose.effectiveScheduledFor.isBefore(now),
            )
            .toList()
          ..sort(
            (a, b) =>
                a.effectiveScheduledFor.compareTo(b.effectiveScheduledFor),
          );

    if (result.isNotEmpty) {
      return result;
    }

    final fallback =
        planning.doses
            .where(
              (dose) =>
                  dose.normalizedStatus ==
                  ScheduledMedicationDose.statusPending,
            )
            .toList()
          ..sort(
            (a, b) =>
                a.effectiveScheduledFor.compareTo(b.effectiveScheduledFor),
          );
    return fallback;
  }

  void _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _openTreatments() => _push(
    FamilyTreatmentsScreen(
      patient: widget.patient,
      isAdmin: _permissions.isAdmin,
    ),
  );

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
      await _load();
    }
  }

  void _openAppointments() => _push(
    FamilyAppointmentsScreen(
      patient: widget.patient,
      isAdmin: _permissions.isAdmin,
    ),
  );

  void _openAlerts() => _push(
    FamilyAlertsScreen(patient: widget.patient, isAdmin: _permissions.isAdmin),
  );

  void _openLocation() => _push(
    FamilyLocationScreen(
      patient: widget.patient,
      isAdmin: _permissions.isAdmin,
    ),
  );

  Future<void> _openFamilyMembers() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyMembersScreen(
          patient: widget.patient,
          isAdmin: _permissions.canManageFamilyMembers,
          currentUserId: widget.currentUserId,
          onCurrentUserAdminChanged: (isCurrentUserAdmin) {
            widget.onFamilyRoleChanged(isCurrentUserAdmin ? 'admin' : 'viewer');
          },
        ),
      ),
    );
  }

  void _openPatientRecord() => _push(
    FamilyPatientRecordScreen(
      patient: widget.patient,
      isAdmin: _permissions.isAdmin,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard famille'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _PatientHeaderCard(
              patient: widget.patient,
              isAdmin: _permissions.isAdmin,
              familyDisplayName: _familyDisplayName,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              _ErrorSection(message: _loadError!, onRetry: _load)
            else ...[
              _DailyOverviewCard(
                nextAppointment: _nextAppointment,
                unreadAlertCount: _unreadAlertCount,
                activeMedCount: _activeMedCount,
                lastLocationTime: _lastLocation?.formattedDateTime,
              ),
              const SizedBox(height: AppSpacing.md),
              _SummaryRow(
                activeMedCount: _activeMedCount,
                upcomingCount: _upcomingAppointments.length,
                unreadAlertCount: _unreadAlertCount,
                hasLocation: _lastLocation != null,
              ),
              const SizedBox(height: AppSpacing.md),
              _TodayMedicationWidget(
                doses: _upcomingTodayDoses,
                isAdmin: _permissions.isAdmin,
                onOpenCalendar: _openMedicationCalendar,
              ),
              const SizedBox(height: AppSpacing.md),
              _QuickAccessGrid(
                activeMedCount: _activeMedCount,
                upcomingCount: _upcomingAppointments.length,
                unreadAlertCount: _unreadAlertCount,
                lastLocationTime: _lastLocation?.formattedDateTime,
                canManageFamilyMembers: _permissions.canManageFamilyMembers,
                onTreatments: _openTreatments,
                onAppointments: _openAppointments,
                onAlerts: _openAlerts,
                onLocation: _openLocation,
                onFamilyMembers: _openFamilyMembers,
                onPatientRecord: _openPatientRecord,
                onMedicationCalendar: _openMedicationCalendar,
              ),
              const SizedBox(height: AppSpacing.md),
              _TodaySection(
                isAdmin: _permissions.isAdmin,
                nextAppointment: _nextAppointment,
                unreadAlertCount: _unreadAlertCount,
                activeMedCount: _activeMedCount,
                onOpenAppointments: _openAppointments,
                onOpenAlerts: _openAlerts,
                onOpenMedicationCalendar: _openMedicationCalendar,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _PatientHeaderCard extends StatelessWidget {
  const _PatientHeaderCard({
    required this.patient,
    required this.isAdmin,
    required this.familyDisplayName,
  });

  final PatientSummary patient;
  final bool isAdmin;
  final String familyDisplayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final greeting = familyDisplayName.isEmpty
        ? 'Bienvenue'
        : 'Bienvenue, $familyDisplayName';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    greeting,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _RoleBadge(isAdmin: isAdmin),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Patient selectionne: ${patient.fullName}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                Chip(
                  avatar: const Icon(Icons.badge_outlined, size: 16),
                  label: Text('CIN ${patient.cin}'),
                ),
                Chip(
                  avatar: const Icon(Icons.cake_outlined, size: 16),
                  label: Text('${patient.age} ans'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isAdmin ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final bg = isAdmin
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final label = isAdmin ? 'Administrateur' : 'Spectateur';
    final icon = isAdmin
        ? Icons.admin_panel_settings_outlined
        : Icons.visibility_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyOverviewCard extends StatelessWidget {
  const _DailyOverviewCard({
    required this.nextAppointment,
    required this.unreadAlertCount,
    required this.activeMedCount,
    required this.lastLocationTime,
  });

  final AppointmentItem? nextAppointment;
  final int unreadAlertCount;
  final int activeMedCount;
  final String? lastLocationTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    var tasks = 0;
    if (unreadAlertCount > 0) tasks += 1;
    if (nextAppointment != null) tasks += 1;
    if (activeMedCount > 0) tasks += 1;

    final headline = tasks == 0
        ? 'Resume du jour: situation stable'
        : 'Resume du jour: $tasks action${tasks > 1 ? 's' : ''} a suivre';

    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard_outlined, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Resume du jour',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(headline, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              nextAppointment == null
                  ? 'Aucun rendez-vous a venir planifie.'
                  : 'Prochain RDV: ${nextAppointment!.dateLabel} a ${nextAppointment!.timeLabel}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              lastLocationTime == null
                  ? 'Localisation: Aucune localisation disponible'
                  : 'Position partagee le: $lastLocationTime',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.activeMedCount,
    required this.upcomingCount,
    required this.unreadAlertCount,
    required this.hasLocation,
  });

  final int activeMedCount;
  final int upcomingCount;
  final int unreadAlertCount;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        _StatTile(
          icon: Icons.medication_outlined,
          value: '$activeMedCount',
          label: 'Traitements actifs',
          color: colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.xs),
        _StatTile(
          icon: Icons.event_outlined,
          value: '$upcomingCount',
          label: 'RDV a venir',
          color: colorScheme.secondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        _StatTile(
          icon: Icons.notifications_outlined,
          value: '$unreadAlertCount',
          label: 'Alertes non lues',
          color: unreadAlertCount > 0
              ? colorScheme.error
              : colorScheme.onSurfaceVariant,
          highlighted: unreadAlertCount > 0,
        ),
        const SizedBox(width: AppSpacing.xs),
        _StatTile(
          icon: hasLocation
              ? Icons.share_location_outlined
              : Icons.location_off_outlined,
          value: hasLocation ? 'OK' : '--',
          label: 'Localisation',
          color: hasLocation
              ? Colors.blue.shade700
              : colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.highlighted = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Card(
        color: highlighted
            ? colorScheme.errorContainer.withValues(alpha: 0.35)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayMedicationWidget extends StatelessWidget {
  const _TodayMedicationWidget({
    required this.doses,
    required this.isAdmin,
    required this.onOpenCalendar,
  });

  final List<ScheduledMedicationDose> doses;
  final bool isAdmin;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visible = doses.take(4).toList();

    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.28),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today_outlined, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Medicaments - Aujourd hui',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: onOpenCalendar,
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (visible.isEmpty)
              Text(
                'Aucune prise restante pour le moment.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                children: visible
                    .map(
                      (dose) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _TodayDosePreviewRow(dose: dose),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isAdmin
                  ? 'Admin: actions disponibles dans le calendrier.'
                  : 'Spectateur: consultation en lecture seule.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayDosePreviewRow extends StatelessWidget {
  const _TodayDosePreviewRow({required this.dose});

  final ScheduledMedicationDose dose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final medName = dose.medication?.name ?? 'Medicament #${dose.medicationId}';
    final hour = dose.effectiveScheduledFor.hour.toString().padLeft(2, '0');
    final minute = dose.effectiveScheduledFor.minute.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '$hour:$minute',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              medName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            dose.statusLabelFr,
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

class _TodaySection extends StatelessWidget {
  const _TodaySection({
    required this.isAdmin,
    required this.nextAppointment,
    required this.unreadAlertCount,
    required this.activeMedCount,
    required this.onOpenAppointments,
    required this.onOpenAlerts,
    required this.onOpenMedicationCalendar,
  });

  final bool isAdmin;
  final AppointmentItem? nextAppointment;
  final int unreadAlertCount;
  final int activeMedCount;
  final VoidCallback onOpenAppointments;
  final VoidCallback onOpenAlerts;
  final VoidCallback onOpenMedicationCalendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasItems =
        nextAppointment != null || unreadAlertCount > 0 || activeMedCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 2),
          child: Text(
            'A faire aujourd hui',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (!isAdmin)
          Card(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Mode spectateur: consultation en lecture seule.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!hasItems)
          _AllGoodCard()
        else
          Column(
            children: [
              if (unreadAlertCount > 0)
                _TodayItem(
                  icon: Icons.notifications_active_outlined,
                  iconColor: colorScheme.error,
                  title:
                      '$unreadAlertCount alerte${unreadAlertCount > 1 ? 's' : ''} '
                      'non lue${unreadAlertCount > 1 ? 's' : ''}',
                  subtitle: 'Appuyez pour consulter',
                  onTap: onOpenAlerts,
                  trailing: _ActionChip(label: 'Ouvrir', onTap: onOpenAlerts),
                ),
              if (nextAppointment != null) ...[
                const SizedBox(height: AppSpacing.xs),
                _TodayItem(
                  icon: Icons.event_outlined,
                  iconColor: colorScheme.primary,
                  title: 'Prochain RDV',
                  subtitle:
                      'Le ${nextAppointment!.dateLabel} a ${nextAppointment!.timeLabel}',
                  onTap: onOpenAppointments,
                  trailing: _ActionChip(
                    label: 'Ouvrir',
                    onTap: onOpenAppointments,
                  ),
                ),
              ],
              if (activeMedCount > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                _TodayItem(
                  icon: Icons.medication_outlined,
                  iconColor: Colors.green.shade700,
                  title:
                      '$activeMedCount traitement${activeMedCount > 1 ? 's' : ''} actif${activeMedCount > 1 ? 's' : ''}',
                  subtitle: 'Suivi des prises en cours',
                  onTap: onOpenMedicationCalendar,
                  trailing: _ActionChip(
                    label: 'Ouvrir',
                    onTap: onOpenMedicationCalendar,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _AllGoodCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.green.shade700,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Aucune action particuliere aujourd hui.',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayItem extends StatelessWidget {
  const _TodayItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid({
    required this.activeMedCount,
    required this.upcomingCount,
    required this.unreadAlertCount,
    required this.lastLocationTime,
    required this.canManageFamilyMembers,
    required this.onTreatments,
    required this.onAppointments,
    required this.onAlerts,
    required this.onLocation,
    required this.onFamilyMembers,
    required this.onPatientRecord,
    required this.onMedicationCalendar,
  });

  final int activeMedCount;
  final int upcomingCount;
  final int unreadAlertCount;
  final String? lastLocationTime;
  final bool canManageFamilyMembers;
  final VoidCallback onTreatments;
  final VoidCallback onAppointments;
  final VoidCallback onAlerts;
  final VoidCallback onLocation;
  final VoidCallback onFamilyMembers;
  final VoidCallback onPatientRecord;
  final VoidCallback onMedicationCalendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 2),
          child: Text(
            'Acces rapide',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Row(
          children: [
            _AccessCard(
              icon: Icons.medication_outlined,
              label: 'Traitements',
              subtitle: activeMedCount > 0
                  ? '$activeMedCount actif${activeMedCount > 1 ? 's' : ''}'
                  : 'Aucun en cours',
              iconColor: colorScheme.primary,
              iconBg: colorScheme.primaryContainer,
              onTap: onTreatments,
            ),
            const SizedBox(width: AppSpacing.sm),
            _AccessCard(
              icon: Icons.calendar_month_outlined,
              label: 'Rendez-vous',
              subtitle: upcomingCount > 0
                  ? '$upcomingCount a venir'
                  : 'Aucun planifie',
              iconColor: colorScheme.secondary,
              iconBg: colorScheme.secondaryContainer,
              onTap: onAppointments,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _AccessCard(
              icon: Icons.notifications_outlined,
              label: 'Alertes',
              subtitle: unreadAlertCount > 0
                  ? '$unreadAlertCount non lue${unreadAlertCount > 1 ? 's' : ''}'
                  : 'Tout lu',
              iconColor: unreadAlertCount > 0
                  ? colorScheme.error
                  : colorScheme.tertiary,
              iconBg: unreadAlertCount > 0
                  ? colorScheme.errorContainer
                  : colorScheme.tertiaryContainer,
              onTap: onAlerts,
              badge: unreadAlertCount > 0 ? unreadAlertCount : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            _AccessCard(
              icon: Icons.share_location_outlined,
              label: 'Localisation',
              subtitle: lastLocationTime != null
                  ? 'Mise a jour: $lastLocationTime'
                  : 'Aucune localisation disponible',
              iconColor: Colors.blue.shade700,
              iconBg: Colors.blue.shade50,
              onTap: onLocation,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _AccessWideCard(
          icon: Icons.family_restroom_outlined,
          label: 'Membres famille',
          subtitle: canManageFamilyMembers
              ? 'Voir les membres et transferer le role admin'
              : 'Voir la liste des membres en lecture seule',
          onTap: onFamilyMembers,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AccessWideCard(
          icon: Icons.badge_outlined,
          label: 'Historique / fiche patient',
          subtitle: 'Consulter le dossier et les derniers evenements',
          onTap: onPatientRecord,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AccessWideCard(
          icon: Icons.today_outlined,
          label: 'Calendrier medicaments',
          subtitle: 'Voir les doses du jour et agir sur les prises',
          onTap: onMedicationCalendar,
        ),
      ],
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    if (badge != null)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$badge',
                            style: TextStyle(
                              color: colorScheme.onError,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessWideCard extends StatelessWidget {
  const _AccessWideCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
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
}

class _ErrorSection extends StatelessWidget {
  const _ErrorSection({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
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
    );
  }
}
