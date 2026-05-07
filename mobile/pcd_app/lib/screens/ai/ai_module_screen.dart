import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/mri_prediction_result.dart';
import '../../models/patient_summary.dart';
import '../../services/mri_prediction_service.dart';
import '../../services/patients_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';
import '../../widgets/secondary_button.dart';

class AiModuleScreen extends StatefulWidget {
  const AiModuleScreen({super.key});

  @override
  State<AiModuleScreen> createState() => _AiModuleScreenState();
}

class _AiModuleScreenState extends State<AiModuleScreen> {
  final PatientsService _patientsService = PatientsService();
  final MriPredictionService _predictionService = MriPredictionService();
  final TextEditingController _patientSearchController =
      TextEditingController();

  bool _isLoadingPatients = true;
  bool _isSubmitting = false;
  List<PatientSummary> _patients = const [];
  PatientSummary? _selectedPatient;
  PlatformFile? _selectedFile;
  MriPredictionResult? _result;
  String? _patientLoadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoadingPatients = true;
      _patientLoadError = null;
    });

    try {
      final patients = await _patientsService.fetchDoctorPatients();
      if (!mounted) return;

      final selectedId = _selectedPatient?.id;
      setState(() {
        _patients = patients;
        _selectedPatient = selectedId == null
            ? null
            : patients.cast<PatientSummary?>().firstWhere(
                (patient) => patient?.id == selectedId,
                orElse: () => null,
              );
        _isLoadingPatients = false;
      });
    } on PatientsException catch (e) {
      if (!mounted) return;
      setState(() {
        _patientLoadError = e.message;
        _isLoadingPatients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _patientLoadError = 'Impossible de charger les patients: $e';
        _isLoadingPatients = false;
      });
    }
  }

  Future<void> _pickMriFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['nii', 'gz'],
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      if (!_isValidNiftiFile(file.name)) {
        setState(() {
          _selectedFile = null;
          _result = null;
          _error = 'Format invalide. Utilisez un fichier .nii ou .nii.gz.';
        });
        return;
      }

      if ((file.path == null || file.path!.trim().isEmpty) &&
          (file.bytes == null || file.bytes!.isEmpty)) {
        setState(() {
          _selectedFile = null;
          _result = null;
          _error = 'Aucun fichier selectionne.';
        });
        return;
      }

      setState(() {
        _selectedFile = file;
        _result = null;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de selectionner le fichier IRM: $e';
      });
    }
  }

  Future<void> _submitPrediction() async {
    final patient = _selectedPatient;
    final file = _selectedFile;

    setState(() {
      _error = null;
      _result = null;
    });

    if (patient == null) {
      setState(() => _error = 'Aucun patient selectionne.');
      return;
    }
    if (file == null) {
      setState(() => _error = 'Aucun fichier selectionne.');
      return;
    }
    if (!_isValidNiftiFile(file.name)) {
      setState(() {
        _error = 'Format invalide. Utilisez un fichier .nii ou .nii.gz.';
      });
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prediction = await _predictionService.predictMri(
        patientId: patient.id,
        fileName: file.name,
        filePath: file.path,
        fileBytes: file.bytes,
      );

      if (!mounted) return;
      setState(() {
        _result = prediction;
        _isSubmitting = false;
      });
    } on MriPredictionException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur pendant la prediction IA: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadPatients,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppHeader(
            title: 'Prediction Alzheimer par IRM',
            subtitle: 'Analyse IA d un fichier IRM cerebral au format NIfTI.',
            actions: [
              SecondaryButton(
                label: 'Rafraichir',
                icon: Icons.refresh_outlined,
                fullWidth: false,
                onPressed: _isLoadingPatients || _isSubmitting
                    ? null
                    : _loadPatients,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _MedicalNotice(),
          const SizedBox(height: AppSpacing.md),
          SectionCard(title: 'Patient', child: _buildPatientPicker(context)),
          const SizedBox(height: AppSpacing.md),
          SectionCard(title: 'Fichier IRM', child: _buildFilePicker(context)),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: _isSubmitting
                ? 'Analyse en cours...'
                : 'Lancer la prediction',
            icon: Icons.psychology_alt_outlined,
            onPressed: _isSubmitting ? null : _submitPrediction,
          ),
          if (_isSubmitting) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _MessageBox(
              icon: Icons.error_outline,
              message: _error!,
              tone: _MessageTone.error,
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ResultSection(result: _result!),
          ],
        ],
      ),
    );
  }

  Widget _buildPatientPicker(BuildContext context) {
    if (_isLoadingPatients) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_patientLoadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MessageBox(
            icon: Icons.error_outline,
            message: _patientLoadError!,
            tone: _MessageTone.error,
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Reessayer',
            icon: Icons.refresh_outlined,
            onPressed: _loadPatients,
          ),
        ],
      );
    }

    if (_patients.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'Aucun patient',
        message: 'Aucun patient medecin disponible.',
      );
    }

    final filteredPatients = _filteredPatients;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _patientSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Rechercher un patient',
            hintText: 'Nom, prenom, CIN ou code patient',
            prefixIcon: const Icon(Icons.search_outlined),
            suffixIcon: _patientSearchController.text.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _patientSearchController.clear();
                      setState(() {});
                    },
                  ),
          ),
        ),
        if (_selectedPatient != null) ...[
          const SizedBox(height: AppSpacing.md),
          _SelectedPatientCard(patient: _selectedPatient!),
        ],
        const SizedBox(height: AppSpacing.md),
        if (filteredPatients.isEmpty)
          const EmptyState(
            icon: Icons.search_off_outlined,
            title: 'Aucun resultat',
            message: 'Aucun patient ne correspond a cette recherche.',
          )
        else
          Column(
            children: filteredPatients
                .map(
                  (patient) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _PatientTile(
                      patient: patient,
                      isSelected: patient.id == _selectedPatient?.id,
                      onTap: () {
                        setState(() {
                          _selectedPatient = patient;
                          _result = null;
                          _error = null;
                        });
                      },
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildFilePicker(BuildContext context) {
    final selectedFile = _selectedFile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Formats acceptes : .nii ou .nii.gz',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: selectedFile == null ? 'Choisir un fichier' : 'Changer',
          icon: Icons.upload_file_outlined,
          onPressed: _isSubmitting ? null : _pickMriFile,
        ),
        if (selectedFile != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _SelectedFileCard(
            file: selectedFile,
            onClear: _isSubmitting
                ? null
                : () {
                    setState(() {
                      _selectedFile = null;
                      _result = null;
                    });
                  },
          ),
        ],
      ],
    );
  }

  List<PatientSummary> get _filteredPatients {
    final query = _normalize(_patientSearchController.text);
    final patients = query.isEmpty
        ? _patients
        : _patients.where((patient) => _matchesPatient(patient, query));
    return patients.take(query.isEmpty ? 8 : 20).toList();
  }

  bool _matchesPatient(PatientSummary patient, String query) {
    return _normalize(patient.firstName).contains(query) ||
        _normalize(patient.lastName).contains(query) ||
        _normalize(patient.fullName).contains(query) ||
        _normalize(patient.cin).contains(query) ||
        _normalize(patient.code).contains(query);
  }

  String _normalize(String value) => value.trim().toLowerCase();

  bool _isValidNiftiFile(String fileName) {
    final lowerName = fileName.trim().toLowerCase();
    return lowerName.endsWith('.nii') || lowerName.endsWith('.nii.gz');
  }
}

class _MedicalNotice extends StatelessWidget {
  const _MedicalNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.onSecondaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              "Ce résultat est une aide au diagnostic et ne remplace pas l’avis médical du médecin.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedPatientCard extends StatelessWidget {
  const _SelectedPatientCard({required this.patient});

  final PatientSummary patient;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: colors.onPrimaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${patient.fullName} - ${patient.cin} - ${patient.code}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({
    required this.patient,
    required this.isSelected,
    required this.onTap,
  });

  final PatientSummary patient;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: isSelected ? colors.primaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        selected: isSelected,
        leading: CircleAvatar(child: Text(_initials(patient))),
        title: Text(patient.fullName),
        subtitle: Text('CIN ${patient.cin} - Code ${patient.code}'),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: colors.primary)
            : const Icon(Icons.chevron_right),
      ),
    );
  }

  String _initials(PatientSummary patient) {
    final first = patient.firstName.trim();
    final last = patient.lastName.trim();
    final firstInitial = first.isEmpty ? '' : first[0].toUpperCase();
    final lastInitial = last.isEmpty ? '' : last[0].toUpperCase();
    final initials = '$firstInitial$lastInitial';
    return initials.isEmpty ? 'P' : initials;
  }
}

class _SelectedFileCard extends StatelessWidget {
  const _SelectedFileCard({required this.file, required this.onClear});

  final PlatformFile file;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file_outlined),
        title: Text(file.name),
        subtitle: Text(_formatFileSize(file.size)),
        trailing: IconButton(
          tooltip: 'Retirer',
          onPressed: onClear,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} Ko';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} Mo';
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.result});

  final MriPredictionResult result;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Resultat IA',
      child: Column(
        children: [
          _ResultRow(label: 'Diagnostic ID', value: '${result.diagnosisId}'),
          _ResultRow(label: 'Patient ID', value: '${result.patientId}'),
          _ResultRow(
            label: 'Questionnaire ID',
            value: result.questionnaireId?.toString() ?? '-',
          ),
          _ResultRow(
            label: 'Classe predite',
            value: result.predictedClass,
            emphasize: true,
          ),
          _ResultRow(
            label: 'Score de confiance',
            value: _formatPercent(result.confidenceScore),
          ),
          _ResultRow(
            label: 'Probabilite AD',
            value: _formatPercent(result.probAd),
          ),
          _ResultRow(
            label: 'Probabilite CNN AD',
            value: _formatPercent(result.cnnProbAd),
          ),
          _ResultRow(
            label: 'Prediction CNN seuil 0.61',
            value: result.cnnPred061.toStringAsFixed(3),
          ),
          _ResultRow(
            label: 'Seuil du modele final',
            value: result.threshold.toStringAsFixed(3),
          ),
          _ResultRow(label: 'Message backend', value: result.message),
        ],
      ),
    );
  }

  String _formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(2)} %';
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
      color: emphasize ? theme.colorScheme.primary : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 6,
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.end,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MessageTone { error }

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.icon,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String message;
  final _MessageTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = switch (tone) {
      _MessageTone.error => colors.errorContainer,
    };
    final foreground = switch (tone) {
      _MessageTone.error => colors.onErrorContainer,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
