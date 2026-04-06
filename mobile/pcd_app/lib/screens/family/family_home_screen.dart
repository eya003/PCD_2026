import 'package:flutter/material.dart';

import '../../models/patient_summary.dart';
import '../../services/family_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';
import 'family_patient_screen.dart';

/// Main dashboard for family users.
/// Loads linked patients and opens the patient detail on tap.
class FamilyHomeScreen extends StatefulWidget {
  const FamilyHomeScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.isAdmin,
  });

  final String firstName;
  final String lastName;
  final bool isAdmin;

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  late final FamilyService _service;

  bool _isLoading = true;
  String? _error;
  List<PatientSummary> _patients = const [];

  /// True once we have auto-navigated to the single patient.
  /// Prevents re-navigation on rebuild or after the user presses back.
  bool _hasAutoNavigated = false;

  @override
  void initState() {
    super.initState();
    _service = FamilyService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final patients = await _service.fetchLinkedPatients();
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _isLoading = false;
      });
      // If exactly one patient and we have not auto-navigated yet this session,
      // navigate directly after the current frame renders (avoids flash of list).
      if (patients.length == 1 && !_hasAutoNavigated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasAutoNavigated) {
            debugPrint('FamilyHome: single patient detected - auto-navigating.');
            _hasAutoNavigated = true;
            _openPatient(patients.first);
          }
        });
      }
    } on FamilyException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Impossible de charger les patients.';
      });
    }
  }

  void _openPatient(PatientSummary patient) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyPatientScreen(
          patient: patient,
          currentUserId: 0,
          isAdmin: widget.isAdmin,
          familyFirstName: widget.firstName,
          familyLastName: widget.lastName,
          onFamilyRoleChanged: (_) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = widget.firstName.trim().isNotEmpty
        ? 'Bonjour, ${widget.firstName} !'
        : 'Bonjour !';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            greeting,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Voici le suivi de votre proche.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          // Single patient: keep spinner visible while auto-navigation is pending
          // to avoid a flash of the card before the push completes.
          else if (_patients.length == 1 && !_hasAutoNavigated)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Chargement impossible',
              message: _error!,
            )
          else if (_patients.isEmpty)
            const EmptyState(
              icon: Icons.person_search_outlined,
              title: 'Aucun patient lie',
              message: 'Aucun patient n est associe a votre compte.',
            )
          else if (_patients.length == 1)
            // User returned from patient screen - show the card so they can re-enter.
            _PatientCard(
              patient: _patients.first,
              onTap: () => _openPatient(_patients.first),
            )
          else ...[
            Text(
              'Vos patients (${_patients.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._patients.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _PatientCard(
                  patient: p,
                  onTap: () => _openPatient(p),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient, required this.onTap});

  final PatientSummary patient;
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
              CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  patient.firstName.trim().isNotEmpty
                      ? patient.firstName.trim().substring(0, 1).toUpperCase()
                      : '?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.fullName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${patient.age} ans  -  CIN : ${patient.cin}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
