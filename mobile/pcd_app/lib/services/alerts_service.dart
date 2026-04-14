import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/patient_alert.dart';
import 'api_base_url.dart';

class AlertsException implements Exception {
  const AlertsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AlertsService {
  AlertsService({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = resolveApiBaseUrl(overrideBaseUrl: baseUrl).replaceAll(
        RegExp(r'/$'),
        '',
      );

  final http.Client _httpClient;
  final String _baseUrl;
  static const Duration _requestTimeout = Duration(seconds: 20);

  static const _tokenKey = 'auth_token';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetches all alerts linked to [patientId].
  /// Endpoint: GET /patients/{patient_id}/alerts
  Future<List<PatientAlert>> fetchPatientAlerts({
    required int patientId,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$_baseUrl/patients/$patientId/alerts');
    debugPrint('AlertsService → GET $url');

    late http.Response response;
    try {
      response = await _httpClient
          .get(url, headers: {'Authorization': 'Bearer $token'})
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const AlertsException(
        'La requete a expire. Verifiez votre connexion.',
      );
    } on http.ClientException catch (e) {
      debugPrint('AlertsService ✗ ClientException: $e');
      throw const AlertsException('Erreur reseau. Verifiez votre connexion.');
    } catch (e) {
      debugPrint('AlertsService ✗ Unexpected: $e');
      throw const AlertsException('Erreur reseau. Verifiez votre connexion.');
    }

    debugPrint('AlertsService ← ${response.statusCode} $url');

    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        throw const AlertsException('Reponse serveur invalide (JSON mal forme).');
      }
    }

    if (response.statusCode == 401) {
      throw const AlertsException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw AlertsException(
        _extractDetail(data) ?? 'Acces refuse.',
        statusCode: 403,
      );
    }
    if (response.statusCode == 404) {
      // No alerts yet for this patient — return empty list.
      return [];
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AlertsException(
        _extractDetail(data) ??
            'Impossible de charger les alertes (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (data is! List) return [];

    final alerts = <PatientAlert>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      try {
        alerts.add(PatientAlert.fromJson(item));
      } catch (e) {
        debugPrint('AlertsService: item ignore (parse error) — $e');
      }
    }

    alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    debugPrint('AlertsService ✓ ${alerts.length} alerte(s) chargee(s).');
    return alerts;
  }

  /// Creates a backend alert when safe-zone exit is detected.
  /// Endpoint: POST /alerts
  Future<void> createSafeZoneExitAlert({
    required int patientId,
    required double distanceMeters,
    required double radiusMeters,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$_baseUrl/alerts');
    debugPrint('AlertsService -> POST $url');

    final distanceLabel = distanceMeters.toStringAsFixed(0);
    final radiusLabel = radiusMeters.toStringAsFixed(0);

    late http.Response response;
    try {
      response = await _httpClient
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'patient_id': patientId,
              'type': 'geofence_exit',
              'message':
                  'Sortie de zone detectee ($distanceLabel m > $radiusLabel m).',
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const AlertsException(
        'La requete a expire. Verifiez votre connexion.',
      );
    } on http.ClientException catch (e) {
      debugPrint('AlertsService ✗ ClientException POST: $e');
      throw const AlertsException('Erreur reseau. Verifiez votre connexion.');
    } catch (e) {
      debugPrint('AlertsService ✗ Unexpected POST: $e');
      throw const AlertsException('Erreur reseau. Verifiez votre connexion.');
    }

    debugPrint('AlertsService <- ${response.statusCode} $url');

    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } catch (_) {}
    }

    if (response.statusCode == 401) {
      throw const AlertsException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw AlertsException(
        _extractDetail(data) ?? 'Acces refuse.',
        statusCode: 403,
      );
    }
    if (response.statusCode == 404) {
      throw const AlertsException('Patient introuvable.', statusCode: 404);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AlertsException(
        _extractDetail(data) ??
            'Impossible de creer l alerte (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
  }

  /// Marks the alert identified by [alertId] as read.
  /// Endpoint: PATCH /alerts/{alert_id}/read
  Future<void> markAlertRead({required int alertId}) async {
    final token = await _getToken();
    final url = Uri.parse('$_baseUrl/alerts/$alertId/read');
    debugPrint('AlertsService → PATCH $url');

    late http.Response response;
    try {
      response = await _httpClient
          .patch(url, headers: {'Authorization': 'Bearer $token'})
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const AlertsException(
        'La requete a expire. Verifiez votre connexion.',
      );
    } on http.ClientException catch (e) {
      debugPrint('AlertsService ✗ ClientException PATCH: $e');
      throw const AlertsException('Erreur reseau. Verifiez votre connexion.');
    } catch (e) {
      debugPrint('AlertsService ✗ Unexpected PATCH: $e');
      throw const AlertsException('Erreur reseau. Verifiez votre connexion.');
    }

    debugPrint('AlertsService ← ${response.statusCode} $url');

    if (response.statusCode == 401) {
      throw const AlertsException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 404) {
      throw const AlertsException('Alerte introuvable.', statusCode: 404);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic data;
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body);
        } catch (_) {}
      }
      throw AlertsException(
        _extractDetail(data) ??
            'Impossible de marquer l alerte comme lue (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      throw const AlertsException(
        'Session invalide. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    return token;
  }

  String? _extractDetail(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map<String, dynamic>) return first['msg']?.toString();
      }
    }
    return null;
  }
}
