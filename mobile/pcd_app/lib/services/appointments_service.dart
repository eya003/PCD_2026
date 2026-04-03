import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/appointment_item.dart';
import '../models/patient_summary.dart';
import 'api_base_url.dart';

class AppointmentsException implements Exception {
  const AppointmentsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AppointmentsService {
  AppointmentsService({http.Client? httpClient, String? baseUrl})
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

  Future<List<AppointmentItem>> fetchDoctorAppointments({
    Map<int, PatientSummary>? patientsById,
  }) async {
    final session = await _getSessionContext();
    final endpoint = '/doctors/${session.userId}/appointments';
    final response = await _safeGet(
      endpoint,
      headers: {'Authorization': 'Bearer ${session.token}'},
    );
    final data = _decodeJson(response);

    if (response.statusCode == 401) {
      throw const AppointmentsException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw AppointmentsException(
        _extractDetail(data) ??
            'Acces refuse. Seul le medecin peut gerer les rendez-vous.',
        statusCode: 403,
      );
    }
    if (response.statusCode == 404) {
      final detail = _extractDetail(data);
      if (detail == 'Not Found') {
        throw const AppointmentsException(
          'Route API introuvable: GET /doctors/{doctor_id}/appointments.',
          statusCode: 404,
        );
      }
      throw AppointmentsException(
        detail ?? 'Medecin introuvable.',
        statusCode: 404,
      );
    }
    if (response.statusCode >= 500) {
      throw AppointmentsException(
        _extractDetail(data) ??
            'Erreur serveur lors du chargement des rendez-vous.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppointmentsException(
        _extractDetail(data) ?? 'Impossible de recuperer les rendez-vous.',
        statusCode: response.statusCode,
      );
    }

    if (data is! List) {
      throw const AppointmentsException(
        'Format de reponse rendez-vous invalide.',
      );
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map((json) => _parseAppointmentItem(json, patientsById: patientsById))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<List<AppointmentItem>> fetchPatientAppointments({
    required int patientId,
    Map<int, PatientSummary>? patientsById,
  }) async {
    final session = await _getSessionContext();
    final endpoint = '/patients/$patientId/appointments';
    final response = await _safeGet(
      endpoint,
      headers: {'Authorization': 'Bearer ${session.token}'},
    );
    final data = _decodeJson(response);

    if (response.statusCode == 401) {
      throw const AppointmentsException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw AppointmentsException(
        _extractDetail(data) ?? 'Acces refuse a ce patient.',
        statusCode: 403,
      );
    }
    if (response.statusCode == 404) {
      throw AppointmentsException(
        _extractDetail(data) ?? 'Patient introuvable.',
        statusCode: 404,
      );
    }
    if (response.statusCode >= 500) {
      throw AppointmentsException(
        _extractDetail(data) ??
            'Erreur serveur lors du chargement des rendez-vous patient.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppointmentsException(
        _extractDetail(data) ??
            'Impossible de recuperer les rendez-vous du patient.',
        statusCode: response.statusCode,
      );
    }

    if (data is! List) {
      throw const AppointmentsException(
        'Format de reponse rendez-vous invalide.',
      );
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map((json) => _parseAppointmentItem(json, patientsById: patientsById))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<AppointmentItem> createAppointment({
    required int patientId,
    required DateTime appointmentDateTime,
    String? notes,
    String status = 'scheduled',
    Map<int, PatientSummary>? patientsById,
  }) async {
    final normalizedStatus = _normalizeOutgoingStatus(status);
    final session = await _getSessionContext();
    final response = await _safePost(
      '/appointments/',
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: {
        'patient_id': patientId,
        'doctor_id': session.userId,
        'appointment_date': appointmentDateTime.toIso8601String(),
        'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
        'status': normalizedStatus,
      },
    );
    final data = _decodeJson(response);

    if (response.statusCode == 404) {
      throw const AppointmentsException(
        'Patient ou medecin introuvable.',
        statusCode: 404,
      );
    }
    if (response.statusCode == 409) {
      throw AppointmentsException(
        _extractDetail(data) ?? 'Conflit lors de la creation du rendez-vous.',
        statusCode: 409,
      );
    }
    if (response.statusCode == 401) {
      throw const AppointmentsException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 422) {
      throw AppointmentsException(
        _extractDetail(data) ?? 'Validation invalide.',
        statusCode: 422,
      );
    }
    if (response.statusCode >= 500) {
      throw AppointmentsException(
        _extractDetail(data) ??
            'Erreur serveur lors de la creation du rendez-vous.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppointmentsException(
        _extractDetail(data) ?? 'Impossible de creer le rendez-vous.',
        statusCode: response.statusCode,
      );
    }

    if (data is! Map<String, dynamic>) {
      throw const AppointmentsException(
        'Format de reponse creation rendez-vous invalide.',
      );
    }
    return _parseAppointmentItem(data, patientsById: patientsById);
  }

  Future<AppointmentItem> updateAppointment({
    required int appointmentId,
    required int patientId,
    required DateTime appointmentDateTime,
    String? notes,
    String status = 'scheduled',
    Map<int, PatientSummary>? patientsById,
  }) async {
    final normalizedStatus = _normalizeOutgoingStatus(status);
    final session = await _getSessionContext();
    final response = await _safePut(
      '/appointments/$appointmentId',
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: {
        'patient_id': patientId,
        'doctor_id': session.userId,
        'appointment_date': appointmentDateTime.toIso8601String(),
        'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
        'status': normalizedStatus,
      },
    );
    final data = _decodeJson(response);

    if (response.statusCode == 404) {
      throw const AppointmentsException(
        'Rendez-vous introuvable.',
        statusCode: 404,
      );
    }
    if (response.statusCode == 409) {
      throw AppointmentsException(
        _extractDetail(data) ?? 'Conflit lors de la modification.',
        statusCode: 409,
      );
    }
    if (response.statusCode == 401) {
      throw const AppointmentsException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 422) {
      throw AppointmentsException(
        _extractDetail(data) ?? 'Validation invalide.',
        statusCode: 422,
      );
    }
    if (response.statusCode >= 500) {
      throw AppointmentsException(
        _extractDetail(data) ??
            'Erreur serveur lors de la modification du rendez-vous.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppointmentsException(
        _extractDetail(data) ?? 'Impossible de modifier le rendez-vous.',
        statusCode: response.statusCode,
      );
    }

    if (data is! Map<String, dynamic>) {
      throw const AppointmentsException(
        'Format de reponse modification rendez-vous invalide.',
      );
    }
    return _parseAppointmentItem(data, patientsById: patientsById);
  }

  Future<void> deleteAppointment(int appointmentId) async {
    final session = await _getSessionContext();
    final response = await _safeDelete(
      '/appointments/$appointmentId',
      headers: {'Authorization': 'Bearer ${session.token}'},
    );
    final data = _decodeJson(response);

    if (response.statusCode == 404) {
      throw const AppointmentsException(
        'Rendez-vous introuvable.',
        statusCode: 404,
      );
    }
    if (response.statusCode == 401) {
      throw const AppointmentsException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode >= 500) {
      throw AppointmentsException(
        _extractDetail(data) ??
            'Erreur serveur lors de la suppression du rendez-vous.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppointmentsException(
        _extractDetail(data) ?? 'Impossible de supprimer le rendez-vous.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<AppointmentItem> markAppointmentCompleted({
    required AppointmentItem appointment,
    Map<int, PatientSummary>? patientsById,
  }) async {
    final session = await _getSessionContext();
    final response = await _safePatch(
      '/appointments/${appointment.id}/complete',
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: const {},
    );
    final data = _decodeJson(response);

    if (response.statusCode == 404) {
      // Backward compatibility: if the dedicated endpoint is unavailable,
      // fallback to generic update with status completed.
      try {
        return await updateAppointment(
          appointmentId: appointment.id,
          patientId: appointment.patientId,
          appointmentDateTime: appointment.dateTime,
          notes: appointment.notes,
          status: AppointmentItem.statusDone,
          patientsById: patientsById,
        );
      } on AppointmentsException catch (e) {
        if (e.statusCode == 404) {
          throw const AppointmentsException(
            'Rendez-vous introuvable.',
            statusCode: 404,
          );
        }
        rethrow;
      }
    }
    if (response.statusCode == 403) {
      throw const AppointmentsException(
        'Acces refuse. Seul le medecin peut marquer un rendez-vous termine.',
        statusCode: 403,
      );
    }
    if (response.statusCode == 401) {
      throw const AppointmentsException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode >= 500) {
      throw AppointmentsException(
        _extractDetail(data) ??
            'Erreur serveur lors de la mise a jour du statut du rendez-vous.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppointmentsException(
        _extractDetail(data) ?? 'Impossible de marquer le rendez-vous termine.',
        statusCode: response.statusCode,
      );
    }

    if (data is! Map<String, dynamic>) {
      throw const AppointmentsException(
        'Format de reponse invalid pour marquer termine.',
      );
    }
    return _parseAppointmentItem(data, patientsById: patientsById);
  }

  AppointmentItem _parseAppointmentItem(
    Map<String, dynamic> json, {
    Map<int, PatientSummary>? patientsById,
  }) {
    final id = _parseInt(json['id']);
    final patientId = _parseInt(json['patient_id']);
    final appointmentDateRaw = json['appointment_date']?.toString();
    final appointmentDate = appointmentDateRaw == null
        ? null
        : DateTime.tryParse(appointmentDateRaw);
    final status = json['status']?.toString() ?? 'scheduled';
    final notes = json['notes']?.toString();

    if (id == null || patientId == null || appointmentDate == null) {
      throw const AppointmentsException(
        'Donnees rendez-vous invalides recues du serveur.',
      );
    }

    final patient = patientsById?[patientId];
    final firstName = patient?.firstName ?? '';
    final lastName = patient?.lastName ?? '';
    final fallbackFirstName = 'Patient';
    final fallbackLastName = '#$patientId';

    return AppointmentItem(
      id: id,
      patientId: patientId,
      patientFirstName: firstName.isEmpty ? fallbackFirstName : firstName,
      patientLastName: lastName.isEmpty ? fallbackLastName : lastName,
      dateTime: appointmentDate.toLocal(),
      status: AppointmentItem.normalizeStatus(status),
      notes: notes,
    );
  }

  String _normalizeOutgoingStatus(String raw) {
    return AppointmentItem.normalizeStatus(raw);
  }

  Future<_SessionContext> _getSessionContext() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getInt(_userIdKey);
    if (token == null || token.isEmpty || userId == null) {
      throw const AppointmentsException(
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
      throw const AppointmentsException(
        'Delai depasse vers l API. Verifiez le serveur backend.',
      );
    } on http.ClientException catch (e) {
      _debugLogException('GET', uri, e);
      throw AppointmentsException('Connexion API impossible (${e.message}).');
    } catch (e) {
      _debugLogException('GET', uri, e);
      throw AppointmentsException('Erreur client lors de l appel API: $e');
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
      throw const AppointmentsException(
        'Delai depasse vers l API. Verifiez le serveur backend.',
      );
    } on http.ClientException catch (e) {
      _debugLogException('POST', uri, e);
      throw AppointmentsException('Connexion API impossible (${e.message}).');
    } catch (e) {
      _debugLogException('POST', uri, e);
      throw AppointmentsException('Erreur client lors de l appel API: $e');
    }
  }

  Future<http.Response> _safePut(
    String path, {
    Map<String, String>? headers,
    required Map<String, dynamic> body,
  }) async {
    final uri = _uri(path);
    _debugLogRequest('PUT', uri, headers: headers, body: body);
    try {
      final response = await _httpClient
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout);
      _debugLogResponse('PUT', uri, response);
      return response;
    } on TimeoutException catch (e) {
      _debugLogException('PUT', uri, e);
      throw const AppointmentsException(
        'Delai depasse vers l API. Verifiez le serveur backend.',
      );
    } on http.ClientException catch (e) {
      _debugLogException('PUT', uri, e);
      throw AppointmentsException('Connexion API impossible (${e.message}).');
    } catch (e) {
      _debugLogException('PUT', uri, e);
      throw AppointmentsException('Erreur client lors de l appel API: $e');
    }
  }

  Future<http.Response> _safeDelete(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = _uri(path);
    _debugLogRequest('DELETE', uri, headers: headers);
    try {
      final response = await _httpClient
          .delete(uri, headers: headers)
          .timeout(_requestTimeout);
      _debugLogResponse('DELETE', uri, response);
      return response;
    } on TimeoutException catch (e) {
      _debugLogException('DELETE', uri, e);
      throw const AppointmentsException(
        'Delai depasse vers l API. Verifiez le serveur backend.',
      );
    } on http.ClientException catch (e) {
      _debugLogException('DELETE', uri, e);
      throw AppointmentsException('Connexion API impossible (${e.message}).');
    } catch (e) {
      _debugLogException('DELETE', uri, e);
      throw AppointmentsException('Erreur client lors de l appel API: $e');
    }
  }

  Future<http.Response> _safePatch(
    String path, {
    Map<String, String>? headers,
    required Map<String, dynamic> body,
  }) async {
    final uri = _uri(path);
    _debugLogRequest('PATCH', uri, headers: headers, body: body);
    try {
      final response = await _httpClient
          .patch(uri, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout);
      _debugLogResponse('PATCH', uri, response);
      return response;
    } on TimeoutException catch (e) {
      _debugLogException('PATCH', uri, e);
      throw const AppointmentsException(
        'Delai depasse vers l API. Verifiez le serveur backend.',
      );
    } on http.ClientException catch (e) {
      _debugLogException('PATCH', uri, e);
      throw AppointmentsException('Connexion API impossible (${e.message}).');
    } catch (e) {
      _debugLogException('PATCH', uri, e);
      throw AppointmentsException('Erreur client lors de l appel API: $e');
    }
  }

  dynamic _decodeJson(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw AppointmentsException(
        'Reponse JSON invalide du serveur.',
        statusCode: response.statusCode,
      );
    }
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

  void _debugLogRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) {
    if (!kDebugMode) return;
    debugPrint('[AppointmentsService] -> $method $uri');
    if (headers != null) {
      final masked = Map<String, String>.from(headers);
      if (masked.containsKey('Authorization')) {
        masked['Authorization'] = 'Bearer ***';
      }
      debugPrint('[AppointmentsService] headers: $masked');
    }
    if (body != null) {
      debugPrint('[AppointmentsService] body: $body');
    }
  }

  void _debugLogResponse(String method, Uri uri, http.Response response) {
    if (!kDebugMode) return;
    final preview = response.body.length > 800
        ? '${response.body.substring(0, 800)}...'
        : response.body;
    debugPrint(
      '[AppointmentsService] <- $method $uri [${response.statusCode}]',
    );
    if (response.statusCode >= 400) {
      debugPrint('[AppointmentsService] error body: $preview');
    }
  }

  void _debugLogException(String method, Uri uri, Object error) {
    if (!kDebugMode) return;
    debugPrint('[AppointmentsService] !! $method $uri error: $error');
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _translateBackendDetail(String detail) {
    switch (detail) {
      case 'Not allowed':
        return 'Acces refuse. Seul le medecin peut gerer les rendez-vous.';
      case 'Doctor user not found':
        return 'Medecin introuvable.';
      case 'Doctor is not linked to this patient':
        return 'Ce patient n est pas lie a ce medecin.';
      case 'You are not allowed to access this patient':
        return 'Acces refuse a ce patient.';
      case "Invalid appointment status. Expected 'scheduled', 'done', 'cancelled' or 'missed'":
        return 'Statut invalide. Utilisez planifie, termine, annule ou manque.';
      default:
        return detail;
    }
  }
}

class _SessionContext {
  const _SessionContext({required this.token, required this.userId});

  final String token;
  final int userId;
}
