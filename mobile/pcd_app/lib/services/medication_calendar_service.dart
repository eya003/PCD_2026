import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medication_calendar.dart';
import 'api_base_url.dart';

class MedicationCalendarException implements Exception {
  const MedicationCalendarException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MedicationCalendarService {
  MedicationCalendarService({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = resolveApiBaseUrl(
        overrideBaseUrl: baseUrl,
      ).replaceAll(RegExp(r'/$'), '');

  final http.Client _httpClient;
  final String _baseUrl;

  static const Duration _requestTimeout = Duration(seconds: 20);
  static const _tokenKey = 'auth_token';

  Future<MedicationDayPlanning> fetchTodayPlanning({
    required int patientId,
    DateTime? planningDate,
  }) async {
    final token = await _getToken();
    final query = <String, String>{};
    if (planningDate != null) {
      query['planning_date'] = _formatDate(planningDate);
    }
    final response = await _safeGet(
      '/medication-calendar/patients/$patientId/planning/today',
      headers: {'Authorization': 'Bearer $token'},
      queryParameters: query,
    );
    final data = _decodeJson(response);
    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de charger le planning du jour.',
    );

    if (data is! Map<String, dynamic>) {
      throw const MedicationCalendarException(
        'Format de reponse planning du jour invalide.',
      );
    }
    return MedicationDayPlanning.fromJson(data);
  }

  Future<MedicationDateRangePlanning> fetchRangePlanning({
    required int patientId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final token = await _getToken();
    final response = await _safeGet(
      '/medication-calendar/patients/$patientId/planning',
      headers: {'Authorization': 'Bearer $token'},
      queryParameters: {
        'start_date': _formatDate(startDate),
        'end_date': _formatDate(endDate),
      },
    );
    final data = _decodeJson(response);
    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de charger le planning sur intervalle.',
    );

    if (data is! Map<String, dynamic>) {
      throw const MedicationCalendarException(
        'Format de reponse planning intervalle invalide.',
      );
    }
    return MedicationDateRangePlanning.fromJson(data);
  }

  Future<List<ScheduledMedicationDose>> fetchMedicationScheduledDoses({
    required int medicationId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final token = await _getToken();
    final query = <String, String>{};
    if (startDate != null) {
      query['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      query['end_date'] = _formatDate(endDate);
    }

    final response = await _safeGet(
      '/medication-calendar/medications/$medicationId/scheduled-doses',
      headers: {'Authorization': 'Bearer $token'},
      queryParameters: query,
    );
    final data = _decodeJson(response);
    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de charger les doses planifiees.',
    );

    if (data is! List) {
      throw const MedicationCalendarException(
        'Format de reponse doses planifiees invalide.',
      );
    }

    final doses = <ScheduledMedicationDose>[];
    for (final item in data.whereType<Map<String, dynamic>>()) {
      try {
        doses.add(ScheduledMedicationDose.fromJson(item));
      } catch (_) {
        // Ignore malformed entries to keep UI usable.
      }
    }
    return doses;
  }

  Future<ScheduledMedicationDose> fetchScheduledDoseDetail({
    required int doseId,
  }) async {
    final token = await _getToken();
    final response = await _safeGet(
      '/medication-calendar/scheduled-doses/$doseId',
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _decodeJson(response);
    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de charger le detail de la dose.',
    );

    if (data is! Map<String, dynamic>) {
      throw const MedicationCalendarException(
        'Format de reponse detail dose invalide.',
      );
    }
    return ScheduledMedicationDose.fromJson(data);
  }

  Future<ScheduledDoseActionResult> takeScheduledDose({
    required int doseId,
    ScheduledDoseTakeActionPayload payload =
        const ScheduledDoseTakeActionPayload(),
  }) {
    return _postDoseAction(
      doseId: doseId,
      action: 'take',
      payload: payload.toJson(),
      defaultMessage: 'Impossible de marquer la dose comme prise.',
    );
  }

  Future<ScheduledDoseActionResult> missScheduledDose({
    required int doseId,
    ScheduledDoseMissActionPayload payload =
        const ScheduledDoseMissActionPayload(),
  }) {
    return _postDoseAction(
      doseId: doseId,
      action: 'miss',
      payload: payload.toJson(),
      defaultMessage: 'Impossible de marquer la dose comme manquee.',
    );
  }

  Future<ScheduledDoseActionResult> skipScheduledDose({
    required int doseId,
    required ScheduledDoseSkipActionPayload payload,
  }) {
    return _postDoseAction(
      doseId: doseId,
      action: 'skip',
      payload: payload.toJson(),
      defaultMessage: 'Impossible de marquer la dose comme sautee.',
    );
  }

  Future<ScheduledDoseActionResult> rescheduleScheduledDose({
    required int doseId,
    required ScheduledDoseRescheduleActionPayload payload,
  }) {
    return _postDoseAction(
      doseId: doseId,
      action: 'reschedule',
      payload: payload.toJson(),
      defaultMessage: 'Impossible de replanifier la dose.',
    );
  }

  Future<ScheduledDoseActionResult> cancelScheduledDose({
    required int doseId,
    ScheduledDoseCancelActionPayload payload =
        const ScheduledDoseCancelActionPayload(),
  }) {
    return _postDoseAction(
      doseId: doseId,
      action: 'cancel',
      payload: payload.toJson(),
      defaultMessage: 'Impossible d annuler la dose.',
    );
  }

  Future<MedicationScheduleTemplate> fetchPatientScheduleTemplate({
    required int patientId,
  }) async {
    final token = await _getToken();
    final response = await _safeGet(
      '/medication-calendar/patients/$patientId/schedule-template',
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _decodeJson(response);
    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de charger le template de planning.',
    );

    if (data is! Map<String, dynamic>) {
      throw const MedicationCalendarException(
        'Format de reponse template planning invalide.',
      );
    }
    return MedicationScheduleTemplate.fromJson(data);
  }

  Future<MedicationScheduleTemplate> updatePatientScheduleTemplate({
    required int patientId,
    required MedicationScheduleTemplateUpdate payload,
  }) async {
    final token = await _getToken();
    final response = await _safePut(
      '/medication-calendar/patients/$patientId/schedule-template',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: payload.toJson(),
    );
    final data = _decodeJson(response);
    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de mettre a jour le template de planning.',
    );

    if (data is! Map<String, dynamic>) {
      throw const MedicationCalendarException(
        'Format de reponse mise a jour template invalide.',
      );
    }
    return MedicationScheduleTemplate.fromJson(data);
  }

  Future<ScheduledDoseActionResult> _postDoseAction({
    required int doseId,
    required String action,
    required Map<String, dynamic> payload,
    required String defaultMessage,
  }) async {
    final token = await _getToken();
    final response = await _safePost(
      '/medication-calendar/scheduled-doses/$doseId/$action',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: payload,
    );
    final data = _decodeJson(response);
    _throwIfError(response, data, defaultMessage: defaultMessage);

    if (data is! Map<String, dynamic>) {
      throw const MedicationCalendarException(
        'Format de reponse action dose invalide.',
      );
    }
    return ScheduledDoseActionResult.fromJson(data);
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.trim().isEmpty) {
      throw const MedicationCalendarException(
        'Session invalide. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    return token;
  }

  Uri _uri(String path, {Map<String, String>? queryParameters}) {
    final base = Uri.parse('$_baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) {
      return base;
    }
    return base.replace(queryParameters: queryParameters);
  }

  Future<http.Response> _safeGet(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) async {
    final uri = _uri(path, queryParameters: queryParameters);
    _debugLogRequest('GET', uri, headers: headers);
    try {
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(_requestTimeout);
      _debugLogResponse('GET', uri, response);
      return response;
    } on TimeoutException catch (e) {
      _debugLogException('GET', uri, e);
      throw const MedicationCalendarException(
        'Delai depasse vers l API. Verifiez le backend.',
      );
    } on http.ClientException catch (e) {
      _debugLogException('GET', uri, e);
      throw MedicationCalendarException(
        'Connexion API impossible (${e.message}).',
      );
    } catch (e) {
      _debugLogException('GET', uri, e);
      throw MedicationCalendarException('Erreur client API: $e');
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
      throw const MedicationCalendarException(
        'Delai depasse vers l API. Verifiez le backend.',
      );
    } on http.ClientException catch (e) {
      _debugLogException('POST', uri, e);
      throw MedicationCalendarException(
        'Connexion API impossible (${e.message}).',
      );
    } catch (e) {
      _debugLogException('POST', uri, e);
      throw MedicationCalendarException('Erreur client API: $e');
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
      throw const MedicationCalendarException(
        'Delai depasse vers l API. Verifiez le backend.',
      );
    } on http.ClientException catch (e) {
      _debugLogException('PUT', uri, e);
      throw MedicationCalendarException(
        'Connexion API impossible (${e.message}).',
      );
    } catch (e) {
      _debugLogException('PUT', uri, e);
      throw MedicationCalendarException('Erreur client API: $e');
    }
  }

  dynamic _decodeJson(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw MedicationCalendarException(
        'Reponse JSON invalide du serveur.',
        statusCode: response.statusCode,
      );
    }
  }

  void _throwIfError(
    http.Response response,
    dynamic data, {
    required String defaultMessage,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final detail = _extractDetail(data);

    if (response.statusCode == 401) {
      throw const MedicationCalendarException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw MedicationCalendarException(
        detail ?? 'Acces refuse.',
        statusCode: 403,
      );
    }
    if (response.statusCode == 404) {
      throw MedicationCalendarException(
        detail ?? 'Ressource introuvable.',
        statusCode: 404,
      );
    }
    if (response.statusCode == 409) {
      throw MedicationCalendarException(
        detail ?? 'Conflit metier.',
        statusCode: 409,
      );
    }
    if (response.statusCode == 422) {
      throw MedicationCalendarException(
        detail ?? 'Validation invalide.',
        statusCode: 422,
      );
    }
    if (response.statusCode >= 500) {
      throw MedicationCalendarException(
        detail ?? 'Erreur serveur backend.',
        statusCode: response.statusCode,
      );
    }

    throw MedicationCalendarException(
      detail ?? defaultMessage,
      statusCode: response.statusCode,
    );
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
      case 'You are not allowed to access this patient':
        return 'Acces refuse pour ce patient.';
      case 'Only family admins can validate or adjust planned doses':
        return 'Seul un membre famille admin peut agir sur les doses.';
      case 'Family user is not linked to this patient':
        return 'Le membre famille n est pas lie a ce patient.';
      case 'Doctor is not linked to this patient':
        return 'Ce medecin n est pas lie a ce patient.';
      case 'Scheduled dose not found':
        return 'Dose planifiee introuvable.';
      case 'Medication not found':
        return 'Medicament introuvable.';
      default:
        return detail;
    }
  }

  String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _debugLogRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) {
    if (!kDebugMode) return;
    debugPrint('[MedicationCalendarService] -> $method $uri');
    if (headers != null) {
      final masked = Map<String, String>.from(headers);
      if (masked.containsKey('Authorization')) {
        masked['Authorization'] = 'Bearer ***';
      }
      debugPrint('[MedicationCalendarService] headers: $masked');
    }
    if (body != null) {
      debugPrint('[MedicationCalendarService] body: $body');
    }
  }

  void _debugLogResponse(String method, Uri uri, http.Response response) {
    if (!kDebugMode) return;
    final preview = response.body.length > 800
        ? '${response.body.substring(0, 800)}...'
        : response.body;
    debugPrint(
      '[MedicationCalendarService] <- $method $uri [${response.statusCode}]',
    );
    if (response.statusCode >= 400) {
      debugPrint('[MedicationCalendarService] error body: $preview');
    }
  }

  void _debugLogException(String method, Uri uri, Object error) {
    if (!kDebugMode) return;
    debugPrint('[MedicationCalendarService] !! $method $uri error: $error');
  }
}
