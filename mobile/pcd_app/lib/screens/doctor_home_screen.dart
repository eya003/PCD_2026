import 'package:flutter/material.dart';

import 'create_patient_screen.dart';
import 'search_patient_screen.dart';

enum _DoctorAccountAction { profile, logout }

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({
    super.key,
    required this.email,
    required this.userId,
    required this.onLogout,
  });

  final String email;
  final int userId;
  final Future<void> Function() onLogout;

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  int _selectedIndex = 0;

  Future<void> _openSearchPatientScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SearchPatientScreen()),
    );
  }

  Future<void> _openCreatePatientScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreatePatientScreen()),
    );
  }

  void _showPlaceholderSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleAccountAction(_DoctorAccountAction action) async {
    switch (action) {
      case _DoctorAccountAction.profile:
        _showPlaceholderSnackBar('Profil: fonctionnalite a venir.');
        break;
      case _DoctorAccountAction.logout:
        await widget.onLogout();
        break;
    }
  }

  String get _displayName => 'Dr. ${widget.email}';

  String get _avatarText {
    final text = widget.email.trim();
    if (text.isEmpty) return 'D';
    return text.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace M\u00E9decin'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              _showPlaceholderSnackBar(
                'Notifications: aucune nouvelle notification.',
              );
            },
            icon: const Icon(Icons.notifications_none_outlined),
          ),
          PopupMenuButton<_DoctorAccountAction>(
            tooltip: 'Compte',
            onSelected: (value) {
              _handleAccountAction(value);
            },
            itemBuilder: (context) => const [
              PopupMenuItem<_DoctorAccountAction>(
                value: _DoctorAccountAction.profile,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline),
                  title: Text('Profil'),
                ),
              ),
              PopupMenuItem<_DoctorAccountAction>(
                value: _DoctorAccountAction.logout,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('D\u00E9connexion'),
                ),
              ),
            ],
            icon: CircleAvatar(radius: 16, child: Text(_avatarText)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _HomeTab(
              displayName: _displayName,
              email: widget.email,
              userId: widget.userId,
              onOpenSearch: _openSearchPatientScreen,
              onOpenCreate: _openCreatePatientScreen,
            ),
            const _DoctorPlaceholderTab(
              icon: Icons.groups_outlined,
              title: 'Patients',
              message:
                  'Liste et gestion des patients a venir. Utilisez l\'onglet Accueil pour ouvrir ou creer un patient.',
            ),
            const _DoctorPlaceholderTab(
              icon: Icons.settings_outlined,
              title: 'Parametres',
              message: 'Parametres du compte et preferences a venir.',
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Param\u00E8tres',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.displayName,
    required this.email,
    required this.userId,
    required this.onOpenSearch,
    required this.onOpenCreate,
  });

  final String displayName;
  final String email;
  final int userId;
  final Future<void> Function() onOpenSearch;
  final Future<void> Function() onOpenCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour $displayName',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bienvenue dans votre espace de travail. Choisissez une action pour commencer.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.email_outlined, size: 18),
                            label: Text(email),
                          ),
                          Chip(
                            avatar: const Icon(Icons.badge_outlined, size: 18),
                            label: Text('ID: $userId'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _DoctorActionCard(
                icon: Icons.search_outlined,
                title: 'Ouvrir un patient existant',
                description:
                    'Recherchez un patient par nom, prenom et date de naissance.',
                buttonLabel: 'Rechercher un patient',
                onPressed: onOpenSearch,
              ),
              const SizedBox(height: 16),
              _DoctorActionCard(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Creer un nouveau patient',
                description:
                    'Saisissez les informations principales pour creer un dossier patient.',
                buttonLabel: 'Creer un patient',
                onPressed: onOpenCreate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorActionCard extends StatelessWidget {
  const _DoctorActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(icon, color: colorScheme.onSecondaryContainer),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  onPressed();
                },
                icon: const Icon(Icons.arrow_forward),
                label: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorPlaceholderTab extends StatelessWidget {
  const _DoctorPlaceholderTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
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
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(icon, color: colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
