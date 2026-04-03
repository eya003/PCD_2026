import 'package:flutter/material.dart';

import '../models/user_role.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key, required this.onRoleSelected});

  final ValueChanged<UserRole> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('PCD'), centerTitle: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choisir le type de compte',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selectionnez votre espace pour continuer.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: isWide
                            ? Row(
                                children: [
                                  Expanded(
                                    child: _RoleCard(
                                      role: UserRole.doctor,
                                      onTap: () =>
                                          onRoleSelected(UserRole.doctor),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _RoleCard(
                                      role: UserRole.family,
                                      onTap: () =>
                                          onRoleSelected(UserRole.family),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Expanded(
                                    child: _RoleCard(
                                      role: UserRole.doctor,
                                      onTap: () =>
                                          onRoleSelected(UserRole.doctor),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: _RoleCard(
                                      role: UserRole.family,
                                      onTap: () =>
                                          onRoleSelected(UserRole.family),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Vous pourrez vous connecter ou creer un compte ensuite.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.onTap});

  final UserRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(role.icon, color: colorScheme.onPrimaryContainer),
              ),
              const Spacer(),
              Text(
                'Compte ${role.label}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                role.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continuer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
