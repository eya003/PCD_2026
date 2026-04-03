import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/medication.dart';
import '../models/note.dart';
import '../models/patient.dart';
import 'create_appointment_screen.dart';
import 'create_medication_screen.dart';
import 'create_note_screen.dart';

enum _PatientMenuAction { edit, back }

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key, required this.patient});

  final Patient? patient;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  bool _isLoading = true;
  List<Appointment> _appointments = const [];
  List<Medication> _medications = const [];
  List<PatientNote> _notes = const [];

  Patient? get _patient => widget.patient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_patient == null) {
        _showSnackBar('Patient introuvable.');
      }
    });
    _loadMockData();
  }

  Future<void> _loadMockData() async {
    // TODO: Remplacer ces donnees mock par un appel API FastAPI.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    if (_patient == null) {
      setState(() => _isLoading = false);
      return;
    }

    final now = DateTime.now();
    setState(() {
      _appointments = <Appointment>[
        Appointment(
          id: 1,
          title: 'Consultation de suivi',
          dateTime: DateTime(now.year, now.month, now.day + 3, 9, 30),
          status: AppointmentStatus.scheduled,
          location: 'Cabinet',
        ),
        Appointment(
          id: 2,
          title: 'Controle tension',
          dateTime: DateTime(now.year, now.month, now.day - 14, 11, 0),
          status: AppointmentStatus.done,
          location: 'Teleconsultation',
        ),
        Appointment(
          id: 3,
          title: 'Bilan mensuel',
          dateTime: DateTime(now.year, now.month, now.day - 25, 10, 15),
          status: AppointmentStatus.cancelled,
          location: 'Cabinet',
        ),
      ]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      _medications = <Medication>[
        Medication(
          id: 1,
          name: 'Paracetamol',
          dosage: '500 mg',
          frequency: '1 comprime x3/jour si douleur',
          startDate: DateTime(now.year, now.month - 1, 5),
        ),
        Medication(
          id: 2,
          name: 'Amoxicilline',
          dosage: '1 g',
          frequency: '2 prises/jour',
          startDate: DateTime(now.year, now.month - 4, 1),
          endDate: DateTime(now.year, now.month - 4, 8),
        ),
      ]..sort((a, b) => b.startDate.compareTo(a.startDate));
      _notes = <PatientNote>[
        PatientNote(
          id: 1,
          createdAt: DateTime(now.year, now.month, now.day - 1, 16, 20),
          content:
              'Patient stable. Poursuite du traitement actuel. Controle dans 2 semaines.',
        ),
        PatientNote(
          id: 2,
          createdAt: DateTime(now.year, now.month, now.day - 18, 10, 5),
          content:
              'Bonne adherence therapeutique. Conseils d\'hydratation et suivi tensionnel a domicile.',
        ),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _isLoading = false;
    });
  }

  Future<void> _openCreateAppointment() async {
    final patient = _patient;
    if (patient == null) {
      _showSnackBar('Patient introuvable.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateAppointmentScreen(patientName: patient.fullName),
      ),
    );
  }

  Future<void> _openCreateMedication() async {
    final patient = _patient;
    if (patient == null) {
      _showSnackBar('Patient introuvable.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateMedicationScreen(patientName: patient.fullName),
      ),
    );
  }

  Future<void> _openCreateNote() async {
    final patient = _patient;
    if (patient == null) {
      _showSnackBar('Patient introuvable.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateNoteScreen(patientName: patient.fullName),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleMenuAction(_PatientMenuAction action) {
    switch (action) {
      case _PatientMenuAction.edit:
        _showSnackBar('Modifier patient: fonctionnalite a venir.');
        break;
      case _PatientMenuAction.back:
        Navigator.of(context).maybePop();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = _patient;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(patient?.appBarTitle ?? 'Fiche patient'),
          actions: [
            IconButton(
              tooltip: 'Ajouter RDV',
              onPressed: _openCreateAppointment,
              icon: const Icon(Icons.event_available_outlined),
            ),
            IconButton(
              tooltip: 'Ajouter medicament',
              onPressed: _openCreateMedication,
              icon: const Icon(Icons.medication_outlined),
            ),
            IconButton(
              tooltip: 'Ajouter note',
              onPressed: _openCreateNote,
              icon: const Icon(Icons.note_add_outlined),
            ),
            PopupMenuButton<_PatientMenuAction>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => const [
                PopupMenuItem<_PatientMenuAction>(
                  value: _PatientMenuAction.edit,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Modifier patient'),
                  ),
                ),
                PopupMenuItem<_PatientMenuAction>(
                  value: _PatientMenuAction.back,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.arrow_back),
                    title: Text('Retour'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Chargement de la fiche patient...'),
                    ],
                  ),
                )
              : _PatientDetailContent(
                  patient: patient,
                  appointments: _appointments,
                  medications: _medications,
                  notes: _notes,
                  onAddAppointment: _openCreateAppointment,
                  onAddMedication: _openCreateMedication,
                  onAddNote: _openCreateNote,
                ),
        ),
      ),
    );
  }
}

class _PatientDetailContent extends StatelessWidget {
  const _PatientDetailContent({
    required this.patient,
    required this.appointments,
    required this.medications,
    required this.notes,
    required this.onAddAppointment,
    required this.onAddMedication,
    required this.onAddNote,
  });

  final Patient? patient;
  final List<Appointment> appointments;
  final List<Medication> medications;
  final List<PatientNote> notes;
  final Future<void> Function() onAddAppointment;
  final Future<void> Function() onAddMedication;
  final Future<void> Function() onAddNote;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (patient == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_off_outlined, size: 40),
                    SizedBox(height: 12),
                    Text(
                      'Patient introuvable',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Impossible d\'ouvrir la fiche patient. Verifiez les donnees.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PatientHeaderCard(patient: patient!),
              const SizedBox(height: 16),
              _QuickActionsCard(
                onAddAppointment: onAddAppointment,
                onAddMedication: onAddMedication,
                onAddNote: onAddNote,
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Resume'),
                      Tab(text: 'Rendez-vous'),
                      Tab(text: 'Medicaments'),
                      Tab(text: 'Notes'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _SummaryTab(patient: patient!),
                    _AppointmentsTab(
                      appointments: appointments,
                      onAddAppointment: onAddAppointment,
                    ),
                    _MedicationsTab(
                      medications: medications,
                      onAddMedication: onAddMedication,
                    ),
                    _NotesTab(notes: notes, onAddNote: onAddNote),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientHeaderCard extends StatelessWidget {
  const _PatientHeaderCard({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final age = _calculateAge(patient.birthDate);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              patient.fullName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoChip(
                  icon: Icons.cake_outlined,
                  label:
                      'Naissance: ${_formatDate(patient.birthDate)} ($age ans)',
                ),
                _InfoChip(
                  icon: Icons.qr_code_2_outlined,
                  label: 'Code: ${patient.patientCode}',
                ),
                if (patient.lastVisitAt != null)
                  _InfoChip(
                    icon: Icons.history_outlined,
                    label:
                        'Derniere visite: ${_formatDate(patient.lastVisitAt!)}',
                  ),
                if (patient.status != null && patient.status!.trim().isNotEmpty)
                  _InfoChip(
                    icon: Icons.flag_outlined,
                    label: 'Statut: ${patient.status}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onAddAppointment,
    required this.onAddMedication,
    required this.onAddNote,
  });

  final Future<void> Function() onAddAppointment;
  final Future<void> Function() onAddMedication;
  final Future<void> Function() onAddNote;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions rapides',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onAddAppointment,
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Ajouter rendez-vous'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onAddMedication,
                  icon: const Icon(Icons.medication_outlined),
                  label: const Text('Ajouter medicament'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onAddNote,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Ajouter note'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informations patient',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Nom', value: patient.lastName),
                _InfoRow(label: 'Prenom', value: patient.firstName),
                _InfoRow(
                  label: 'Date de naissance',
                  value: _formatDate(patient.birthDate),
                ),
                _InfoRow(
                  label: 'Age',
                  value: '${_calculateAge(patient.birthDate)} ans',
                ),
                _InfoRow(label: 'Code patient', value: patient.patientCode),
                if (patient.lastVisitAt != null)
                  _InfoRow(
                    label: 'Derniere visite',
                    value: _formatDate(patient.lastVisitAt!),
                  ),
                if (patient.status != null)
                  _InfoRow(label: 'Statut', value: patient.status!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contacts famille',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text('Aucun contact famille renseigne (placeholder).'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AppointmentsTab extends StatelessWidget {
  const _AppointmentsTab({
    required this.appointments,
    required this.onAddAppointment,
  });

  final List<Appointment> appointments;
  final Future<void> Function() onAddAppointment;

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Rendez-vous',
      addLabel: '+ Ajouter RDV',
      onAdd: onAddAppointment,
      child: appointments.isEmpty
          ? const _EmptyState(
              icon: Icons.event_busy_outlined,
              message: 'Aucun rendez-vous',
            )
          : ListView.separated(
              itemCount: appointments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _AppointmentCard(appointment: appointments[index]),
            ),
    );
  }
}

class _MedicationsTab extends StatelessWidget {
  const _MedicationsTab({
    required this.medications,
    required this.onAddMedication,
  });

  final List<Medication> medications;
  final Future<void> Function() onAddMedication;

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Medicaments',
      addLabel: '+ Ajouter medicament',
      onAdd: onAddMedication,
      child: medications.isEmpty
          ? const _EmptyState(
              icon: Icons.medication_liquid_outlined,
              message: 'Aucun medicament',
            )
          : ListView.separated(
              itemCount: medications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _MedicationCard(medication: medications[index]),
            ),
    );
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab({required this.notes, required this.onAddNote});

  final List<PatientNote> notes;
  final Future<void> Function() onAddNote;

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Notes',
      addLabel: '+ Ajouter note',
      onAdd: onAddNote,
      child: notes.isEmpty
          ? const _EmptyState(
              icon: Icons.notes_outlined,
              message: 'Aucune note',
            )
          : ListView.separated(
              itemCount: notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _NoteCard(note: notes[index]),
            ),
    );
  }
}

class _SectionScaffold extends StatelessWidget {
  const _SectionScaffold({
    required this.title,
    required this.addLabel,
    required this.onAdd,
    required this.child,
  });

  final String title;
  final String addLabel;
  final Future<void> Function() onAdd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final chipBackground = switch (appointment.status) {
      AppointmentStatus.scheduled => colorScheme.primaryContainer,
      AppointmentStatus.done => colorScheme.secondaryContainer,
      AppointmentStatus.cancelled => colorScheme.errorContainer,
    };
    final chipForeground = switch (appointment.status) {
      AppointmentStatus.scheduled => colorScheme.onPrimaryContainer,
      AppointmentStatus.done => colorScheme.onSecondaryContainer,
      AppointmentStatus.cancelled => colorScheme.onErrorContainer,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appointment.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: chipBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _appointmentStatusLabel(appointment.status),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: chipForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _InlineMeta(
                  icon: Icons.schedule_outlined,
                  text: _formatDateTime(appointment.dateTime),
                ),
                if (appointment.location != null &&
                    appointment.location!.trim().isNotEmpty)
                  _InlineMeta(
                    icon: Icons.location_on_outlined,
                    text: appointment.location!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    medication.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: medication.isActive
                        ? colorScheme.secondaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    medication.isActive ? 'Actif' : 'Historique',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: medication.isActive
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'Dosage', value: medication.dosage, dense: true),
            _InfoRow(
              label: 'Frequence',
              value: medication.frequency,
              dense: true,
            ),
            _InfoRow(
              label: 'Debut',
              value: _formatDate(medication.startDate),
              dense: true,
            ),
            _InfoRow(
              label: 'Fin',
              value: medication.endDate == null
                  ? '-'
                  : _formatDate(medication.endDate!),
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final PatientNote note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.note_alt_outlined, size: 18),
                const SizedBox(width: 8),
                Text(
                  _formatDateTime(note.createdAt),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(note.content, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.dense = false,
  });

  final String label;
  final String value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final spacing = dense ? 6.0 : 10.0;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(text)],
    );
  }
}

int _calculateAge(DateTime birthDate) {
  final now = DateTime.now();
  var age = now.year - birthDate.year;
  final hasBirthdayPassed =
      (now.month > birthDate.month) ||
      (now.month == birthDate.month && now.day >= birthDate.day);
  if (!hasBirthdayPassed) {
    age -= 1;
  }
  return age;
}

String _formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

String _formatDateTime(DateTime dateTime) {
  final h = dateTime.hour.toString().padLeft(2, '0');
  final m = dateTime.minute.toString().padLeft(2, '0');
  return '${_formatDate(dateTime)} - $h:$m';
}

String _appointmentStatusLabel(AppointmentStatus status) {
  switch (status) {
    case AppointmentStatus.scheduled:
      return 'Planifie';
    case AppointmentStatus.done:
      return 'Effectue';
    case AppointmentStatus.cancelled:
      return 'Annule';
  }
}
