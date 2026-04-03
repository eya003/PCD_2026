import 'package:flutter/material.dart';

import '../models/patient_summary.dart';
import '../models/status_type.dart';
import '../theme/app_spacing.dart';
import 'primary_button.dart';
import 'status_badge.dart';

class PatientCard extends StatelessWidget {
  const PatientCard({super.key, required this.patient, this.onOpen});

  final PatientSummary patient;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: patient.status.label,
                  tone: _statusTone(patient.status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Age: ${patient.age} ans'),
            const SizedBox(height: AppSpacing.xs),
            Text('CIN: ${patient.cin}'),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              fullWidth: false,
              label: 'Voir fiche',
              onPressed: onOpen,
            ),
          ],
        ),
      ),
    );
  }

  BadgeTone _statusTone(PatientStatus status) {
    switch (status) {
      case PatientStatus.suivi:
        return BadgeTone.neutral;
      case PatientStatus.nouveau:
        return BadgeTone.primary;
      case PatientStatus.aVerifier:
        return BadgeTone.warning;
    }
  }
}
