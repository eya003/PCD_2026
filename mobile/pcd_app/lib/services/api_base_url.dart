import 'package:flutter/foundation.dart';

String resolveApiBaseUrl({String? overrideBaseUrl}) {
  final normalizedOverride = overrideBaseUrl?.trim() ?? '';
  if (normalizedOverride.isNotEmpty) {
    return normalizedOverride;
  }

  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (envUrl.isNotEmpty) {
    return envUrl;
  }

  if (kIsWeb) {
    final base = Uri.base;
    final host = base.host.trim();
    final isLocalWildcard = host == '0.0.0.0';
    if (host.isNotEmpty && !isLocalWildcard) {
      final scheme = base.scheme == 'https' ? 'https' : 'http';
      return '$scheme://$host:8000';
    }
  }

  return 'http://127.0.0.1:8000';
}
