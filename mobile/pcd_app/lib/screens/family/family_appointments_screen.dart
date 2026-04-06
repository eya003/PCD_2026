import 'package:flutter/material.dart';

import '../../models/appointment_item.dart';
import '../../models/family_permissions.dart';
import '../../models/patient_summary.dart';
import '../../services/appointments_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';

/// Lists appointments for a given patient (family view).
/// Admins can add, edit, and mark appointments as completed.
/// Viewers have read-only access.
class FamilyAppointmentsScreen extends StatefulWidget {
  const FamilyAppointmentsScreen({
    super.key,
    required this.patient,
    required this.isAdmin,
  });

  final PatientSummary patient;
  final bool isAdmin;

  @override
  State<FamilyAppointmentsScreen> createState() =>
      _FamilyAppointmentsScreenState();
}

class _FamilyAppointmentsScreenState extends State<FamilyAppointmentsScreen> {
  late final AppointmentsService _service;
  FamilyPermissions get _permissions => FamilyPermissions(isAdmin: widget.isAdmin);

  bool _isLoading = true;
  String? _error;
  List<AppointmentItem> _appointments = const [];

  @override
  void initState() {
    super.initState();
    _service = AppointmentsService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _service.fetchPatientAppointments(
        patientId: widget.patient.id,
      );
      if (!mounted) return;
      setState(() {
        _appointments = items;
        _isLoading = false;
      });
    } on AppointmentsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Impossible de charger les rendez-vous.';
      });
    }
  }

  // ── Admin actions ──────────────────────────────────────────────────────────

  Future<void> _openAddForm() async {
    final result = await _showAppointmentForm(context);
    if (result != null && mounted) {
      setState(() {
        _appointments = [..._appointments, result]
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      });
    }
  }

  Future<void> _openEditForm(AppointmentItem appt) async {
    final result = await _showAppointmentForm(context, existing: appt);
    if (result != null && mounted) {
      setState(() {
        final idx = _appointments.indexWhere((a) => a.id == result.id);
        if (idx >= 0) {
          final list = List<AppointmentItem>.from(_appointments);
          list[idx] = result;
          _appointments = list..sort((a, b) => a.dateTime.compareTo(b.dateTime));
        }
      });
    }
  }

  Future<void> _markComplete(AppointmentItem appt) async {
    try {
      final updated = await _service.markAppointmentCompleted(
        appointment: appt,
      );
      if (!mounted) return;
      setState(() {
        final idx = _appointments.indexWhere((a) => a.id == updated.id);
        if (idx >= 0) {
          final list = List<AppointmentItem>.from(_appointments);
          list[idx] = updated;
          _appointments = list;
        }
      });
      _showSnackBar('Rendez-vous marque termine.');
    } on AppointmentsException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Impossible de marquer le rendez-vous comme termine.');
    }
  }

  void _showItemOptions(AppointmentItem appt) {
    if (!_permissions.canManageAppointments) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.of(context).pop();
                _openEditForm(appt);
              },
            ),
            if (appt.canMarkCompleted)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Marquer comme terminé'),
                onTap: () {
                  Navigator.of(context).pop();
                  _markComplete(appt);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Form dialog ────────────────────────────────────────────────────────────

  Future<AppointmentItem?> _showAppointmentForm(
    BuildContext context, {
    AppointmentItem? existing,
  }) async {
    DateTime selectedDate =
        existing?.dateTime ?? DateTime.now().add(const Duration(hours: 1));
    TimeOfDay selectedTime = TimeOfDay(
      hour: selectedDate.hour,
      minute: selectedDate.minute,
    );
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    bool isSaving = false;
    String? formError;

    final result = await showDialog<AppointmentItem>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isEdit = existing != null;

          Future<void> pickDate() async {
            final d = await showDatePicker(
              context: ctx,
              initialDate: selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (d != null) {
              setDialogState(() {
                selectedDate = DateTime(
                  d.year,
                  d.month,
                  d.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
              });
            }
          }

          Future<void> pickTime() async {
            final t = await showTimePicker(
              context: ctx,
              initialTime: selectedTime,
            );
            if (t != null) {
              setDialogState(() {
                selectedTime = t;
                selectedDate = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  t.hour,
                  t.minute,
                );
              });
            }
          }

          String fmtDate(DateTime d) {
            final day = d.day.toString().padLeft(2, '0');
            final month = d.month.toString().padLeft(2, '0');
            return '$day/$month/${d.year}';
          }

          String fmtTime(TimeOfDay t) {
            final h = t.hour.toString().padLeft(2, '0');
            final m = t.minute.toString().padLeft(2, '0');
            return '$h:$m';
          }

          Future<void> save() async {
            setDialogState(() {
              isSaving = true;
              formError = null;
            });
            try {
              AppointmentItem saved;
              if (isEdit) {
                saved = await _service.updateAppointment(
                  appointmentId: existing.id,
                  patientId: widget.patient.id,
                  appointmentDateTime: selectedDate,
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  status: existing.status,
                );
              } else {
                saved = await _service.createAppointment(
                  patientId: widget.patient.id,
                  appointmentDateTime: selectedDate,
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                );
              }
              if (ctx.mounted) Navigator.of(ctx).pop(saved);
            } on AppointmentsException catch (e) {
              setDialogState(() {
                isSaving = false;
                formError = e.message;
              });
            } catch (_) {
              setDialogState(() {
                isSaving = false;
                formError = 'Erreur lors de l enregistrement.';
              });
            }
          }

          return AlertDialog(
            title: Text(isEdit ? 'Modifier le rendez-vous' : 'Nouveau rendez-vous'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date picker row
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 20),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text('Date : ${fmtDate(selectedDate)}'),
                      ),
                      TextButton(
                        onPressed: isSaving ? null : pickDate,
                        child: const Text('Changer'),
                      ),
                    ],
                  ),
                  // Time picker row
                  Row(
                    children: [
                      const Icon(Icons.access_time_outlined, size: 20),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text('Heure : ${fmtTime(selectedTime)}'),
                      ),
                      TextButton(
                        onPressed: isSaving ? null : pickTime,
                        child: const Text('Changer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Notes field
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    enabled: !isSaving,
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      formError!,
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(ctx).pop(null),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEdit ? 'Enregistrer' : 'Ajouter'),
              ),
            ],
          );
        },
      ),
    );

    notesCtrl.dispose();
    return result;
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rendez-vous — ${widget.patient.firstName}'),
      ),
      floatingActionButton: _permissions.canManageAppointments
          ? FloatingActionButton(
              onPressed: _openAddForm,
              tooltip: 'Ajouter un rendez-vous',
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorBody(message: _error!, onRetry: _load)
                : _appointments.isEmpty
                    ? const EmptyState(
                        icon: Icons.event_outlined,
                        title: 'Aucun rendez-vous',
                        message: 'Aucun rendez-vous enregistre pour ce patient.',
                      )
                    : _AppointmentList(
                        appointments: _appointments,
                        isAdmin: _permissions.canManageAppointments,
                        onTap: _permissions.canManageAppointments ? _showItemOptions : null,
                      ),
      ),
    );
  }
}

// ── Appointment list ──────────────────────────────────────────────────────────

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({
    required this.appointments,
    required this.isAdmin,
    required this.onTap,
  });

  final List<AppointmentItem> appointments;
  final bool isAdmin;
  final void Function(AppointmentItem)? onTap;

  @override
  Widget build(BuildContext context) {
    final upcoming = appointments
        .where((a) =>
            a.effectiveStatus == AppointmentItem.statusScheduled)
        .toList();
    final past = appointments
        .where((a) =>
            a.effectiveStatus != AppointmentItem.statusScheduled)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (upcoming.isNotEmpty) ...[
          _SectionHeader(
            title: 'À venir',
            count: upcoming.length,
          ),
          ...upcoming.map((a) => _AppointmentCard(
                appointment: a,
                isAdmin: isAdmin,
                onTap: onTap != null ? () => onTap!(a) : null,
              )),
          const SizedBox(height: AppSpacing.md),
        ],
        if (past.isNotEmpty) ...[
          _SectionHeader(
            title: 'Passés',
            count: past.length,
          ),
          ...past.map((a) => _AppointmentCard(
                appointment: a,
                isAdmin: isAdmin,
                onTap: onTap != null ? () => onTap!(a) : null,
              )),
        ],
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Appointment card ──────────────────────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.isAdmin,
    required this.onTap,
  });

  final AppointmentItem appointment;
  final bool isAdmin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final status = appointment.effectiveStatus;
    final Color statusColor;
    switch (status) {
      case AppointmentItem.statusDone:
        statusColor = Colors.green.shade700;
        break;
      case AppointmentItem.statusCancelled:
        statusColor = colorScheme.error;
        break;
      case AppointmentItem.statusMissed:
        statusColor = Colors.orange.shade700;
        break;
      default:
        statusColor = colorScheme.primary;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Date column
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      appointment.dateTime.day.toString().padLeft(2, '0'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      _monthLabel(appointment.dateTime.month),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Details column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.timeLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 4, top: 1),
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          appointment.statusLabelFr,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if ((appointment.notes ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          appointment.notes!.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (isAdmin)
                Icon(
                  Icons.more_vert,
                  color: colorScheme.onSurfaceVariant,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthLabel(int month) {
    const labels = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return month >= 1 && month <= 12 ? labels[month - 1] : '';
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
