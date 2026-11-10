abstract final class AppConfig {
  static const String appName = 'JLU Dela';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  static Uri resolveApiBaseUri([String raw = apiBaseUrl]) {
    final trimmed = raw.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(trimmed);
    final validScheme =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final validPath = uri != null && (uri.path.isEmpty || uri.path == '/');

    if (uri == null ||
        !validScheme ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !validPath) {
      throw FormatException(
        'API_BASE_URL must be an absolute http(s) origin without a path, '
        'for example http://127.0.0.1:8080. Received: $raw',
      );
    }

    return uri;
  }
}
