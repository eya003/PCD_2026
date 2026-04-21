import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/family_member.dart';
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

  /// Resolves the current family role ('admin' | 'viewer') for the logged user.
  ///
  /// The role is relation-based (family_patient.family_role), so this method
  /// derives it from the selected patient link, not from user profile fields.
  ///
  /// If [patientId] is null, the first linked patient is used.
  Future<String> fetchCurrentFamilyRole({int? patientId}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_userIdKey);
    if (userId == null) {
      throw const FamilyException(
        'Session invalide. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }

    int? effectivePatientId = patientId;
    if (effectivePatientId == null) {
      final patients = await fetchLinkedPatients();
      if (patients.isEmpty) return '';
      effectivePatientId = patients.first.id;
    }

    final members = await fetchFamilyMembers(patientId: effectivePatientId);
    for (final member in members) {
      if (member.userId == userId) {
        final role = member.familyRole.trim().toLowerCase();
        if (role == 'admin' || role == 'viewer') return role;
      }
    }
    return '';
  }

  /// Fetches the list of patients linked to the currently logged-in family user.
  ///
  /// Endpoint: GET /family/{userId}/patients
  /// (prefix is /family — singular — as mounted in backend/app/main.py)
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

    // ── CORRECTION BUG 1 ──────────────────────────────────────────────────
    // Le backend monte le router avec prefix="/family" (singulier).
    //   app.include_router(family.router, prefix="/family")
    // L'ancienne implémentation appelait /families/ (pluriel) → 404.
    final url = Uri.parse('$_baseUrl/family/$userId/patients');
    debugPrint('FamilyService → GET $url');

    late http.Response response;
    try {
      response = await _httpClient
          .get(url, headers: {'Authorization': 'Bearer $token'})
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const FamilyException(
        'La requete a expire. Verifiez votre connexion.',
      );
    } on http.ClientException catch (e) {
      debugPrint('FamilyService ✗ ClientException: $e');
      throw const FamilyException(
        'Erreur reseau. Verifiez votre connexion.',
      );
    } catch (e) {
      debugPrint('FamilyService ✗ Unexpected: $e');
      throw const FamilyException(
        'Erreur reseau. Verifiez votre connexion.',
      );
    }

    debugPrint('FamilyService ← ${response.statusCode} $url');

    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        throw const FamilyException('Reponse serveur invalide (JSON mal forme).');
      }
    }

    if (response.statusCode == 401) {
      throw const FamilyException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw const FamilyException(
        'Acces refuse. Ce compte n est pas autorise.',
        statusCode: 403,
      );
    }

    // ── CORRECTION BUG 2 ──────────────────────────────────────────────────
    // L'ancienne implémentation retournait [] silencieusement pour tout 404,
    // masquant ainsi l'erreur de routing (mauvaise URL → 404 → "aucun patient").
    // Maintenant : on distingue 404 "utilisateur introuvable" d'une vraie erreur.
    if (response.statusCode == 404) {
      final detail = _extractDetail(data);
      debugPrint('FamilyService ✗ 404 detail: $detail');
      // 404 sur la bonne URL = l'utilisateur famille n'existe pas côté backend.
      // C'est possible pour un compte fraîchement créé dont le lien n'est pas
      // encore propagé. On lève une exception explicite plutôt que de cacher.
      throw FamilyException(
        detail ?? 'Utilisateur famille introuvable (id=$userId).',
        statusCode: 404,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _extractDetail(data);
      debugPrint('FamilyService ✗ HTTP ${response.statusCode}: $detail');
      throw FamilyException(
        detail ?? 'Impossible de charger les patients (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (data is! List) {
      debugPrint('FamilyService ✗ reponse inattendue (pas une liste): $data');
      return [];
    }

    final patients = <PatientSummary>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      try {
        patients.add(_parsePatient(item));
      } catch (e) {
        debugPrint('FamilyService: item patient ignore (parse error) — $e');
      }
    }

    debugPrint('FamilyService ✓ ${patients.length} patient(s) charges.');
    return patients;
  }

  /// Fetches the list of family members linked to [patientId].
  ///
  /// Endpoint: GET /patients/{patient_id}/family-members
  Future<List<FamilyMember>> fetchFamilyMembers({
    required int patientId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      throw const FamilyException(
        'Session invalide. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }

    final url = Uri.parse('$_baseUrl/patients/$patientId/family-members');
    debugPrint('FamilyService → GET $url');

    late http.Response response;
    try {
      response = await _httpClient
          .get(url, headers: {'Authorization': 'Bearer $token'})
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const FamilyException(
        'La requete a expire. Verifiez votre connexion.',
      );
    } on http.ClientException catch (e) {
      debugPrint('FamilyService ✗ ClientException: $e');
      throw const FamilyException('Erreur reseau. Verifiez votre connexion.');
    } catch (e) {
      debugPrint('FamilyService ✗ Unexpected: $e');
      throw const FamilyException('Erreur reseau. Verifiez votre connexion.');
    }

    debugPrint('FamilyService ← ${response.statusCode} $url');

    if (response.statusCode == 401) {
      throw const FamilyException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 404) return [];
    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic data;
      try { data = jsonDecode(response.body); } catch (_) {}
      throw FamilyException(
        _extractDetail(data) ??
            'Impossible de charger les membres (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } on FormatException {
      throw const FamilyException('Reponse serveur invalide (JSON mal forme).');
    }
    if (data is! List) return [];

    final members = <FamilyMember>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      try {
        members.add(FamilyMember.fromJson(item));
      } catch (e) {
        debugPrint('FamilyService: membre ignore (parse error) — $e');
      }
    }

    // Admin first, then sort alphabetically.
    members.sort((a, b) {
      if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
      return a.fullName.compareTo(b.fullName);
    });

    debugPrint('FamilyService ✓ ${members.length} membre(s) charge(s).');
    return members;
  }

  /// Transfers the admin role to [newAdminUserId] for [patientId].
  ///
  /// Endpoint: POST /family/transfer-admin
  /// Body: { "patient_id": ..., "new_admin_user_id": ... }
  Future<void> transferAdmin({
    required int patientId,
    required int newAdminUserId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      throw const FamilyException(
        'Session invalide. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }

    final url = Uri.parse('$_baseUrl/family/transfer-admin');
    debugPrint('FamilyService → POST $url');

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
              'new_admin_user_id': newAdminUserId,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const FamilyException(
        'La requete a expire. Verifiez votre connexion.',
      );
    } on http.ClientException catch (e) {
      debugPrint('FamilyService ✗ ClientException: $e');
      throw const FamilyException('Erreur reseau. Verifiez votre connexion.');
    } catch (e) {
      debugPrint('FamilyService ✗ Unexpected: $e');
      throw const FamilyException('Erreur reseau. Verifiez votre connexion.');
    }

    debugPrint('FamilyService ← ${response.statusCode} $url');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint('FamilyService ✓ Transfert admin reussi.');
      return;
    }

    dynamic data;
    try { data = jsonDecode(response.body); } catch (_) {}
    final detail = _extractDetail(data);

    if (response.statusCode == 401) {
      throw const FamilyException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw FamilyException(
        detail ?? 'Seul l\'administrateur familial peut effectuer ce transfert.',
        statusCode: 403,
      );
    }
    throw FamilyException(
      detail ?? 'Impossible de transferer le role admin (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
    );
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
      throw const FamilyException(
        'Donnees patient invalides recues du serveur.',
      );
    }

    return PatientSummary(
      id: id,
      code: (code == null || code.isEmpty) ? 'P-$id' : code,
      firstName: firstName,
      lastName: lastName,
      cin: cin,
      birthDate: birthDate,
      status: PatientStatus.suivi,
    );
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

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
