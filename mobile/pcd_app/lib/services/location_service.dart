import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/patient_location.dart';
import 'api_base_url.dart';

class LocationException implements Exception {
  const LocationException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class LocationService {
  LocationService({http.Client? httpClient, String? baseUrl})
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

  /// Returns the most recent location recorded for [patientId], or null if none.
  /// Endpoint: GET /patients/{patient_id}/last-location
  Future<PatientLocation?> fetchLastLocation({required int patientId}) async {
    final token = await _getToken();
    final url = Uri.parse('$_baseUrl/patients/$patientId/last-location');
    debugPrint('LocationService → GET $url');

    late http.Response response;
    try {
      response = await _httpClient
          .get(url, headers: {'Authorization': 'Bearer $token'})
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const LocationException(
        'La requete a expire. Verifiez votre connexion.',
      );
    } on http.ClientException catch (e) {
      debugPrint('LocationService ✗ ClientException: $e');
      throw const LocationException('Erreur reseau. Verifiez votre connexion.');
    } catch (e) {
      debugPrint('LocationService ✗ Unexpected: $e');
      throw const LocationException('Erreur reseau. Verifiez votre connexion.');
    }

    debugPrint('LocationService ← ${response.statusCode} $url');

    if (response.statusCode == 404 || response.body.isEmpty) return null;

    if (response.statusCode == 401) {
      throw const LocationException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw const LocationException('Acces refuse.', statusCode: 403);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic data;
      try { data = jsonDecode(response.body); } catch (_) {}
      throw LocationException(
        _extractDetail(data) ??
            'Impossible de charger la localisation (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return PatientLocation.fromJson(data);
      }
    } on FormatException {
      throw const LocationException('Reponse serveur invalide (JSON mal forme).');
    } catch (e) {
      debugPrint('LocationService ✗ parse last-location: $e');
    }
    return null;
  }

  /// Returns the full location history for [patientId], sorted newest first.
  /// Endpoint: GET /patients/{patient_id}/locations
  Future<List<PatientLocation>> fetchLocationHistory({
    required int patientId,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$_baseUrl/patients/$patientId/locations');
    debugPrint('LocationService → GET $url');

    late http.Response response;
    try {
      response = await _httpClient
          .get(url, headers: {'Authorization': 'Bearer $token'})
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const LocationException(
        'La requete a expire. Verifiez votre connexion.',
      );
    } on http.ClientException catch (e) {
      debugPrint('LocationService ✗ ClientException: $e');
      throw const LocationException('Erreur reseau. Verifiez votre connexion.');
    } catch (e) {
      debugPrint('LocationService ✗ Unexpected: $e');
      throw const LocationException('Erreur reseau. Verifiez votre connexion.');
    }

    debugPrint('LocationService ← ${response.statusCode} $url');

    if (response.statusCode == 404 || response.body.isEmpty) return [];

    if (response.statusCode == 401) {
      throw const LocationException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw const LocationException('Acces refuse.', statusCode: 403);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic data;
      try { data = jsonDecode(response.body); } catch (_) {}
      throw LocationException(
        _extractDetail(data) ??
            "Impossible de charger l historique (HTTP ${response.statusCode}).",
        statusCode: response.statusCode,
      );
    }

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } on FormatException {
      throw const LocationException('Reponse serveur invalide (JSON mal forme).');
    }

    if (data is! List) return [];

    final locations = <PatientLocation>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      try {
        locations.add(PatientLocation.fromJson(item));
      } catch (e) {
        debugPrint('LocationService: item ignore (parse error) — $e');
      }
    }

    locations.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    debugPrint('LocationService ✓ ${locations.length} position(s) chargee(s).');
    return locations;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      throw const LocationException(
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
