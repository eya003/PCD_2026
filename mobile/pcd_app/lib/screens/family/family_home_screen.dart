import 'package:flutter/material.dart';

import '../../models/patient_summary.dart';
import '../../services/family_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';

/// Main dashboard for family users.
/// Loads and displays the patients linked to the logged-in family member.
class FamilyHomeScreen extends StatefulWidget {
  const FamilyHomeScreen({
    super.key,
    required this.firstName,
  });

  final String firstName;

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  late final FamilyService _service;

  bool _isLoading = true;
  String? _error;
  List<PatientSummary> _patients = const [];

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
          // ── Greeting ─────────────────────────────────────
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

          // ── Patient section ───────────────────────────────
          if (_isLoading)
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
              message: 'Aucun patient n est associe a votre compte pour le moment.',
            )
          else if (_patients.length == 1)
            _PatientSummaryCard(patient: _patients.first)
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
                child: _PatientSummaryCard(patient: p),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Patient card ──────────────────────────────────────────────────────────────

class _PatientSummaryCard extends StatelessWidget {
  const _PatientSummaryCard({required this.patient});

  final PatientSummary patient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Identity row ──────────────────────────────
            Row(
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
                        'CIN : ${patient.cin}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Details row ───────────────────────────────
            Row(
              children: [
                _InfoChip(
                  icon: Icons.cake_outlined,
                  label: '${patient.age} ans',
                ),
              ],
            ),

            // ── Future sections placeholder ───────────────
            // Rendez-vous, traitements, localisation, alertes
            // seront ajoutés dans les sprints suivants.
          ],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
