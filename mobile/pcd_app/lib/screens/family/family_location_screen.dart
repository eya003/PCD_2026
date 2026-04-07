import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/patient_location.dart';
import '../../models/patient_safe_zone.dart';
import '../../models/patient_summary.dart';
import '../../services/local_notification_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/section_card.dart';

/// Displays location history and allows family admin to configure safe zone.
class FamilyLocationScreen extends StatefulWidget {
  const FamilyLocationScreen({
    super.key,
    required this.patient,
    required this.isAdmin,
  });

  final PatientSummary patient;
  final bool isAdmin;

  @override
  State<FamilyLocationScreen> createState() => _FamilyLocationScreenState();
}

class _FamilyLocationScreenState extends State<FamilyLocationScreen> {
  late final LocationService _service;
  late final TextEditingController _radiusController;

  bool _isLoading = true;
  String? _error;
  PatientLocation? _lastLocation;
  List<PatientLocation> _history = const [];

  PatientSafeZone? _safeZone;
  bool _isEditingSafeZone = false;
  bool _isResolvingPosition = false;
  bool _isSavingSafeZone = false;
  String? _safeZoneMessage;
  String? _safeZoneError;
  double? _selectedLatitude;
  double? _selectedLongitude;

  static const Duration _trackingInterval = Duration(seconds: 30);
  Timer? _trackingTimer;
  bool _isTracking = false;
  bool _isSamplingPosition = false;
  String? _trackingError;
  double? _currentLatitude;
  double? _currentLongitude;
  double? _currentDistanceMeters;
  bool? _isOutOfZone;

  @override
  void initState() {
    super.initState();
    _service = LocationService();
    _radiusController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _safeZoneError = null;
    });

    PatientLocation? lastLocation;
    List<PatientLocation> history = const [];
    PatientSafeZone? safeZone;
    String? message;
    String? safeZoneError;

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

    try {
      safeZone = await _service.fetchSafeZone(patientId: widget.patient.id);
    } on LocationException catch (e) {
      if (e.statusCode == 401) {
        message ??= e.message;
      } else if (e.statusCode == 403) {
        safeZoneError = 'Acces non autorise a la zone de securite.';
      } else {
        safeZoneError = 'Impossible de charger la zone de securite.';
      }
    } catch (_) {
      safeZoneError = 'Impossible de charger la zone de securite.';
    }

    if (!mounted) return;
    setState(() {
      _lastLocation = lastLocation;
      _history = history;
      _safeZone = safeZone;
      _error = message;
      _safeZoneError = safeZoneError;
      _safeZoneMessage = null;
      _isLoading = false;
      _isEditingSafeZone = widget.isAdmin && safeZone == null;
      _applySafeZoneToForm(safeZone);
    });

    if ((safeZone == null || !widget.isAdmin) && _isTracking) {
      _stopTracking(clearError: true);
    }
  }

  void _applySafeZoneToForm(PatientSafeZone? safeZone) {
    if (safeZone == null) {
      _selectedLatitude = null;
      _selectedLongitude = null;
      _radiusController.text = '';
      return;
    }

    _selectedLatitude = safeZone.originLatitude;
    _selectedLongitude = safeZone.originLongitude;
    final radius = safeZone.radiusMeters;
    _radiusController.text = radius % 1 == 0
        ? radius.toInt().toString()
        : radius.toStringAsFixed(1);
  }

  Future<Position?> _getCurrentPhonePosition({
    required void Function(String message) onError,
  }) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      onError('GPS desactive. Activez la localisation du telephone puis reessayez.');
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      onError('Permission de localisation refusee. Autorisez-la pour continuer.');
      return null;
    }

    if (permission == LocationPermission.deniedForever) {
      onError(
        'Permission de localisation refusee definitivement. Modifiez-la depuis les reglages.',
      );
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      onError('Impossible de recuperer la position actuelle pour le moment.');
      return null;
    }
  }

  Future<void> _useCurrentPosition() async {
    if (!widget.isAdmin || _isResolvingPosition || _isSavingSafeZone) return;

    setState(() {
      _isResolvingPosition = true;
      _safeZoneError = null;
      _safeZoneMessage = null;
    });

    try {
      final position = await _getCurrentPhonePosition(
        onError: (message) {
          if (!mounted) return;
          setState(() => _safeZoneError = message);
        },
      );
      if (!mounted || position == null) return;
      setState(() {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
        _safeZoneMessage = 'Position actuelle recuperee avec succes.';
      });
    } finally {
      if (mounted) {
        setState(() => _isResolvingPosition = false);
      }
    }
  }

  double? _parseRadiusMeters() {
    final raw = _radiusController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  bool get _canSaveSafeZone {
    final radius = _parseRadiusMeters();
    return widget.isAdmin &&
        !_isSavingSafeZone &&
        !_isResolvingPosition &&
        _selectedLatitude != null &&
        _selectedLongitude != null &&
        radius != null &&
        radius > 0;
  }

  Future<void> _saveSafeZone() async {
    if (!widget.isAdmin || _isSavingSafeZone || _isResolvingPosition) return;

    final radius = _parseRadiusMeters();
    if (radius == null || radius <= 0) {
      setState(() => _safeZoneError = 'Rayon invalide. Saisissez un nombre > 0.');
      return;
    }

    if (_selectedLatitude == null || _selectedLongitude == null) {
      setState(() {
        _safeZoneError =
            'Aucune position selectionnee. Utilisez votre position actuelle.';
      });
      return;
    }

    setState(() {
      _isSavingSafeZone = true;
      _safeZoneError = null;
      _safeZoneMessage = null;
    });

    try {
      final saved = await _service.saveSafeZone(
        patientId: widget.patient.id,
        originLatitude: _selectedLatitude!,
        originLongitude: _selectedLongitude!,
        radiusMeters: radius,
      );

      if (!mounted) return;
      setState(() {
        _safeZone = saved;
        _isEditingSafeZone = false;
        _safeZoneMessage = 'Zone de securite enregistree.';
        _applySafeZoneToForm(saved);
      });
      _showSnackBar('Zone de securite enregistree.');
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() => _safeZoneError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _safeZoneError = 'Impossible d enregistrer la zone de securite.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSavingSafeZone = false);
      }
    }
  }

  Future<void> _startTracking() async {
    if (!widget.isAdmin) {
      setState(() {
        _trackingError =
            'Seul un administrateur peut demarrer le suivi de localisation.';
      });
      return;
    }
    if (_safeZone == null) {
      setState(() {
        _trackingError =
            'Zone non configuree. Configurez d abord la zone de securite.';
      });
      return;
    }
    if (_isTracking) return;

    setState(() {
      _trackingError = null;
      _safeZoneMessage = null;
    });

    final started = await _collectAndEvaluatePosition();
    if (!mounted || !started) return;

    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(_trackingInterval, (_) {
      _collectAndEvaluatePosition();
    });
    setState(() => _isTracking = true);
  }

  void _stopTracking({bool clearError = false}) {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    if (!mounted) return;
    setState(() {
      _isTracking = false;
      if (clearError) _trackingError = null;
    });
  }

  Future<bool> _collectAndEvaluatePosition() async {
    final zone = _safeZone;
    if (zone == null) return false;
    if (_isSamplingPosition) return true;
    if (!mounted) return false;

    setState(() {
      _isSamplingPosition = true;
      _trackingError = null;
    });

    try {
      final position = await _getCurrentPhonePosition(
        onError: (message) {
          if (!mounted) return;
          setState(() => _trackingError = message);
        },
      );
      if (!mounted || position == null) return false;

      final distanceMeters = Geolocator.distanceBetween(
        zone.originLatitude,
        zone.originLongitude,
        position.latitude,
        position.longitude,
      );
      final isOutNow = distanceMeters > zone.radiusMeters;
      final wasOut = _isOutOfZone ?? false;
      final crossedOut = isOutNow && !wasOut;

      setState(() {
        _currentLatitude = position.latitude;
        _currentLongitude = position.longitude;
        _currentDistanceMeters = distanceMeters;
        _isOutOfZone = isOutNow;
        _history = [
          PatientLocation(
            id: _history.isEmpty ? 0 : _history.first.id + 1,
            latitude: position.latitude,
            longitude: position.longitude,
            recordedAt: DateTime.now(),
          ),
          ..._history,
        ].take(30).toList();
        _lastLocation = PatientLocation(
          id: _lastLocation?.id ?? 0,
          latitude: position.latitude,
          longitude: position.longitude,
          recordedAt: DateTime.now(),
        );
      });

      try {
        await _service.recordCurrentLocation(
          patientId: widget.patient.id,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } catch (_) {
        // Local tracking must remain functional even if backend write fails.
      }

      if (crossedOut) {
        await LocalNotificationService.instance.showOutOfZoneAlert(
          distanceMeters: distanceMeters,
          radiusMeters: zone.radiusMeters,
        );
      }

      return true;
    } finally {
      if (mounted) {
        setState(() => _isSamplingPosition = false);
      }
    }
  }

  Future<void> _refreshTrackingSample() async {
    await _collectAndEvaluatePosition();
  }

  void _startEditSafeZone() {
    if (!widget.isAdmin) return;
    _stopTracking(clearError: true);
    setState(() {
      _isEditingSafeZone = true;
      _safeZoneError = null;
      _safeZoneMessage = null;
      _applySafeZoneToForm(_safeZone);
    });
  }

  void _cancelEditSafeZone() {
    if (!widget.isAdmin) return;
    setState(() {
      _isEditingSafeZone = false;
      _safeZoneError = null;
      _safeZoneMessage = null;
      _applySafeZoneToForm(_safeZone);
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildSafeZoneSection() {
    final zone = _safeZone;
    final canEdit = widget.isAdmin;
    final hasSelectedPosition =
        _selectedLatitude != null && _selectedLongitude != null;
    final canSave = _canSaveSafeZone;

    if (!canEdit) {
      return SectionCard(
        title: 'Zone de securite',
        child: zone == null
            ? const _EmptySectionMessage(
                icon: Icons.gps_off_outlined,
                title: 'Aucune zone configuree',
                message:
                    'Seul le membre famille administrateur peut configurer la zone de securite.',
              )
            : _SafeZoneSummary(
                safeZone: zone,
                readOnlyMessage: 'Lecture seule: configuration reservee a l administrateur.',
              ),
      );
    }

    if (zone != null && !_isEditingSafeZone) {
      return SectionCard(
        title: 'Zone de securite',
        action: OutlinedButton.icon(
          onPressed: _startEditSafeZone,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Modifier'),
        ),
        child: _SafeZoneSummary(safeZone: zone),
      );
    }

    return SectionCard(
      title: 'Zone de securite',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            zone == null
                ? 'Configurez la zone de securite de ce patient.'
                : 'Mettez a jour la position d origine et le rayon autorise.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SafeZoneFieldRow(
            icon: Icons.north_outlined,
            label: 'Latitude',
            value: hasSelectedPosition
                ? _selectedLatitude!.toStringAsFixed(6)
                : '--',
          ),
          const SizedBox(height: 4),
          _SafeZoneFieldRow(
            icon: Icons.east_outlined,
            label: 'Longitude',
            value: hasSelectedPosition
                ? _selectedLongitude!.toStringAsFixed(6)
                : '--',
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _radiusController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: !_isSavingSafeZone,
            decoration: const InputDecoration(
              labelText: 'Rayon autorise (metres)',
              hintText: 'Ex: 120',
              prefixIcon: Icon(Icons.radio_button_checked_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: (_isSavingSafeZone || _isResolvingPosition)
                    ? null
                    : _useCurrentPosition,
                icon: _isResolvingPosition
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_outlined),
                label: Text(
                  _isResolvingPosition
                      ? 'Recuperation...'
                      : 'Utiliser ma position actuelle',
                ),
              ),
              FilledButton.icon(
                onPressed: canSave ? _saveSafeZone : null,
                icon: _isSavingSafeZone
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSavingSafeZone ? 'Enregistrement...' : 'Enregistrer',
                ),
              ),
              if (zone != null)
                TextButton(
                  onPressed: (_isSavingSafeZone || _isResolvingPosition)
                      ? null
                      : _cancelEditSafeZone,
                  child: const Text('Annuler'),
                ),
            ],
          ),
          if (!canSave && !_isSavingSafeZone && !_isResolvingPosition) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Selectionnez une position GPS et saisissez un rayon > 0 pour activer l enregistrement.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (_safeZoneMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InlineInfoCard(message: _safeZoneMessage!),
          ],
          if (_safeZoneError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InlineErrorCard(message: _safeZoneError!),
          ],
        ],
      ),
    );
  }

  String _formatMeters(double? meters) {
    if (meters == null) return '--';
    if (meters % 1 == 0) return '${meters.toInt()} m';
    return '${meters.toStringAsFixed(1)} m';
  }

  Widget _buildTrackingSection() {
    final zone = _safeZone;

    if (zone == null) {
      return const SectionCard(
        title: 'Suivi de deplacement',
        child: _EmptySectionMessage(
          icon: Icons.gps_not_fixed_outlined,
          title: 'Zone non configuree',
          message: 'Configurez d abord la zone de securite pour demarrer le suivi.',
        ),
      );
    }

    if (!widget.isAdmin) {
      return SectionCard(
        title: 'Suivi de deplacement',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _EmptySectionMessage(
              icon: Icons.visibility_outlined,
              title: 'Mode lecture seule',
              message:
                  'Le suivi actif depuis ce telephone est reserve a l administrateur.',
            ),
            const SizedBox(height: AppSpacing.sm),
            _SafeZoneFieldRow(
              icon: Icons.radio_button_checked_outlined,
              label: 'Rayon',
              value: zone.formattedRadius,
            ),
          ],
        ),
      );
    }

    final inZone = _isOutOfZone == false;
    final outZone = _isOutOfZone == true;
    final statusText = _isOutOfZone == null
        ? 'Non evalue'
        : (outZone ? 'Hors zone' : 'Dans la zone');
    final statusColor = _isOutOfZone == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : (outZone
            ? Theme.of(context).colorScheme.error
            : Colors.green.shade700);

    return SectionCard(
      title: 'Suivi de deplacement',
      action: _isTracking
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSamplingPosition)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.sensors_outlined,
                    size: 14,
                    color: Colors.green.shade700,
                  ),
                const SizedBox(width: 6),
                Text(
                  _isSamplingPosition ? 'Lecture...' : 'Suivi actif',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700,
                      ),
                ),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SafeZoneFieldRow(
            icon: Icons.place_outlined,
            label: 'Origine',
            value: zone.formattedOrigin,
          ),
          const SizedBox(height: 4),
          _SafeZoneFieldRow(
            icon: Icons.my_location_outlined,
            label: 'Position',
            value: (_currentLatitude == null || _currentLongitude == null)
                ? '--'
                : '${_currentLatitude!.toStringAsFixed(6)}, ${_currentLongitude!.toStringAsFixed(6)}',
          ),
          const SizedBox(height: 4),
          _SafeZoneFieldRow(
            icon: Icons.straighten_outlined,
            label: 'Distance',
            value: _formatMeters(_currentDistanceMeters),
          ),
          const SizedBox(height: 4),
          _SafeZoneFieldRow(
            icon: Icons.radio_button_checked_outlined,
            label: 'Rayon',
            value: zone.formattedRadius,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                outZone
                    ? Icons.warning_amber_outlined
                    : (inZone ? Icons.check_circle_outline : Icons.info_outline),
                size: 18,
                color: statusColor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Statut: $statusText',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: _isTracking ||
                        _isSamplingPosition ||
                        _isEditingSafeZone ||
                        _isSavingSafeZone ||
                        _isResolvingPosition
                    ? null
                    : _startTracking,
                icon: const Icon(Icons.play_arrow_outlined),
                label: const Text('Demarrer le suivi'),
              ),
              OutlinedButton.icon(
                onPressed: _isTracking ? _stopTracking : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Arreter le suivi'),
              ),
              TextButton.icon(
                onPressed: _isSamplingPosition ? null : _refreshTrackingSample,
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('Actualiser'),
              ),
            ],
          ),
          if (_trackingError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InlineErrorCard(message: _trackingError!),
          ],
          if (outZone) ...[
            const SizedBox(height: AppSpacing.sm),
            const _InlineInfoCard(
              message:
                  'Alerte envoyee lors du passage hors zone. Aucune repetition tant que la position reste hors zone.',
            ),
          ],
        ],
      ),
    );
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
                  _buildSafeZoneSection(),
                  const SizedBox(height: AppSpacing.md),
                  _buildTrackingSection(),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                    'Cette position est basee sur le telephone du membre '
                    'famille administrateur. Elle ne represente pas forcement '
                    'la localisation exacte du patient.',
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

class _SafeZoneSummary extends StatelessWidget {
  const _SafeZoneSummary({
    required this.safeZone,
    this.readOnlyMessage,
  });

  final PatientSafeZone safeZone;
  final String? readOnlyMessage;

  String _formatDateTime(DateTime? value) {
    if (value == null) return '--';
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/${value.year} $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SafeZoneFieldRow(
          icon: Icons.north_outlined,
          label: 'Latitude',
          value: safeZone.originLatitude.toStringAsFixed(6),
        ),
        const SizedBox(height: 4),
        _SafeZoneFieldRow(
          icon: Icons.east_outlined,
          label: 'Longitude',
          value: safeZone.originLongitude.toStringAsFixed(6),
        ),
        const SizedBox(height: 4),
        _SafeZoneFieldRow(
          icon: Icons.radio_button_checked_outlined,
          label: 'Rayon',
          value: safeZone.formattedRadius,
        ),
        const SizedBox(height: 4),
        _SafeZoneFieldRow(
          icon: Icons.access_time_outlined,
          label: 'Mise a jour',
          value: _formatDateTime(safeZone.updatedAt),
        ),
        if (readOnlyMessage != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _InlineInfoCard(message: readOnlyMessage!),
        ],
      ],
    );
  }
}

class _SafeZoneFieldRow extends StatelessWidget {
  const _SafeZoneFieldRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
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

class _InlineErrorCard extends StatelessWidget {
  const _InlineErrorCard({required this.message});

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
            Icon(
              Icons.error_outline,
              size: 18,
              color: colorScheme.error,
            ),
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
