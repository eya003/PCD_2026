import 'package:flutter/material.dart';

import '../../models/appointment_item.dart';
import '../../models/family_permissions.dart';
import '../../models/medication_intake.dart';
import '../../models/patient_alert.dart';
import '../../models/patient_summary.dart';
import '../../services/alerts_service.dart';
import '../../services/appointments_service.dart';
import '../../services/treatments_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';

class FamilyPatientRecordScreen extends StatefulWidget {
  const FamilyPatientRecordScreen({
    super.key,
    required this.patient,
    required this.isAdmin,
  });

  final PatientSummary patient;
  final bool isAdmin;

  @override
  State<FamilyPatientRecordScreen> createState() =>
      _FamilyPatientRecordScreenState();
}

class _FamilyPatientRecordScreenState extends State<FamilyPatientRecordScreen> {
  late final AppointmentsService _appointmentsService;
  late final AlertsService _alertsService;
  late final TreatmentsService _treatmentsService;

  bool _isLoading = true;
  String? _error;
  List<AppointmentItem> _appointments = const [];
  List<PatientAlert> _alerts = const [];
  List<MedicationIntake> _intakes = const [];

  @override
  void initState() {
    super.initState();
    _appointmentsService = AppointmentsService();
    _alertsService = AlertsService();
    _treatmentsService = TreatmentsService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final patientId = widget.patient.id;
    List<AppointmentItem> appointments = [];
    List<PatientAlert> alerts = [];
    List<MedicationIntake> intakes = [];
    String? authError;

    await Future.wait([
      _appointmentsService
          .fetchPatientAppointments(patientId: patientId)
          .then((data) {
            appointments = data;
          })
          .catchError((Object e) {
            if (e is AppointmentsException && e.statusCode == 401) {
              authError = e.message;
            }
          }),
      _alertsService
          .fetchPatientAlerts(patientId: patientId)
          .then((data) {
            alerts = data;
          })
          .catchError((Object e) {
            if (e is AlertsException && e.statusCode == 401) {
              authError = e.message;
            }
          }),
      _treatmentsService
          .fetchPatientTreatmentData(patientId: patientId)
          .then((data) {
            intakes = data.intakes;
          })
          .catchError((Object e) {
            if (e is TreatmentsException && e.statusCode == 401) {
              authError = e.message;
            }
          }),
    ]);

    if (!mounted) return;
    setState(() {
      _appointments = appointments;
      _alerts = alerts;
      _intakes = intakes;
      _error = authError;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final permissions = FamilyPermissions(isAdmin: widget.isAdmin);
    final sortedAppointments = List<AppointmentItem>.from(_appointments)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final recentAppointments = sortedAppointments.take(5).toList();
    final recentAlerts = _alerts.take(5).toList();
    final recentIntakes = _intakes.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique / fiche patient'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _IdentityCard(
              patient: widget.patient,
              isAdmin: permissions.isAdmin,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorBody(message: _error!, onRetry: _load)
            else if (recentAppointments.isEmpty &&
                recentAlerts.isEmpty &&
                recentIntakes.isEmpty)
              const EmptyState(
                icon: Icons.history_outlined,
                title: 'Aucun historique disponible',
                message: 'Aucun element recent pour ce patient.',
              )
            else ...[
              SectionCard(
                title: 'Rendez-vous recents',
                action: Text(
                  '${_appointments.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                child: recentAppointments.isEmpty
                    ? const _InlineEmpty(message: 'Aucun rendez-vous.')
                    : Column(
                        children: recentAppointments
                            .map((item) => _AppointmentRow(item: item))
                            .toList(),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Dernieres prises medicaments',
                action: Text(
                  '${_intakes.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                child: recentIntakes.isEmpty
                    ? const _InlineEmpty(message: 'Aucune prise enregistree.')
                    : Column(
                        children: recentIntakes
                            .map((item) => _IntakeRow(item: item))
                            .toList(),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Alertes recentes',
                action: Text(
                  '${_alerts.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                child: recentAlerts.isEmpty
                    ? const _InlineEmpty(message: 'Aucune alerte.')
                    : Column(
                        children: recentAlerts
                            .map((item) => _AlertRow(item: item))
                            .toList(),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.patient, required this.isAdmin});

  final PatientSummary patient;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              patient.fullName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
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
                Chip(
                  avatar: Icon(
                    isAdmin
                        ? Icons.admin_panel_settings_outlined
                        : Icons.visibility_outlined,
                    size: 16,
                  ),
                  label: Text(isAdmin ? 'Role admin' : 'Role spectateur'),
                  backgroundColor: isAdmin
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.item});

  final AppointmentItem item;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.effectiveStatus, Theme.of(context));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.event_outlined, size: 18, color: statusColor),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text('${item.dateLabel} ${item.timeLabel}'),
          ),
          Text(
            item.statusLabelFr,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status, ThemeData theme) {
    switch (status) {
      case AppointmentItem.statusDone:
        return Colors.green.shade700;
      case AppointmentItem.statusCancelled:
        return theme.colorScheme.error;
      case AppointmentItem.statusMissed:
        return Colors.orange.shade700;
      default:
        return theme.colorScheme.primary;
    }
  }
}

class _IntakeRow extends StatelessWidget {
  const _IntakeRow({required this.item});

  final MedicationIntake item;

  @override
  Widget build(BuildContext context) {
    final isTaken = item.isTaken;
    final color = isTaken ? Colors.green.shade700 : Colors.orange.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            isTaken ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(item.statusLabelFr)),
          Text(
            _formatDateTime(item.takenAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$min';
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.item});

  final PatientAlert item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isRead
                ? Icons.notifications_none_outlined
                : Icons.notifications_active_outlined,
            size: 18,
            color: item.isRead
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  item.formattedDate,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
