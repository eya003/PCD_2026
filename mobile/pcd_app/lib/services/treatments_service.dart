import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medication.dart';
import '../models/medication_intake.dart';
import '../models/patient_allergy.dart';
import '../models/prescription.dart';
import '../models/user_role.dart';
import 'api_base_url.dart';

class TreatmentsException implements Exception {
  const TreatmentsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PatientTreatmentData {
  const PatientTreatmentData({
    required this.role,
    required this.activeMedications,
    required this.archivedMedications,
    required this.intakes,
    required this.prescriptions,
    required this.allergies,
    required this.doctorNamesById,
  });

  final UserRole role;
  final List<Medication> activeMedications;
  final List<Medication> archivedMedications;
  final List<MedicationIntake> intakes;
  final List<Prescription> prescriptions;
  final List<PatientAllergy> allergies;
  final Map<int, String> doctorNamesById;

  String? doctorNameFor(int doctorId) => doctorNamesById[doctorId];
}

class TreatmentsService {
  TreatmentsService({http.Client? httpClient, String? baseUrl})
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
  static const _roleKey = 'auth_role';

  Future<UserRole> getCurrentRole() async {
    final session = await _getSessionContext();
    return session.role;
  }

  // Retourne true si l'erreur N'EST PAS une erreur d'authentification (401).
  // Utilisé comme test dans catchError pour laisser passer les 401.
  static bool _isNonAuthError(Object e) =>
      !(e is TreatmentsException && e.statusCode == 401);

  Future<PatientTreatmentData> fetchPatientTreatmentData({
    required int patientId,
  }) async {
    final session = await _getSessionContext();
    final headers = {'Authorization': 'Bearer ${session.token}'};

    // Tous les appels sont lancés en parallèle.
    // Chaque appel est isolé : une erreur non-401 retourne une liste vide
    // plutôt que de faire échouer toute la fonction.
    final activeFuture = _fetchActiveMedications(
      patientId: patientId,
      headers: headers,
    ).catchError(
      (Object _) => <Medication>[],
      test: _isNonAuthError,
    );
    final completedFuture = _fetchCompletedMedications(
      patientId: patientId,
      headers: headers,
    ).catchError(
      (Object _) => <Medication>[],
      test: _isNonAuthError,
    );
    final allFuture = _fetchAllMedications(
      patientId: patientId,
      headers: headers,
    ).catchError(
      (Object _) => <Medication>[],
      test: _isNonAuthError,
    );
    final intakesFuture = _fetchMedicationIntakes(
      patientId: patientId,
      headers: headers,
    ).catchError(
      (Object _) => <MedicationIntake>[],
      test: _isNonAuthError,
    );
    final prescriptionsFuture = _fetchPrescriptions(
      patientId: patientId,
      headers: headers,
    ).catchError(
      (Object _) => <Prescription>[],
      test: _isNonAuthError,
    );
    final allergiesFuture = _fetchAllergies(
      patientId: patientId,
      headers: headers,
    ).catchError(
      (Object _) => <PatientAllergy>[],
      test: _isNonAuthError,
    );
    final doctorsFuture = _fetchPatientDoctors(
      patientId: patientId,
      headers: headers,
    ).catchError(
      (Object _) => <int, String>{},
      test: _isNonAuthError,
    );

    final activeApi = await activeFuture;
    final completedApi = await completedFuture;
    final allApi = await allFuture;
    final intakes = await intakesFuture;
    final prescriptions = await prescriptionsFuture;
    final allergies = await allergiesFuture;
    final doctorsById = await doctorsFuture;

    final byId = <int, Medication>{};
    for (final item in allApi) {
      byId[item.id] = item;
    }
    for (final item in activeApi) {
      byId[item.id] = item;
    }
    for (final item in completedApi) {
      byId[item.id] = item;
    }

    final merged = byId.values.toList();
    final active = merged.where((item) => item.isActive).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final archived = merged.where((item) => item.isArchived).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    prescriptions.sort(
      (a, b) => b.prescriptionDate.compareTo(a.prescriptionDate),
    );
    allergies.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    intakes.sort((a, b) => b.takenAt.compareTo(a.takenAt));

    return PatientTreatmentData(
      role: session.role,
      activeMedications: active,
      archivedMedications: archived,
      intakes: intakes,
      prescriptions: prescriptions,
      allergies: allergies,
      doctorNamesById: doctorsById,
    );
  }

  Future<T> _withRequestContext<T>(
    String label,
    Future<T> Function() request,
  ) async {
    try {
      return await request();
    } on TreatmentsException catch (e) {
      throw TreatmentsException(
        '$label -> ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  Future<Prescription> createPrescription({
    required int patientId,
    required DateTime prescriptionDate,
    String? notes,
  }) async {
    final session = await _getSessionContext();
    final response = await _safePost(
      '/prescriptions/',
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: {
        'patient_id': patientId,
        'prescription_date': _formatDate(prescriptionDate),
        'notes': _nullable(notes),
        'status': Prescription.statusActive,
      },
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de creer l ordonnance.',
    );

    if (data is! Map<String, dynamic>) {
      throw const TreatmentsException(
        'Format de reponse creation ordonnance invalide.',
      );
    }
    return Prescription.fromJson(data);
  }

  Future<Medication> createMedication({
    required int patientId,
    required int prescriptionId,
    required String name,
    required String dosage,
    String? form,
    required String quantity,
    required String frequency,
    required String period,
    required DateTime startDate,
    DateTime? endDate,
    String? instructions,
  }) async {
    final session = await _getSessionContext();
    final response = await _safePost(
      '/medications/',
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: {
        'prescription_id': prescriptionId,
        'patient_id': patientId,
        // backend fixe doctor_id depuis le token, mais on garde un fallback
        'doctor_id': session.userId,
        'name': name.trim(),
        'dosage': dosage.trim(),
        'form': _nullable(form),
        'quantity': quantity.trim(),
        'frequency': frequency.trim(),
        'period': period.trim(),
        'start_date': _formatDate(startDate),
        'end_date': endDate == null ? null : _formatDate(endDate),
        'instructions': _nullable(instructions),
        'status': Medication.statusActive,
      },
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de creer le medicament.',
    );

    if (data is! Map<String, dynamic>) {
      throw const TreatmentsException(
        'Format de reponse creation medicament invalide.',
      );
    }
    return Medication.fromJson(data);
  }

  Future<Medication> markMedicationCompleted(int medicationId) async {
    final session = await _getSessionContext();
    final response = await _safePatch(
      '/medications/$medicationId/complete',
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: const {},
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de marquer ce traitement termine.',
    );

    if (data is! Map<String, dynamic>) {
      throw const TreatmentsException(
        'Format de reponse marquer termine invalide.',
      );
    }
    return Medication.fromJson(data);
  }

  Future<Medication> cancelMedication(int medicationId) async {
    final session = await _getSessionContext();
    final response = await _safePatch(
      '/medications/$medicationId/cancel',
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: const {},
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible d annuler ce traitement.',
    );

    if (data is! Map<String, dynamic>) {
      throw const TreatmentsException(
        'Format de reponse annulation traitement invalide.',
      );
    }
    return Medication.fromJson(data);
  }

  Future<Prescription> updatePrescription({
    required int prescriptionId,
    String? status,
    String? notes,
    DateTime? prescriptionDate,
  }) async {
    final session = await _getSessionContext();
    final body = <String, dynamic>{};
    if (status != null) body['status'] = Prescription.normalizeStatus(status);
    if (notes != null) body['notes'] = notes.trim().isEmpty ? null : notes.trim();
    if (prescriptionDate != null) {
      body['prescription_date'] = _formatDate(prescriptionDate);
    }
    if (body.isEmpty) {
      throw const TreatmentsException('Aucun champ a mettre a jour.');
    }

    final response = await _safePatch(
      '/prescriptions/$prescriptionId',
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: body,
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de modifier l ordonnance.',
    );

    if (data is! Map<String, dynamic>) {
      throw const TreatmentsException(
        'Format de reponse modification ordonnance invalide.',
      );
    }
    return Prescription.fromJson(data);
  }

  Future<PrescriptionWithItemsResult> createPrescriptionWithMedications({
    required int patientId,
    required DateTime prescriptionDate,
    String? notes,
    required List<MedicationItemPayload> medications,
  }) async {
    final session = await _getSessionContext();
    final response = await _safePost(
      '/prescriptions/with-items',
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: {
        'patient_id': patientId,
        'prescription_date': _formatDate(prescriptionDate),
        'notes': _nullable(notes),
        'status': Prescription.statusActive,
        'medications': medications
            .map(
              (m) => {
                'name': m.name,
                'dosage': m.dosage,
                'form': _nullable(m.form),
                'quantity': _nullable(m.quantity),
                'frequency': m.frequency,
                'period': _nullable(m.period),
                'start_date': _formatDate(m.startDate),
                'end_date': m.endDate == null ? null : _formatDate(m.endDate!),
                'instructions': _nullable(m.instructions),
                'status': Medication.statusActive,
              },
            )
            .toList(),
      },
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de creer l ordonnance avec ses medicaments.',
    );

    if (data is! Map<String, dynamic>) {
      throw const TreatmentsException(
        'Format de reponse creation ordonnance invalide.',
      );
    }

    final prescriptionJson = data['prescription'];
    final medicationsJson = data['medications'];
    if (prescriptionJson is! Map<String, dynamic> || medicationsJson is! List) {
      throw const TreatmentsException(
        'Format de reponse with-items invalide.',
      );
    }

    return PrescriptionWithItemsResult(
      prescription: Prescription.fromJson(prescriptionJson),
      medications: medicationsJson
          .whereType<Map<String, dynamic>>()
          .map(Medication.fromJson)
          .toList(),
    );
  }

  Future<PatientAllergy> addAllergy({
    required int patientId,
    required String allergen,
    String? reaction,
    String severity = PatientAllergy.severityModerate,
    String? notes,
  }) async {
    final session = await _getSessionContext();
    final response = await _safePost(
      '/patients/$patientId/allergies',
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: {
        'allergen': allergen.trim(),
        'reaction': _nullable(reaction),
        'severity': PatientAllergy.normalizeSeverity(severity),
        'notes': _nullable(notes),
      },
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible d ajouter l allergie.',
    );

    if (data is! Map<String, dynamic>) {
      throw const TreatmentsException(
        'Format de reponse creation allergie invalide.',
      );
    }
    return PatientAllergy.fromJson(data);
  }

  Future<MedicationIntake> createMedicationIntake({
    required int medicationId,
    required String status,
    String? comment,
    DateTime? takenAt,
  }) async {
    final session = await _getSessionContext();
    final response = await _safePost(
      '/medication-intakes/',
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: {
        'medication_id': medicationId,
        'status': MedicationIntake.normalizeStatus(status),
        'taken_at': _formatDateTime(takenAt ?? DateTime.now()),
        'comment': _nullable(comment),
      },
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible d enregistrer la prise.',
    );

    if (data is! Map<String, dynamic>) {
      throw const TreatmentsException(
        'Format de reponse creation prise invalide.',
      );
    }
    return MedicationIntake.fromJson(data);
  }

  Future<List<Medication>> _fetchActiveMedications({
    required int patientId,
    required Map<String, String> headers,
  }) async {
    final response = await _safeGet(
      '/patients/$patientId/active-medications',
      headers: headers,
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de recuperer les traitements actifs.',
    );
    return _parseMedicationList(data);
  }

  Future<List<Medication>> _fetchCompletedMedications({
    required int patientId,
    required Map<String, String> headers,
  }) async {
    final response = await _safeGet(
      '/patients/$patientId/completed-medications',
      headers: headers,
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de recuperer les traitements termines.',
    );
    return _parseMedicationList(data);
  }

  Future<List<Medication>> _fetchAllMedications({
    required int patientId,
    required Map<String, String> headers,
  }) async {
    final response = await _safeGet(
      '/patients/$patientId/medications',
      headers: headers,
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de recuperer les medicaments.',
    );
    return _parseMedicationList(data);
  }

  Future<List<MedicationIntake>> _fetchMedicationIntakes({
    required int patientId,
    required Map<String, String> headers,
  }) async {
    final response = await _safeGet(
      '/patients/$patientId/medication-intakes',
      headers: headers,
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de recuperer les prises de medicaments.',
    );
    return _parseMedicationIntakeList(data);
  }

  Future<List<Prescription>> _fetchPrescriptions({
    required int patientId,
    required Map<String, String> headers,
  }) async {
    final response = await _safeGet(
      '/patients/$patientId/prescriptions',
      headers: headers,
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de recuperer les ordonnances.',
    );

    if (data is! List) {
      throw const TreatmentsException(
        'Format de reponse ordonnances invalide.',
      );
    }
    final result = <Prescription>[];
    for (final item in data.whereType<Map<String, dynamic>>()) {
      try {
        result.add(Prescription.fromJson(item));
      } catch (_) {
        // Item malformé ignoré.
      }
    }
    return result;
  }

  Future<List<PatientAllergy>> _fetchAllergies({
    required int patientId,
    required Map<String, String> headers,
  }) async {
    final response = await _safeGet(
      '/patients/$patientId/allergies',
      headers: headers,
    );
    final data = _decodeJson(response);

    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de recuperer les allergies.',
    );

    if (data is! List) {
      throw const TreatmentsException('Format de reponse allergies invalide.');
    }
    final result = <PatientAllergy>[];
    for (final item in data.whereType<Map<String, dynamic>>()) {
      try {
        result.add(PatientAllergy.fromJson(item));
      } catch (_) {
        // Item malformé ignoré.
      }
    }
    return result;
  }

  Future<Map<int, String>> _fetchPatientDoctors({
    required int patientId,
    required Map<String, String> headers,
  }) async {
    final response = await _safeGet(
      '/patients/$patientId/doctors',
      headers: headers,
    );
    final data = _decodeJson(response);

    if (response.statusCode == 404) {
      return const {};
    }
    _throwIfError(
      response,
      data,
      defaultMessage: 'Impossible de recuperer les medecins du patient.',
    );

    if (data is! List) {
      return const {};
    }

    final doctorsById = <int, String>{};
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final id = _parseInt(item['id']);
      if (id == null) {
        continue;
      }
      final firstName = item['first_name']?.toString().trim() ?? '';
      final lastName = item['last_name']?.toString().trim() ?? '';
      final fullName = '$firstName $lastName'.trim();
      doctorsById[id] = fullName.isEmpty ? 'Medecin #$id' : fullName;
    }
    return doctorsById;
  }

  List<Medication> _parseMedicationList(dynamic data) {
    if (data is! List) {
      throw const TreatmentsException(
        'Format de reponse medicaments invalide.',
      );
    }
    final result = <Medication>[];
    for (final item in data.whereType<Map<String, dynamic>>()) {
      try {
        result.add(Medication.fromJson(item));
      } catch (_) {
        // Item malformé ignoré — les autres restent visibles.
      }
    }
    return result;
  }

  List<MedicationIntake> _parseMedicationIntakeList(dynamic data) {
    if (data is! List) {
      throw const TreatmentsException(
        'Format de reponse prises medicaments invalide.',
      );
    }
    final result = <MedicationIntake>[];
    for (final item in data.whereType<Map<String, dynamic>>()) {
      try {
        result.add(MedicationIntake.fromJson(item));
      } catch (_) {
        // Item malformé ignoré — les autres restent visibles.
      }
    }
    return result;
  }

  Future<_SessionContext> _getSessionContext() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getInt(_userIdKey);
    final roleRaw = prefs.getString(_roleKey);

    final role = _parseRole(roleRaw);
    if (token == null || token.isEmpty || userId == null || role == null) {
      throw const TreatmentsException(
        'Session invalide. Veuillez vous reconnecter.',
      );
    }
    return _SessionContext(token: token, userId: userId, role: role);
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
      throw const TreatmentsException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw TreatmentsException(detail ?? 'Acces refuse.', statusCode: 403);
    }
    if (response.statusCode == 404) {
      throw TreatmentsException(
        detail ?? 'Ressource introuvable.',
        statusCode: 404,
      );
    }
    if (response.statusCode == 409) {
      throw TreatmentsException(detail ?? 'Conflit metier.', statusCode: 409);
    }
    if (response.statusCode == 422) {
      throw TreatmentsException(
        detail ?? 'Validation invalide. Verifiez les champs.',
        statusCode: 422,
      );
    }
    if (response.statusCode >= 500) {
      throw TreatmentsException(
        detail ?? 'Erreur serveur backend.',
        statusCode: response.statusCode,
      );
    }

    throw TreatmentsException(
      detail ?? defaultMessage,
      statusCode: response.statusCode,
    );
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
      throw const TreatmentsException(
        'Delai depasse vers l API. Verifiez le serveur backend.',
      );
    } on http.ClientException catch (e) {
      _debugLogException('GET', uri, e);
      throw TreatmentsException('Connexion API impossible (${e.message}).');
    } catch (e) {
      _debugLogException('GET', uri, e);
      throw TreatmentsException('Erreur client lors de l appel API: $e');
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
      throw const TreatmentsException(
        'Delai depasse vers l API. Verifiez le serveur backend.',
      );
    } on http.ClientException catch (e) {
      _debugLogException('POST', uri, e);
      throw TreatmentsException('Connexion API impossible (${e.message}).');
    } catch (e) {
      _debugLogException('POST', uri, e);
      throw TreatmentsException('Erreur client lors de l appel API: $e');
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
      throw const TreatmentsException(
        'Delai depasse vers l API. Verifiez le serveur backend.',
      );
    } on http.ClientException catch (e) {
      _debugLogException('PATCH', uri, e);
      throw TreatmentsException('Connexion API impossible (${e.message}).');
    } catch (e) {
      _debugLogException('PATCH', uri, e);
      throw TreatmentsException('Erreur client lors de l appel API: $e');
    }
  }

  dynamic _decodeJson(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw TreatmentsException(
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
    debugPrint('[TreatmentsService] -> $method $uri');
    if (headers != null) {
      final masked = Map<String, String>.from(headers);
      if (masked.containsKey('Authorization')) {
        masked['Authorization'] = 'Bearer ***';
      }
      debugPrint('[TreatmentsService] headers: $masked');
    }
    if (body != null) {
      debugPrint('[TreatmentsService] body: $body');
    }
  }

  void _debugLogResponse(String method, Uri uri, http.Response response) {
    if (!kDebugMode) return;
    final preview = response.body.length > 800
        ? '${response.body.substring(0, 800)}...'
        : response.body;
    debugPrint('[TreatmentsService] <- $method $uri [${response.statusCode}]');
    if (response.statusCode >= 400) {
      debugPrint('[TreatmentsService] error body: $preview');
    }
  }

  void _debugLogException(String method, Uri uri, Object error) {
    if (!kDebugMode) return;
    debugPrint('[TreatmentsService] !! $method $uri error: $error');
  }

  String _translateBackendDetail(String detail) {
    switch (detail) {
      case 'Only doctors can manage prescriptions':
      case 'Only doctors can manage medications':
      case 'Only doctors can add patient allergies':
      case 'Only the prescribing doctor can update this medication':
      case 'Only the prescribing doctor can complete this medication':
      case 'Only the prescribing doctor can cancel this medication':
        return 'Seul le medecin peut effectuer cette action.';
      case 'You are not allowed to access this patient':
      case 'Doctor is not linked to this patient':
      case 'Family user is not linked to this patient':
        return 'Acces refuse pour ce patient.';
      case 'Prescription not found':
        return 'Ordonnance introuvable.';
      case 'Medication not found':
        return 'Medicament introuvable.';
      case 'Patient not found':
        return 'Patient introuvable.';
      case 'Medication conflict':
        return 'Conflit: ce medicament existe deja ou les donnees sont invalides.';
      case 'Only family members can submit medication intake follow-up':
        return 'Seul un membre famille peut indiquer pris/manque.';
      case 'Invalid intake status. Expected \'taken\' or \'missed\'':
        return 'Statut de prise invalide. Utilisez pris ou manque.';
      default:
        return detail;
    }
  }

  UserRole? _parseRole(String? rawValue) {
    if (rawValue == null) return null;
    for (final role in UserRole.values) {
      if (role.name == rawValue) {
        return role;
      }
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateTime(DateTime value) {
    return value.toUtc().toIso8601String();
  }

  String? _nullable(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class _SessionContext {
  const _SessionContext({
    required this.token,
    required this.userId,
    required this.role,
  });

  final String token;
  final int userId;
  final UserRole role;
}

class MedicationItemPayload {
  const MedicationItemPayload({
    required this.name,
    required this.dosage,
    this.form,
    this.quantity,
    required this.frequency,
    this.period,
    required this.startDate,
    this.endDate,
    this.instructions,
  });

  final String name;
  final String dosage;
  final String? form;
  final String? quantity;
  final String frequency;
  final String? period;
  final DateTime startDate;
  final DateTime? endDate;
  final String? instructions;
}

class PrescriptionWithItemsResult {
  const PrescriptionWithItemsResult({
    required this.prescription,
    required this.medications,
  });

  final Prescription prescription;
  final List<Medication> medications;
}
