import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/patient_summary.dart';
import '../models/status_type.dart';
import 'api_base_url.dart';

class PatientsException implements Exception {
  const PatientsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PatientsService {
  PatientsService({http.Client? httpClient, String? baseUrl})
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

  Future<List<PatientSummary>> fetchPatients({
    String query = '',
    PatientStatus? status,
  }) async {
    final allPatients = await fetchDoctorPatients();
    final q = query.trim().toLowerCase();

    return allPatients.where((patient) {
      final matchesStatus = status == null || patient.status == status;
      if (!matchesStatus) {
        return false;
      }

      if (q.isEmpty) {
        return true;
      }

      return patient.code.toLowerCase().contains(q) ||
          patient.fullName.toLowerCase().contains(q) ||
          patient.cin.toLowerCase().contains(q) ||
          patient.age.toString().contains(q);
    }).toList();
  }

  Future<Map<int, int>> _fetchAppointmentCountMap(
    _SessionContext session,
  ) async {
    try {
      final endpoint = '/doctors/${session.userId}/appointments';
      final response = await _safeGet(
        endpoint,
        headers: {'Authorization': 'Bearer ${session.token}'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return {};
      }
      final data = _decodeJson(response);
      if (data is! List) return {};
      final countMap = <int, int>{};
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          final pid = item['patient_id'];
          if (pid is int) {
            countMap[pid] = (countMap[pid] ?? 0) + 1;
          }
        }
      }
      return countMap;
    } catch (_) {
      return {};
    }
  }

  Future<List<PatientSummary>> fetchDoctorPatients() async {
    final session = await _getSessionContext();
    const path = '/doctors/';
    final endpoint = '$path${session.userId}/patients';
    final patientsFuture = _safeGet(
      endpoint,
      headers: {'Authorization': 'Bearer ${session.token}'},
    );
    final countMapFuture = _fetchAppointmentCountMap(session);
    final response = await patientsFuture;
    final countMap = await countMapFuture;
    final data = _decodeJson(response);

    if (response.statusCode == 401) {
      throw const PatientsException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw const PatientsException(
        'Acces refuse. Ce compte n est pas autorise.',
        statusCode: 403,
      );
    }
    if (response.statusCode == 404) {
      throw const PatientsException('Medecin introuvable.', statusCode: 404);
    }
    if (response.statusCode >= 500) {
      throw PatientsException(
        _extractDetail(data) ??
            'Erreur serveur lors du chargement des patients.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PatientsException(
        _extractDetail(data) ?? 'Impossible de recuperer les patients.',
        statusCode: response.statusCode,
      );
    }

    if (data is! List) {
      throw const PatientsException('Format de reponse patients invalide.');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map((json) => _parsePatientSummary(json, countMap: countMap))
        .toList();
  }

  Future<int> fetchPatientCount() async {
    final patients = await fetchDoctorPatients();
    return patients.length;
  }

  Future<PatientSummary> createPatient({
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String cin,
  }) async {
    final normalizedFirstName = firstName.trim();
    final normalizedLastName = lastName.trim();
    final normalizedCin = cin.trim().toUpperCase();

    if (normalizedFirstName.isEmpty ||
        normalizedLastName.isEmpty ||
        normalizedCin.isEmpty) {
      throw const PatientsException('Tous les champs sont obligatoires.');
    }

    final session = await _getSessionContext();
    final response = await _safePost(
      '/patients/',
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: {
        'patient_code': _buildPatientCode(normalizedCin),
        'first_name': normalizedFirstName,
        'last_name': normalizedLastName,
        'birth_date': _formatDate(birthDate),
        'cin': normalizedCin,
      },
    );
    final data = _decodeJson(response);

    if (response.statusCode == 409) {
      final detail = _extractDetail(data);
      if (detail == 'Un patient avec ce CIN existe deja.') {
        throw const PatientsException(
          'Un patient avec ce CIN existe deja.',
          statusCode: 409,
        );
      }
      throw PatientsException(
        detail ?? 'Conflit lors de la creation du patient.',
        statusCode: 409,
      );
    }
    if (response.statusCode == 401) {
      throw const PatientsException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw const PatientsException(
        'Seul un medecin peut ajouter un patient.',
        statusCode: 403,
      );
    }
    if (response.statusCode == 422) {
      throw PatientsException(
        _extractDetail(data) ?? 'Validation invalide. Verifiez le formulaire.',
        statusCode: 422,
      );
    }
    if (response.statusCode >= 500) {
      throw PatientsException(
        _extractDetail(data) ??
            'Erreur serveur lors de la creation du patient.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PatientsException(
        _extractDetail(data) ?? 'Impossible de creer le patient.',
        statusCode: response.statusCode,
      );
    }

    if (data is! Map<String, dynamic>) {
      throw const PatientsException(
        'Format de reponse creation patient invalide.',
      );
    }
    return _parsePatientSummary(data);
  }

  Future<PatientSummary?> getPatientById(int id) async {
    final patients = await fetchDoctorPatients();
    for (final patient in patients) {
      if (patient.id == id) {
        return patient;
      }
    }
    return null;
  }

  PatientSummary _parsePatientSummary(
    Map<String, dynamic> json, {
    Map<int, int> countMap = const {},
  }) {
    final id = _parseInt(json['id']);
    final firstName = json['first_name']?.toString().trim() ?? '';
    final lastName = json['last_name']?.toString().trim() ?? '';
    final birthDateRaw = json['birth_date']?.toString();
    final birthDate = birthDateRaw == null
        ? null
        : DateTime.tryParse(birthDateRaw);
    final cin = json['cin']?.toString().trim().toUpperCase() ?? '';
    final code = json['patient_code']?.toString().trim();

    if (id == null ||
        birthDate == null ||
        firstName.isEmpty ||
        lastName.isEmpty ||
        cin.isEmpty) {
      throw const PatientsException(
        'Donnees patient invalides recues du serveur.',
      );
    }

    final apptCount = countMap[id] ?? 0;

    return PatientSummary(
      id: id,
      code: (code == null || code.isEmpty) ? 'P-$id' : code,
      firstName: firstName,
      lastName: lastName,
      cin: cin,
      birthDate: birthDate,
      status: _resolveStatus(apptCount),
    );
  }

  PatientStatus _resolveStatus(int appointmentCount) {
    return appointmentCount >= 2 ? PatientStatus.suivi : PatientStatus.nouveau;
  }

  Future<_SessionContext> _getSessionContext() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getInt(_userIdKey);
    if (token == null || token.isEmpty || userId == null) {
      throw const PatientsException(
        'Session invalide. Veuillez vous reconnecter.',
      );
    }
    return _SessionContext(token: token, userId: userId);
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<http.Response> _safeGet(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = _uri(path);
    _debugLogRequest('GET', uri, headers: headers);
    try {
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(_requestTimeout);
      _debugLogResponse('GET', uri, response);
      return response;
    } on TimeoutException catch (e) {
      _debugLogException('GET', uri, e);
      throw const PatientsException(
        'Delai depasse vers l API. Verifiez le serveur backend.',
      );
    } on http.ClientException catch (e) {
      _debugLogException('GET', uri, e);
      throw PatientsException('Connexion API impossible (${e.message}).');
    } catch (e) {
      _debugLogException('GET', uri, e);
      throw PatientsException('Erreur client lors de l appel API: $e');
    }
  }

  Future<http.Response> _safePost(
    String path, {
    Map<String, String>? headers,
    required Map<String, dynamic> body,
  }) async {
    final uri = _uri(path);
    _debugLogRequest('POST', uri, headers: headers, body: body);
    try {
      final response = await _httpClient
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout);
      _debugLogResponse('POST', uri, response);
      return response;
    } on TimeoutException catch (e) {
      _debugLogException('POST', uri, e);
      throw const PatientsException(
        'Delai depasse vers l API. Verifiez le serveur backend.',
      );
    } on http.ClientException catch (e) {
      _debugLogException('POST', uri, e);
      throw PatientsException('Connexion API impossible (${e.message}).');
    } catch (e) {
      _debugLogException('POST', uri, e);
      throw PatientsException('Erreur client lors de l appel API: $e');
    }
  }

  dynamic _decodeJson(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw PatientsException(
        'Reponse JSON invalide du serveur.',
        statusCode: response.statusCode,
      );
    }
  }

  void _debugLogRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) {
    if (!kDebugMode) return;
    debugPrint('[PatientsService] -> $method $uri');
    if (headers != null) {
      final masked = Map<String, String>.from(headers);
      if (masked.containsKey('Authorization')) {
        masked['Authorization'] = 'Bearer ***';
      }
      debugPrint('[PatientsService] headers: $masked');
    }
    if (body != null) {
      debugPrint('[PatientsService] body: $body');
    }
  }

  void _debugLogResponse(String method, Uri uri, http.Response response) {
    if (!kDebugMode) return;
    final preview = response.body.length > 800
        ? '${response.body.substring(0, 800)}...'
        : response.body;
    debugPrint('[PatientsService] <- $method $uri [${response.statusCode}]');
    if (response.statusCode >= 400) {
      debugPrint('[PatientsService] error body: $preview');
    }
  }

  void _debugLogException(String method, Uri uri, Object error) {
    if (!kDebugMode) return;
    debugPrint('[PatientsService] !! $method $uri error: $error');
  }

  String? _extractDetail(dynamic data) {
    if (data is Map<String, dynamic> && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) {
        return _translateBackendDetail(detail);
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map<String, dynamic> && first['msg'] != null) {
          return first['msg'].toString();
        }
      }
      return detail.toString();
    }
    return null;
  }

  String _translateBackendDetail(String detail) {
    switch (detail) {
      case 'Patient CIN already exists':
      case 'Patient code already exists':
      case 'Unable to create patient':
        return 'Un patient avec ce CIN existe deja.';
      case 'Only doctors can create patients':
        return 'Seul un medecin peut ajouter un patient.';
      case 'Missing bearer token':
      case 'Invalid or expired token':
      case 'User not found':
        return 'Session expiree. Veuillez vous reconnecter.';
      default:
        return detail;
    }
  }

  String _buildPatientCode(String cin) {
    final clean = cin.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final base = clean.isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : clean;
    final code = 'P$base';
    return code.length <= 50 ? code : code.substring(0, 50);
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class _SessionContext {
  const _SessionContext({required this.token, required this.userId});

  final String token;
  final int userId;
}
