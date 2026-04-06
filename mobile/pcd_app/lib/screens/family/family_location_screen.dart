import 'package:flutter/material.dart';

import '../../models/patient_location.dart';
import '../../models/patient_summary.dart';
import '../../services/location_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/section_card.dart';

/// Displays the last known location and location history for a patient.
/// The position currently comes from the family administrator device.
class FamilyLocationScreen extends StatefulWidget {
  const FamilyLocationScreen({
    super.key,
    required this.patient,
  });

  final PatientSummary patient;

  @override
  State<FamilyLocationScreen> createState() => _FamilyLocationScreenState();
}

class _FamilyLocationScreenState extends State<FamilyLocationScreen> {
  late final LocationService _service;

  bool _isLoading = true;
  String? _error;
  PatientLocation? _lastLocation;
  List<PatientLocation> _history = const [];

  @override
  void initState() {
    super.initState();
    _service = LocationService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    PatientLocation? lastLocation;
    List<PatientLocation> history = const [];
    String? message;

    try {
      lastLocation = await _service.fetchLastLocation(patientId: widget.patient.id);
    } on LocationException catch (e) {
      if (e.statusCode == 401) {
        message = e.message;
      } else {
        message = 'Impossible de charger la derniere position pour le moment.';
      }
    } catch (_) {
      message = 'Impossible de charger la derniere position pour le moment.';
    }

    try {
      history = await _service.fetchLocationHistory(patientId: widget.patient.id);
    } on LocationException catch (e) {
      if (e.statusCode == 401) {
        message ??= e.message;
      } else {
        message ??= 'Impossible de charger l historique pour le moment.';
      }
    } catch (_) {
      message ??= 'Impossible de charger l historique pour le moment.';
    }

    if (!mounted) return;
    setState(() {
      _lastLocation = lastLocation;
      _history = history;
      _error = message;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Localisation - ${widget.patient.firstName}'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: _isLoading
              ? const [
                  SizedBox(height: AppSpacing.xl),
                  Center(child: CircularProgressIndicator()),
                ]
              : [
                  const _SourceInfoBanner(),
                  const SizedBox(height: AppSpacing.md),
                  if (_error != null) ...[
                    _InlineInfoCard(message: _error!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  SectionCard(
                    title: 'Derniere position',
                    child: _lastLocation == null
                        ? const _EmptySectionMessage(
                            icon: Icons.location_off_outlined,
                            title: 'Aucune localisation disponible',
                            message:
                                'Aucune position n a encore ete enregistree.',
                          )
                        : _LocationDetail(
                            location: _lastLocation!,
                            isLatest: true,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SectionCard(
                    title: 'Historique des positions',
                    action: Text(
                      '${_history.length} enregistrement${_history.length > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    child: _history.isEmpty
                        ? const _EmptySectionMessage(
                            icon: Icons.history_outlined,
                            title: 'Historique vide',
                            message:
                                'Aucune localisation disponible dans l historique.',
                          )
                        : Column(
                            children: _history
                                .map((loc) => _LocationRow(location: loc))
                                .toList(),
                          ),
                  ),
                ],
        ),
      ),
    );
  }
}

class _SourceInfoBanner extends StatelessWidget {
  const _SourceInfoBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: Color.alphaBlend(
        colorScheme.secondaryContainer.withAlpha(102),
        colorScheme.surface,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.secondary.withAlpha(77),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: colorScheme.secondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Source de la position',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cette position est basee sur le telephone du '
                    'membre famille administrateur. Elle ne represente '
                    'pas forcement la localisation exacte du patient.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer.withAlpha(217),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineInfoCard extends StatelessWidget {
  const _InlineInfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _EmptySectionMessage extends StatelessWidget {
  const _EmptySectionMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationDetail extends StatelessWidget {
  const _LocationDetail({
    required this.location,
    this.isLatest = false,
  });

  final PatientLocation location;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(value, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLatest)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Position transmise par l accompagnant',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        row(
          Icons.north_outlined,
          'Latitude',
          location.latitude.toStringAsFixed(6),
        ),
        row(
          Icons.east_outlined,
          'Longitude',
          location.longitude.toStringAsFixed(6),
        ),
        row(
          Icons.access_time_outlined,
          'Transmise le',
          location.formattedDateTime,
        ),
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.location});

  final PatientLocation location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            Icons.share_location_outlined,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              location.formattedCoords,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            location.formattedDateTime,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
