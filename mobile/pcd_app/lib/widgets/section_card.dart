import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titleWidget = Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );

    Widget buildHeader() {
      if (action == null) {
        return titleWidget;
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final shouldStack = constraints.maxWidth < 460;
          if (shouldStack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                const SizedBox(height: AppSpacing.xs),
                Align(alignment: Alignment.centerLeft, child: action!),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleWidget),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: action!),
            ],
          );
        },
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildHeader(),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
