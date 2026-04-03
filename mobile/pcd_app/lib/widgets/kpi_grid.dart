import 'package:flutter/material.dart';

import '../models/dashboard_kpi.dart';
import '../theme/app_spacing.dart';
import 'stat_card.dart';

class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.items});

  final List<DashboardKpi> items;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 900 ? 4 : (width >= 650 ? 2 : 1);

    return GridView.builder(
      itemCount: items.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) => StatCard(kpi: items[index]),
    );
  }
}
