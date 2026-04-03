import 'package:flutter/material.dart';

import '../models/dashboard_kpi.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'status_badge.dart';

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.kpi});

  final DashboardKpi kpi;

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
                Expanded(
                  child: Text(
                    kpi.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.08),
                  child: Icon(kpi.icon, size: 20, color: AppColors.primaryBlue),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              kpi.value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              kpi.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(label: kpi.badge, tone: kpi.badgeTone),
            ),
          ],
        ),
      ),
    );
  }
}
