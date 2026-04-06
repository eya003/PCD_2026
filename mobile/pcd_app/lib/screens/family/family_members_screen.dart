import 'package:flutter/material.dart';

import '../../models/family_member.dart';
import '../../models/family_permissions.dart';
import '../../models/patient_summary.dart';
import '../../services/family_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';

/// Lists family members linked to a patient.
/// Only family admins can transfer admin role.
class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({
    super.key,
    required this.patient,
    required this.isAdmin,
    required this.currentUserId,
    required this.onCurrentUserAdminChanged,
  });

  final PatientSummary patient;
  final bool isAdmin;
  final int currentUserId;
  final ValueChanged<bool> onCurrentUserAdminChanged;

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  late final FamilyService _service;

  bool _isLoading = true;
  bool _isTransferring = false;
  late bool _isCurrentUserAdmin;
  String? _error;
  List<FamilyMember> _members = const [];
  FamilyPermissions get _permissions => FamilyPermissions(isAdmin: _isCurrentUserAdmin);

  @override
  void initState() {
    super.initState();
    _service = FamilyService();
    _isCurrentUserAdmin = widget.isAdmin;
    _load();
  }

  bool _deriveCurrentUserIsAdmin(List<FamilyMember> members) {
    final current = members.where((m) => m.userId == widget.currentUserId);
    if (current.isEmpty) return false;
    return current.first.isAdmin;
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final members = await _service.fetchFamilyMembers(
        patientId: widget.patient.id,
      );
      if (!mounted) return;

      final currentIsAdmin = _deriveCurrentUserIsAdmin(members);
      widget.onCurrentUserAdminChanged(currentIsAdmin);

      setState(() {
        _isCurrentUserAdmin = currentIsAdmin;
        _members = members;
        _isLoading = false;
      });
    } on FamilyException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Impossible de charger les membres famille.';
      });
    }
  }

  Future<void> _confirmTransferAdmin(FamilyMember target) async {
    if (!_permissions.canTransferAdmin || _isTransferring) return;
    if (target.userId == widget.currentUserId || target.isAdmin) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.swap_horiz_outlined, size: 32),
        title: const Text('Transferer le role administrateur ?'),
        content: Text(
          'Vous allez transferer le role administrateur a ${target.fullName}.\n\n'
          'Vous passerez en mode spectateur apres confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isTransferring = true);
    try {
      await _service.transferAdmin(
        patientId: widget.patient.id,
        newAdminUserId: target.userId,
      );

      final refreshed = await _service.fetchFamilyMembers(
        patientId: widget.patient.id,
      );
      if (!mounted) return;

      final currentIsAdmin = _deriveCurrentUserIsAdmin(refreshed);
      widget.onCurrentUserAdminChanged(currentIsAdmin);

      setState(() {
        _members = refreshed;
        _isCurrentUserAdmin = currentIsAdmin;
        _isTransferring = false;
      });
      _showSnackBar('Role administrateur transfere a ${target.fullName}.');
    } on FamilyException catch (e) {
      if (!mounted) return;
      setState(() => _isTransferring = false);
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isTransferring = false);
      _showSnackBar('Impossible de transferer le role administrateur.');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final currentUserMissing =
        !_isLoading && _members.isNotEmpty && !_members.any((m) => m.userId == widget.currentUserId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Membres famille - ${widget.patient.firstName}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Chip(
              label: Text(
                _permissions.isAdmin ? 'Admin' : 'Lecture seule',
                style: const TextStyle(fontSize: 11),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorBody(message: _error!, onRetry: _load)
                : _members.isEmpty
                    ? const EmptyState(
                        icon: Icons.group_off_outlined,
                        title: 'Aucun membre famille',
                        message: 'Aucun membre n est lie a ce patient.',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          if (_isTransferring) ...[
                            const LinearProgressIndicator(minHeight: 3),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          if (_permissions.isViewer) ...[
                            const _ViewerBanner(),
                            const SizedBox(height: AppSpacing.sm),
                          ] else ...[
                            const _AdminInfoBanner(),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          if (currentUserMissing) ...[
                            const _InlineWarning(
                              message:
                                  'Votre role ne peut pas etre determine pour ce patient. '
                                  'L interface reste en mode lecture seule.',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          ..._members.map(
                            (member) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _MemberCard(
                                member: member,
                                isCurrentUser: member.userId == widget.currentUserId,
                                canTransfer: _permissions.canTransferAdmin &&
                                    !_isTransferring &&
                                    member.userId != widget.currentUserId &&
                                    !member.isAdmin,
                                onTransfer: () => _confirmTransferAdmin(member),
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _AdminInfoBanner extends StatelessWidget {
  const _AdminInfoBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.primaryContainer.withAlpha(77),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Vous etes administrateur. Vous pouvez transferer ce role '
                'a un autre membre de la famille.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerBanner extends StatelessWidget {
  const _ViewerBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Mode spectateur: consultation de la liste uniquement.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer.withAlpha(90),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: colorScheme.error, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.isCurrentUser,
    required this.canTransfer,
    required this.onTransfer,
  });

  final FamilyMember member;
  final bool isCurrentUser;
  final bool canTransfer;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final badgeColor = member.isAdmin
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final badgeBg = member.isAdmin
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: member.isAdmin
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  child: Text(
                    member.firstName.isNotEmpty
                        ? member.firstName[0].toUpperCase()
                        : '?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: member.isAdmin
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              member.fullName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(vous)',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.email.isNotEmpty
                            ? member.email
                            : 'Email non disponible',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        member.isAdmin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.visibility_outlined,
                        size: 13,
                        color: badgeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        member.roleLabelFr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _InfoChip(
                  icon: Icons.family_restroom_outlined,
                  label: member.relationLabelFr,
                ),
                if (member.cin.isNotEmpty)
                  _InfoChip(
                    icon: Icons.badge_outlined,
                    label: 'CIN ${member.cin}',
                  ),
              ],
            ),
            if (canTransfer) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onTransfer,
                  icon: const Icon(Icons.swap_horiz_outlined, size: 18),
                  label: const Text('Transferer le role admin'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.primary.withAlpha(128)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Reessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
