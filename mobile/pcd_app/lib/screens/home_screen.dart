import 'package:flutter/material.dart';

import '../models/user_role.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.role,
    required this.email,
    required this.userId,
    required this.onLogout,
  });

  final UserRole role;
  final String email;
  final int userId;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(role.homeTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Icon(
                              role.icon,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              role.homeTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Role: ${role.label}',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Email: $email', style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text(
                        'User ID: $userId',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Ecran placeholder. La session JWT est stockee localement (shared_preferences).',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () async {
                          await onLogout();
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Se deconnecter'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
