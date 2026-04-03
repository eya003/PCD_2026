import 'package:flutter/material.dart';

import '../models/ai_result_item.dart';
import '../models/status_type.dart';
import '../theme/app_spacing.dart';
import 'status_badge.dart';

class AiResultCard extends StatelessWidget {
  const AiResultCard({super.key, required this.result, this.onOpen});

  final AiResultItem result;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = result.score >= 75
        ? BadgeTone.success
        : (result.score >= 60 ? BadgeTone.warning : BadgeTone.primary);

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
                    result.patientName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusBadge(
                  label: '${result.modelName} ${result.score}%',
                  tone: tone,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(result.summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(result.dateLabel, style: theme.textTheme.bodySmall),
            if (onOpen != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Voir details'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
