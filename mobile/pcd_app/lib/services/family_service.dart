import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/patient_summary.dart';
import '../models/status_type.dart';
import 'api_base_url.dart';

class FamilyException implements Exception {
  const FamilyException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class FamilyService {
  FamilyService({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = resolveApiBaseUrl(overrideBaseUrl: baseUrl).replaceAll(
        RegExp(r'/$'),
        '',
      );

  final http.Client _httpClient;
  final String _baseUrl;
  static const Duration _requestTimeout = Duration(seconds: 20);

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';

  /// Fetches the list of patients linked to the currently logged-in family user.
  /// Endpoint: GET /families/{userId}/patients
  Future<List<PatientSummary>> fetchLinkedPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getInt(_userIdKey);

    if (token == null || token.isEmpty || userId == null) {
      throw const FamilyException(
        'Session invalide. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }

    late http.Response response;
    try {
      response = await _httpClient
          .get(
            Uri.parse('$_baseUrl/families/$userId/patients'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_requestTimeout);
    } on http.ClientException {
      throw const FamilyException(
        'Erreur reseau. Verifiez votre connexion.',
      );
    } catch (_) {
      throw const FamilyException(
        'Erreur reseau. Verifiez votre connexion.',
      );
    }

    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        throw const FamilyException('Reponse serveur invalide.');
      }
    }

    if (response.statusCode == 401) {
      throw const FamilyException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw const FamilyException('Acces refuse.', statusCode: 403);
    }
    if (response.statusCode == 404) {
      // Family user not found — treat as empty list rather than hard error
      // so that a freshly-registered user doesn't see a crash screen.
      return [];
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = data is Map<String, dynamic>
          ? data['detail']?.toString()
          : null;
      throw FamilyException(
        detail ?? 'Impossible de charger les patients.',
        statusCode: response.statusCode,
      );
    }

    if (data is! List) return [];

    final patients = <PatientSummary>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      try {
        patients.add(_parsePatient(item));
      } catch (e) {
        debugPrint('FamilyService: skipping malformed patient item — $e');
      }
    }
    return patients;
  }

  PatientSummary _parsePatient(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final firstName = json['first_name']?.toString().trim() ?? '';
    final lastName = json['last_name']?.toString().trim() ?? '';
    final birthDateRaw = json['birth_date']?.toString();
    final birthDate =
        birthDateRaw == null ? null : DateTime.tryParse(birthDateRaw);
    final cin = json['cin']?.toString().trim().toUpperCase() ?? '';
    final code = json['patient_code']?.toString().trim();

    if (id == null ||
        birthDate == null ||
        firstName.isEmpty ||
        lastName.isEmpty ||
        cin.isEmpty) {
      throw const FamilyException('Donnees patient invalides recues du serveur.');
    }

    return PatientSummary(
      id: id,
      code: (code == null || code.isEmpty) ? 'P-$id' : code,
      firstName: firstName,
      lastName: lastName,
      cin: cin,
      birthDate: birthDate,
      // Status is not meaningful for family view — default to suivi.
      status: PatientStatus.suivi,
    );
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
