import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.role,
    required this.userId,
    required this.cin,
    required this.email,
    required this.firstName,
    required this.lastName,
  });

  final String token;
  final UserRole role;
  final int userId;
  final String cin;
  final String email;
  final String firstName;
  final String lastName;
}

class AuthService {
  AuthService({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = (baseUrl ?? _defaultBaseUrl()).replaceAll(RegExp(r'/$'), '');

  final http.Client _httpClient;
  final String _baseUrl;

  static const _tokenKey = 'auth_token';
  static const _roleKey = 'auth_role';
  static const _userIdKey = 'auth_user_id';
  static const _cinKey = 'auth_cin';
  static const _emailKey = 'auth_email';
  static const _firstNameKey = 'auth_first_name';
  static const _lastNameKey = 'auth_last_name';

  String get baseUrl => _baseUrl;

  static String _defaultBaseUrl() {
    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return kIsWeb ? 'http://localhost:8000' : 'http://127.0.0.1:8000';
  }

  Future<AuthSession?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final roleName = prefs.getString(_roleKey);
    final userId = prefs.getInt(_userIdKey);
    if (token == null || roleName == null || userId == null) {
      return null;
    }

    final role = _parseRoleOrNull(roleName);
    if (role == null) {
      await clearSession();
      return null;
    }

    return AuthSession(
      token: token,
      role: role,
      userId: userId,
      cin: prefs.getString(_cinKey) ?? '',
      email: prefs.getString(_emailKey) ?? '',
      firstName: prefs.getString(_firstNameKey) ?? '',
      lastName: prefs.getString(_lastNameKey) ?? '',
    );
  }

  Future<AuthSession> login(String cin, String password) async {
    final response = await _safePost(
      '/auth/login',
      body: {'cin': cin.trim(), 'password': password},
    );
    final data = _decodeJson(response);

    if (response.statusCode == 404) {
      throw const AuthException(
        'Aucun compte trouve avec ce CIN.',
        statusCode: 404,
      );
    }
    if (response.statusCode == 401) {
      throw const AuthException(
        'CIN ou mot de passe incorrect.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 422) {
      throw AuthException(
        _extractDetail(data) ?? 'Veuillez remplir tous les champs obligatoires.',
        statusCode: 422,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        _extractDetail(data) ?? 'Erreur de connexion au serveur.',
        statusCode: response.statusCode,
      );
    }

    if (data is! Map<String, dynamic>) {
      throw const AuthException('Reponse login invalide.');
    }

    final session = _parseSessionFromAuthPayload(data, fallbackCin: cin.trim());
    await _saveSession(session);
    return session;
  }

  Future<AuthSession> register({
    required String firstName,
    required String lastName,
    required String cin,
    required String email,
    required String password,
    required UserRole role,
    String? familyRole,
    String? patientCin,
  }) async {
    final endpoint = role == UserRole.doctor
        ? '/auth/register-doctor'
        : '/auth/register-family';

    final body = <String, dynamic>{
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'cin': cin.trim(),
      'email': email.trim(),
      'password': password,
    };

    if (role == UserRole.family) {
      if ((familyRole ?? '').trim().isEmpty || (patientCin ?? '').trim().isEmpty) {
        throw const AuthException('Les champs famille sont obligatoires.');
      }
      body.addAll({
        'family_role': familyRole!.trim(),
        'patient_cin': patientCin!.trim(),
        // Compatibility with backend variants that still require this field.
        'relation_to_patient': 'unspecified',
      });
    }

    final response = await _safePost(endpoint, body: body);
    final data = _decodeJson(response);

    if (response.statusCode == 409) {
      final detail = _extractDetail(data);
      if (detail == 'Un administrateur existe deja pour ce patient.') {
        throw const AuthException(
          'Un administrateur existe deja pour ce patient.',
          statusCode: 409,
        );
      }
      throw const AuthException(
        'Un compte avec ce CIN ou cet email existe deja.',
        statusCode: 409,
      );
    }
    if (response.statusCode == 404) {
      throw const AuthException(
        'Patient introuvable pour ce patient_cin.',
        statusCode: 404,
      );
    }
    if (response.statusCode == 422) {
      throw AuthException(
        _extractDetail(data) ?? 'Veuillez remplir tous les champs obligatoires.',
        statusCode: 422,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        _extractDetail(data) ?? 'Impossible de creer le compte.',
        statusCode: response.statusCode,
      );
    }

    // If backend returns token directly, consume it, otherwise auto-login.
    if (data is Map<String, dynamic> && data['access_token'] != null) {
      final session = _parseSessionFromAuthPayload(data, fallbackCin: cin.trim());
      await _saveSession(session);
      return session;
    }

    return login(cin, password);
  }

  Future<Map<String, dynamic>> getMe(String token) async {
    final response = await _safeGet(
      '/auth/me',
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300 || data is! Map<String, dynamic>) {
      throw AuthException(
        _extractDetail(data) ?? 'Impossible de recuperer le profil.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_cinKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_firstNameKey);
    await prefs.remove(_lastNameKey);
  }

  Future<void> _saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await prefs.setString(_roleKey, session.role.name);
    await prefs.setInt(_userIdKey, session.userId);
    await prefs.setString(_cinKey, session.cin);
    await prefs.setString(_emailKey, session.email);
    await prefs.setString(_firstNameKey, session.firstName);
    await prefs.setString(_lastNameKey, session.lastName);
  }

  AuthSession _parseSessionFromAuthPayload(
    Map<String, dynamic> data, {
    required String fallbackCin,
  }) {
    final token = data['access_token']?.toString();
    final userId = _parseInt(data['user_id']);
    final user = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final role = _parseRoleOrNull(data['role']?.toString() ?? user['role']?.toString());
    final effectiveUserId = userId ?? _parseInt(user['id']);
    final cin = user['cin']?.toString() ?? fallbackCin;
    final email = user['email']?.toString() ?? '';
    final firstName = user['first_name']?.toString() ?? '';
    final lastName = user['last_name']?.toString() ?? '';

    if (
        token == null ||
        token.isEmpty ||
        role == null ||
        effectiveUserId == null ||
        cin.isEmpty
    ) {
      throw const AuthException('Reponse login incomplete.');
    }

    return AuthSession(
      token: token,
      role: role,
      userId: effectiveUserId,
      cin: cin,
      email: email,
      firstName: firstName,
      lastName: lastName,
    );
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<http.Response> _safePost(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    try {
      return await _httpClient.post(
        _uri(path),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } on http.ClientException {
      throw const AuthException('Erreur reseau. Verifiez votre connexion.');
    } catch (_) {
      throw const AuthException('Erreur reseau. Verifiez votre connexion.');
    }
  }

  Future<http.Response> _safeGet(
    String path, {
    Map<String, String>? headers,
  }) async {
    try {
      return await _httpClient.get(_uri(path), headers: headers);
    } on http.ClientException {
      throw const AuthException('Erreur reseau. Verifiez votre connexion.');
    } catch (_) {
      throw const AuthException('Erreur reseau. Verifiez votre connexion.');
    }
  }

  dynamic _decodeJson(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw AuthException(
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
        return 'Veuillez verifier les champs obligatoires.';
      }
      return detail.toString();
    }
    return null;
  }

  String _translateBackendDetail(String detail) {
    switch (detail) {
      case 'User not found':
      case 'User not found with this CIN':
        return 'Aucun compte trouve avec ce CIN.';
      case 'Invalid email or password':
      case 'Invalid CIN or password':
        return 'CIN ou mot de passe incorrect.';
      case 'Email already exists':
      case 'CIN already exists':
        return 'Un compte avec ce CIN ou cet email existe deja.';
      case 'Patient not found':
      case 'Patient not found for the provided patient_cin':
        return 'Patient introuvable pour ce patient_cin.';
      case 'An admin already exists for this patient':
        return 'Un administrateur existe deja pour ce patient.';
      default:
        return detail;
    }
  }

  UserRole? _parseRoleOrNull(String? value) {
    if (value == null) return null;
    for (final role in UserRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
