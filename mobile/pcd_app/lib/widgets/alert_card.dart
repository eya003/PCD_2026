import 'package:flutter/material.dart';

import '../models/alert_item.dart';
import '../theme/app_spacing.dart';
import 'status_badge.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert, this.onView});

  final AlertItem alert;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(label: alert.type, tone: alert.tone),
                const Spacer(),
                TextButton(onPressed: onView, child: const Text('Voir')),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              alert.patientName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(alert.message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(alert.dateLabel, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
