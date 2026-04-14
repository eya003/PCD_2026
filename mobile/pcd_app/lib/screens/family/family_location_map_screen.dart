import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_spacing.dart';

class FamilyLocationMapScreen extends StatefulWidget {
  const FamilyLocationMapScreen({
    super.key,
    required this.patientName,
    required this.currentPosition,
    required this.originPosition,
    required this.radiusMeters,
  });

  final String patientName;
  final LatLng? currentPosition;
  final LatLng? originPosition;
  final double? radiusMeters;

  @override
  State<FamilyLocationMapScreen> createState() =>
      _FamilyLocationMapScreenState();
}

class _FamilyLocationMapScreenState extends State<FamilyLocationMapScreen> {
  final MapController _mapController = MapController();

  bool get _hasAnyPoint =>
      widget.currentPosition != null || widget.originPosition != null;

  LatLng get _fallbackCenter =>
      widget.currentPosition ??
      widget.originPosition ??
      const LatLng(36.8065, 10.1815);

  double get _initialZoom {
    final current = widget.currentPosition;
    final origin = widget.originPosition;
    if (current == null || origin == null) return 16;
    return _zoomForDistance(_distanceMeters(current, origin));
  }

  void _centerOnCurrent() {
    final current = widget.currentPosition;
    if (current == null) return;
    _mapController.move(current, 16);
  }

  void _centerOnOrigin() {
    final origin = widget.originPosition;
    if (origin == null) return;
    _mapController.move(origin, 16);
  }

  void _showBoth() {
    final current = widget.currentPosition;
    final origin = widget.originPosition;
    if (current == null && origin == null) return;
    if (current == null) {
      _centerOnOrigin();
      return;
    }
    if (origin == null) {
      _centerOnCurrent();
      return;
    }
    final center = _midpoint(current, origin);
    final zoom = _zoomForDistance(_distanceMeters(current, origin));
    _mapController.move(center, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = widget.currentPosition;
    final origin = widget.originPosition;

    return Scaffold(
      appBar: AppBar(title: Text('Carte - ${widget.patientName}')),
      body: !_hasAnyPoint
          ? const _NoMapDataState(
              title: 'Carte indisponible',
              message:
                  'Aucune position patient ni origine de zone disponible pour le moment.',
            )
          : Stack(
              children: [
                _LocationMapView(
                  mapController: _mapController,
                  center: _fallbackCenter,
                  zoom: _initialZoom,
                  currentPosition: current,
                  originPosition: origin,
                  radiusMeters: widget.radiusMeters,
                ),
                Positioned(
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'map_fit_all',
                        onPressed: _showBoth,
                        tooltip: 'Voir les deux',
                        child: const Icon(Icons.fit_screen_outlined),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      FloatingActionButton.small(
                        heroTag: 'map_origin',
                        onPressed: origin == null ? null : _centerOnOrigin,
                        tooltip: 'Recentrer origine',
                        child: const Icon(Icons.home_outlined),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      FloatingActionButton.small(
                        heroTag: 'map_patient',
                        onPressed: current == null ? null : _centerOnCurrent,
                        tooltip: 'Recentrer patient',
                        child: const Icon(Icons.my_location_outlined),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  top: AppSpacing.md,
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.surface.withAlpha(230),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _LegendChip(
                            icon: Icons.location_pin,
                            color: Colors.red.shade400,
                            label: 'Patient / suivi',
                          ),
                          _LegendChip(
                            icon: Icons.home_rounded,
                            color: Colors.blue.shade700,
                            label: 'Origine',
                          ),
                          if (widget.radiusMeters != null)
                            _LegendChip(
                              icon: Icons.radio_button_checked_outlined,
                              color: Colors.blue.shade300,
                              label:
                                  'Rayon ${_formatMeters(widget.radiusMeters!)}',
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class FamilyLocationMiniMapCard extends StatefulWidget {
  const FamilyLocationMiniMapCard({
    super.key,
    required this.currentPosition,
    required this.originPosition,
    required this.radiusMeters,
    required this.onOpenExpanded,
  });

  final LatLng? currentPosition;
  final LatLng? originPosition;
  final double? radiusMeters;
  final VoidCallback onOpenExpanded;

  @override
  State<FamilyLocationMiniMapCard> createState() =>
      _FamilyLocationMiniMapCardState();
}

class _FamilyLocationMiniMapCardState extends State<FamilyLocationMiniMapCard> {
  final MapController _mapController = MapController();

  bool get _hasAnyPoint =>
      widget.currentPosition != null || widget.originPosition != null;

  LatLng get _fallbackCenter =>
      widget.currentPosition ??
      widget.originPosition ??
      const LatLng(36.8065, 10.1815);

  double get _initialZoom {
    final current = widget.currentPosition;
    final origin = widget.originPosition;
    if (current == null || origin == null) return 16;
    return _zoomForDistance(_distanceMeters(current, origin));
  }

  @override
  void didUpdateWidget(covariant FamilyLocationMiniMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentChanged = !_samePoint(
      oldWidget.currentPosition,
      widget.currentPosition,
    );
    final originChanged = !_samePoint(
      oldWidget.originPosition,
      widget.originPosition,
    );
    if (!currentChanged && !originChanged) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasAnyPoint) return;
      _mapController.move(_fallbackCenter, _initialZoom);
    });
  }

  void _centerOnOrigin() {
    final origin = widget.originPosition;
    if (origin == null) return;
    _mapController.move(origin, 16);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_hasAnyPoint) {
      return const _NoMapDataState(
        title: 'Carte de localisation',
        message:
            'La carte sera disponible des qu une position ou une origine sera connue.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.map_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Carte de localisation',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: widget.originPosition == null ? null : _centerOnOrigin,
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Origine'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              IgnorePointer(
                ignoring: true,
                child: _LocationMapView(
                  mapController: _mapController,
                  center: _fallbackCenter,
                  zoom: _initialZoom,
                  currentPosition: widget.currentPosition,
                  originPosition: widget.originPosition,
                  radiusMeters: widget.radiusMeters,
                ),
              ),
              Positioned(
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: FilledButton.icon(
                  onPressed: widget.onOpenExpanded,
                  icon: const Icon(Icons.open_in_full_outlined, size: 18),
                  label: const Text('Agrandir'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _LegendChip(
              icon: Icons.location_pin,
              color: Colors.red.shade400,
              label: 'Patient / suivi',
            ),
            _LegendChip(
              icon: Icons.home_rounded,
              color: Colors.blue.shade700,
              label: 'Origine',
            ),
            if (widget.radiusMeters != null)
              _LegendChip(
                icon: Icons.radio_button_checked_outlined,
                color: Colors.blue.shade300,
                label: 'Rayon ${_formatMeters(widget.radiusMeters!)}',
              ),
          ],
        ),
      ],
    );
  }
}

bool _samePoint(LatLng? a, LatLng? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.latitude == b.latitude && a.longitude == b.longitude;
}

class _LocationMapView extends StatelessWidget {
  const _LocationMapView({
    required this.center,
    required this.zoom,
    required this.currentPosition,
    required this.originPosition,
    required this.radiusMeters,
    this.mapController,
  });

  final MapController? mapController;
  final LatLng center;
  final double zoom;
  final LatLng? currentPosition;
  final LatLng? originPosition;
  final double? radiusMeters;

  @override
  Widget build(BuildContext context) {
    final circleCenter = originPosition;
    final showCircle =
        circleCenter != null && radiusMeters != null && radiusMeters! > 0;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(initialCenter: center, initialZoom: zoom),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.pcd_app',
          maxNativeZoom: 19,
        ),
        if (showCircle)
          CircleLayer(
            circles: [
              CircleMarker(
                point: circleCenter,
                radius: radiusMeters!,
                useRadiusInMeter: true,
                color: Colors.blue.shade300.withAlpha(50),
                borderColor: Colors.blue.shade400,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (originPosition != null)
              Marker(
                point: originPosition!,
                width: 44,
                height: 44,
                child: const _HomeMarker(),
              ),
            if (currentPosition != null)
              Marker(
                point: currentPosition!,
                width: 42,
                height: 42,
                child: const _TrackedPatientMarker(),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrackedPatientMarker extends StatelessWidget {
  const _TrackedPatientMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.red.shade300.withAlpha(95),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.red.shade500,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ],
    );
  }
}

class _HomeMarker extends StatelessWidget {
  const _HomeMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(225),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue.shade700, width: 2),
      ),
      child: Icon(Icons.home_rounded, color: Colors.blue.shade700, size: 22),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _NoMapDataState extends StatelessWidget {
  const _NoMapDataState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(140),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.map_outlined, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

LatLng _midpoint(LatLng a, LatLng b) =>
    LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);

double _distanceMeters(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  final dLat = _degToRad(b.latitude - a.latitude);
  final dLon = _degToRad(b.longitude - a.longitude);
  final lat1 = _degToRad(a.latitude);
  final lat2 = _degToRad(b.latitude);

  final hav =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(lat1) * math.cos(lat2);
  final c = 2 * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
  return earthRadius * c;
}

double _degToRad(double value) => value * math.pi / 180;

double _zoomForDistance(double meters) {
  if (meters <= 100) return 16.5;
  if (meters <= 300) return 15.5;
  if (meters <= 700) return 14.5;
  if (meters <= 1500) return 13.5;
  if (meters <= 3000) return 12.5;
  if (meters <= 7000) return 11.5;
  if (meters <= 15000) return 10.5;
  return 9.5;
}

String _formatMeters(double meters) {
  if (meters % 1 == 0) return '${meters.toInt()} m';
  return '${meters.toStringAsFixed(1)} m';
}
