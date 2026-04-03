import 'package:flutter/material.dart';

import 'status_type.dart';

class DashboardKpi {
  const DashboardKpi({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.badge,
    this.badgeTone = BadgeTone.neutral,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final String badge;
  final BadgeTone badgeTone;
}
