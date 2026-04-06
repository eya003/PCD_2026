import 'package:flutter/material.dart';

import '../../models/family_permissions.dart';
import '../../models/patient_alert.dart';
import '../../models/patient_summary.dart';
import '../../services/alerts_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';

/// Displays the list of alerts for a patient (family view).
/// Unread alerts are highlighted.
/// Only admins can mark alerts as read.
class FamilyAlertsScreen extends StatefulWidget {
  const FamilyAlertsScreen({
    super.key,
    required this.patient,
    required this.isAdmin,
  });

  final PatientSummary patient;
  final bool isAdmin;

  @override
  State<FamilyAlertsScreen> createState() => _FamilyAlertsScreenState();
}

class _FamilyAlertsScreenState extends State<FamilyAlertsScreen> {
  late final AlertsService _service;
  FamilyPermissions get _permissions => FamilyPermissions(isAdmin: widget.isAdmin);

  bool _isLoading = true;
  String? _error;
  List<PatientAlert> _alerts = const [];

  @override
  void initState() {
    super.initState();
    _service = AlertsService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _service.fetchPatientAlerts(
        patientId: widget.patient.id,
      );
      if (!mounted) return;
      setState(() {
        _alerts = items;
        _isLoading = false;
      });
    } on AlertsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Impossible de charger les alertes.';
      });
    }
  }

  Future<void> _markRead(PatientAlert alert) async {
    if (!_permissions.canMarkAlertsRead) return;
    if (alert.isRead) return;

    final idx = _alerts.indexWhere((a) => a.id == alert.id);
    if (idx < 0) return;

    setState(() {
      final updated = List<PatientAlert>.from(_alerts);
      updated[idx] = alert.copyWith(isRead: true);
      _alerts = updated;
    });

    try {
      await _service.markAlertRead(alertId: alert.id);
    } on AlertsException catch (e) {
      if (!mounted) return;
      setState(() {
        final revert = List<PatientAlert>.from(_alerts);
        revert[idx] = alert;
        _alerts = revert;
      });
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final revert = List<PatientAlert>.from(_alerts);
        revert[idx] = alert;
        _alerts = revert;
      });
      _showSnackBar('Impossible de marquer l alerte comme lue.');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  int get _unreadCount => _alerts.where((a) => !a.isRead).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Alertes - ${widget.patient.firstName}'),
        actions: [
          if (!_permissions.canMarkAlertsRead)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.xs),
              child: Chip(
                label: Text(
                  'Lecture seule',
                  style: TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (!_isLoading && _unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Chip(
                label: Text(
                  '$_unreadCount non lue${_unreadCount > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorBody(message: _error!, onRetry: _load)
                : _alerts.isEmpty
                    ? const EmptyState(
                        icon: Icons.notifications_none_outlined,
                        title: 'Aucune alerte',
                        message: 'Aucune alerte enregistree pour ce patient.',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          if (!_permissions.canMarkAlertsRead)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.visibility_outlined,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        'Mode spectateur: consultation des alertes uniquement.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (!_permissions.canMarkAlertsRead)
                            const SizedBox(height: AppSpacing.xs),
                          ...List.generate(_alerts.length, (index) {
                            final alert = _alerts[index];
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              child: _AlertCard(
                                alert: alert,
                                canMarkRead: _permissions.canMarkAlertsRead,
                                onMarkRead: () => _markRead(alert),
                              ),
                            );
                          }),
                        ],
                      ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.canMarkRead,
    required this.onMarkRead,
  });

  final PatientAlert alert;
  final bool canMarkRead;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUnread = !alert.isRead;

    final Color typeColor;
    final IconData typeIcon;
    switch (alert.type.toLowerCase()) {
      case 'emergency':
        typeColor = colorScheme.error;
        typeIcon = Icons.warning_amber_outlined;
        break;
      case 'medication':
      case 'medication_missed':
        typeColor = Colors.orange.shade700;
        typeIcon = Icons.medication_outlined;
        break;
      case 'appointment':
        typeColor = colorScheme.primary;
        typeIcon = Icons.event_outlined;
        break;
      default:
        typeColor = colorScheme.onSurfaceVariant;
        typeIcon = Icons.notifications_outlined;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      color: isUnread ? colorScheme.primaryContainer.withOpacity(0.18) : null,
      child: InkWell(
        onTap: isUnread && canMarkRead ? onMarkRead : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(typeIcon, color: typeColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          alert.typeLabelFr,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: typeColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: typeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isUnread ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.formattedDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUnread && canMarkRead)
                Tooltip(
                  message: 'Marquer comme lue',
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
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
