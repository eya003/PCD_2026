import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'patient_model.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : 'HTTP $statusCode: $message';
}

class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
    : baseUrl = (baseUrl ?? _defaultBaseUrl()).replaceAll(RegExp(r'/$'), ''),
      _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  static String _defaultBaseUrl() {
    const envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }

    // Windows desktop + Web (same machine) -> localhost works.
    return kIsWeb ? 'http://127.0.0.1:8000' : 'http://127.0.0.1:8000';
  }

  Future<List<Patient>> getPatients() async {
    final response = await _httpClient.get(_uri('/patients/'));
    final data = _decodeJson(response);
    _throwIfError(response, data);

    if (data is! List) {
      throw ApiException('Unexpected response format for patients list');
    }

    return data
        .map((item) => Patient.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Patient?> searchPatient({
    required String firstName,
    required String lastName,
    required DateTime birthDate,
  }) async {
    final response = await _httpClient.get(
      _uri(
        '/patients/search',
        queryParameters: {
          'first_name': firstName,
          'last_name': lastName,
          'birth_date': _formatDate(birthDate),
        },
      ),
    );

    final data = _decodeJson(response);

    if (response.statusCode == 404) {
      return null;
    }

    _throwIfError(response, data);

    if (data is! Map<String, dynamic>) {
      throw ApiException('Unexpected response format for patient search');
    }

    return Patient.fromJson(data);
  }

  Uri _uri(String path, {Map<String, String>? queryParameters}) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }

  dynamic _decodeJson(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        'Invalid JSON response from server',
        statusCode: response.statusCode,
      );
    }
  }

  void _throwIfError(http.Response response, dynamic data) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final message = switch (data) {
      {'detail': final detail} => detail.toString(),
      _ => response.reasonPhrase ?? 'Request failed',
    };

    throw ApiException(message, statusCode: response.statusCode);
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
