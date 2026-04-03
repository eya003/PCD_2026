import 'package:flutter/material.dart';

import '../models/status_type.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
  });

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _colors(tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.badge),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  (Color, Color) _colors(BadgeTone tone) {
    switch (tone) {
      case BadgeTone.primary:
        return (AppColors.primaryBlue.withOpacity(0.12), AppColors.primaryBlue);
      case BadgeTone.success:
        return (AppColors.statusGreen.withOpacity(0.15), AppColors.statusGreen);
      case BadgeTone.warning:
        return (AppColors.statusTeal.withOpacity(0.16), AppColors.statusTeal);
      case BadgeTone.neutral:
        return (AppColors.surfaceAlt, AppColors.textSecondary);
    }
  }
}
