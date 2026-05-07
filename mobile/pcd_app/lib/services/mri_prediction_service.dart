import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mri_prediction_result.dart';
import 'api_base_url.dart';

class MriPredictionException implements Exception {
  const MriPredictionException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MriPredictionService {
  MriPredictionService({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = resolveApiBaseUrl(
        overrideBaseUrl: baseUrl,
      ).replaceAll(RegExp(r'/$'), '');

  final http.Client _httpClient;
  final String _baseUrl;

  static const _tokenKey = 'auth_token';
  static const _requestTimeout = Duration(minutes: 5);

  Future<MriPredictionResult> predictMri({
    required int patientId,
    required String fileName,
    String? filePath,
    Uint8List? fileBytes,
  }) async {
    final normalizedName = fileName.trim();
    final normalizedPath = filePath?.trim();
    final hasBytes = fileBytes != null && fileBytes.isNotEmpty;

    if (patientId <= 0) {
      throw const MriPredictionException('Aucun patient selectionne.');
    }
    if (!_isValidNiftiFile(normalizedName)) {
      throw const MriPredictionException(
        'Format invalide. Utilisez un fichier .nii ou .nii.gz.',
      );
    }
    if (!hasBytes && (normalizedPath == null || normalizedPath.isEmpty)) {
      throw const MriPredictionException('Aucun fichier selectionne.');
    }

    final token = await _getToken();
    final uri = Uri.parse('$_baseUrl/ai/predict-mri');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['patient_id'] = patientId.toString();

    try {
      if (hasBytes) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'mri_file',
            fileBytes,
            filename: normalizedName,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'mri_file',
            normalizedPath!,
            filename: normalizedName,
          ),
        );
      }

      _debugLogRequest(uri, patientId, normalizedName);
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      _debugLogResponse(uri, response);

      final data = _decodeJson(response);
      _throwIfError(response, data);

      if (data is! Map<String, dynamic>) {
        throw const MriPredictionException('Format de reponse IA invalide.');
      }

      return MriPredictionResult.fromJson(data);
    } on TimeoutException {
      throw const MriPredictionException(
        'Delai depasse pendant l analyse IA. Verifiez le backend.',
      );
    } on MriPredictionException {
      rethrow;
    } on MriPredictionResultParseException catch (e) {
      throw MriPredictionException(e.message);
    } on http.ClientException catch (e) {
      throw MriPredictionException('Connexion API impossible (${e.message}).');
    } catch (e) {
      throw MriPredictionException('Erreur pendant la prediction IA: $e');
    }
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      throw const MriPredictionException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    return token;
  }

  dynamic _decodeJson(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw MriPredictionException(
        'Reponse JSON invalide du serveur.',
        statusCode: response.statusCode,
      );
    }
  }

  void _throwIfError(http.Response response, dynamic data) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }

    final detail = _extractDetail(data);
    if (statusCode == 401) {
      throw const MriPredictionException(
        'Session expiree. Veuillez vous reconnecter.',
        statusCode: 401,
      );
    }
    if (statusCode == 403) {
      throw const MriPredictionException(
        'Acces reserve au medecin.',
        statusCode: 403,
      );
    }
    if (statusCode == 404) {
      throw const MriPredictionException(
        'Patient introuvable.',
        statusCode: 404,
      );
    }
    if (statusCode == 422) {
      throw MriPredictionException(
        detail ?? 'Validation invalide. Verifiez le patient et le fichier IRM.',
        statusCode: 422,
      );
    }
    if (statusCode >= 500) {
      throw MriPredictionException(
        detail ?? 'Erreur backend ou pipeline IA.',
        statusCode: statusCode,
      );
    }

    throw MriPredictionException(
      detail ?? 'Prediction IA impossible.',
      statusCode: statusCode,
    );
  }

  String? _extractDetail(dynamic data) {
    if (data is Map<String, dynamic> && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) return _translateBackendDetail(detail);
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
      case 'Missing bearer token':
      case 'Invalid or expired token':
      case 'User not found':
        return 'Session expiree. Veuillez vous reconnecter.';
      case 'Only doctors can use MRI AI prediction':
      case 'Only doctors can access AI predictions':
        return 'Acces reserve au medecin.';
      case 'Patient not found':
        return 'Patient introuvable.';
      case 'Invalid MRI file extension. Use .nii or .nii.gz':
        return 'Format invalide. Utilisez un fichier .nii ou .nii.gz.';
      default:
        return detail;
    }
  }

  bool _isValidNiftiFile(String fileName) {
    final lowerName = fileName.toLowerCase();
    return lowerName.endsWith('.nii') || lowerName.endsWith('.nii.gz');
  }

  void _debugLogRequest(Uri uri, int patientId, String fileName) {
    if (!kDebugMode) return;
    debugPrint('[MriPredictionService] -> POST $uri');
    debugPrint('[MriPredictionService] patient_id: $patientId');
    debugPrint('[MriPredictionService] mri_file: $fileName');
  }

  void _debugLogResponse(Uri uri, http.Response response) {
    if (!kDebugMode) return;
    final preview = response.body.length > 800
        ? '${response.body.substring(0, 800)}...'
        : response.body;
    debugPrint('[MriPredictionService] <- POST $uri [${response.statusCode}]');
    if (response.statusCode >= 400) {
      debugPrint('[MriPredictionService] error body: $preview');
    }
  }
}
