import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'secondary_button.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.currentIndex,
    required this.email,
    required this.onSelectIndex,
    required this.onOpenAboutApp,
    required this.onLogout,
  });

  final int currentIndex;
  final String email;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback onOpenAboutApp;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryBlue,
                    child: Text('A', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AlzCare',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          email,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _DrawerItem(
                selected: currentIndex == 0,
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                onTap: () => onSelectIndex(0),
              ),
              _DrawerItem(
                selected: currentIndex == 1,
                icon: Icons.groups_outlined,
                label: 'Patients',
                onTap: () => onSelectIndex(1),
              ),
              _DrawerItem(
                selected: currentIndex == 2,
                icon: Icons.psychology_alt_outlined,
                label: 'Module IA',
                onTap: () => onSelectIndex(2),
              ),
              _DrawerItem(
                selected: false,
                icon: Icons.info_outline,
                label: 'À propos de l’application',
                onTap: onOpenAboutApp,
              ),
              _DrawerItem(
                selected: currentIndex == 3,
                icon: Icons.person_outline,
                label: 'Profil',
                onTap: () => onSelectIndex(3),
              ),
              const Spacer(),
              SecondaryButton(
                label: 'Deconnexion',
                icon: Icons.logout,
                onPressed: () async {
                  Navigator.of(context).pop();
                  await onLogout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = AppColors.primaryBlue.withValues(alpha: 0.10);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? selectedColor : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
