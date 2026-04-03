import 'package:flutter/material.dart';

import '../models/status_type.dart';
import '../theme/app_spacing.dart';

class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    required this.selectedStatus,
    required this.onSelected,
  });

  final PatientStatus? selectedStatus;
  final ValueChanged<PatientStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Tous'),
            selected: selectedStatus == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: AppSpacing.xs),
          ...PatientStatus.values.map(
            (status) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(status.label),
                selected: selectedStatus == status,
                onSelected: (_) => onSelected(status),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
