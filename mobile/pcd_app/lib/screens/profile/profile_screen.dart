import 'package:flutter/material.dart';

import '../../models/user_role.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/section_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.email,
    required this.userId,
    required this.role,
    required this.onLogout,
  });

  final String email;
  final int userId;
  final UserRole role;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text(
                    email.trim().isEmpty
                        ? 'D'
                        : email.trim().substring(0, 1).toUpperCase(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role == UserRole.doctor
                            ? 'Profil medecin'
                            : 'Profil famille',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(email),
                      Text('User ID: $userId'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionCard(
          title: 'Preferences',
          child: Text('Parametres de notifications et compte a venir.'),
        ),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          label: 'Deconnexion',
          icon: Icons.logout,
          onPressed: () {
            onLogout();
          },
        ),
      ],
    );
  }
}
