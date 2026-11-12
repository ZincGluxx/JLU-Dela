import '../models/source.dart';
import 'source.dart';

enum SourceAuthGroup { jluCampus, chaoxing }

enum SourceConnectionState { disconnected, connected }

SourceAuthGroup sourceAuthGroup(SourceKind source) {
  return switch (source) {
    SourceKind.jluIedu || SourceKind.jluOa => SourceAuthGroup.jluCampus,
    SourceKind.chaoxing => SourceAuthGroup.chaoxing,
  };
}

class SourceRequest {
  const SourceRequest({
    required this.uri,
    this.method = 'GET',
    this.headers = const {},
    this.body,
  });

  final Uri uri;
  final String method;
  final Map<String, String> headers;
  final String? body;
}

class SourceResponse {
  const SourceResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

abstract interface class SourceHttpClient {
  Future<SourceResponse> send(SourceRequest request);
}

class SourceSessionRegistry {
  final Map<SourceAuthGroup, Map<String, String>> _cookies = {};

  Map<String, String> cookiesFor(SourceKind source) {
    return cookiesForGroup(sourceAuthGroup(source));
  }

  Map<String, String> cookiesForGroup(SourceAuthGroup group) {
    return Map.unmodifiable(_cookies[group] ?? const <String, String>{});
  }

  bool hasSession(SourceKind source) => cookiesFor(source).isNotEmpty;

  bool hasGroupSession(SourceAuthGroup group) {
    return (_cookies[group] ?? const <String, String>{}).isNotEmpty;
  }

  SourceConnectionState stateFor(SourceKind source) {
    return hasSession(source)
        ? SourceConnectionState.connected
        : SourceConnectionState.disconnected;
  }

  void save(SourceAuthGroup group, Map<String, String> cookies) {
    if (cookies.isEmpty) {
      _cookies.remove(group);
      return;
    }
    _cookies[group] = Map.of(cookies);
  }

  void clearGroup(SourceAuthGroup group) {
    _cookies.remove(group);
  }

  void clearAll() {
    _cookies.clear();
  }
}

class UnavailableSourceHttpClient implements SourceHttpClient {
  const UnavailableSourceHttpClient({required this.sessions});

  final SourceSessionRegistry sessions;

  @override
  Future<SourceResponse> send(SourceRequest request) async {
    throw const SourceException(
      SourceFailure(
        code: SourceErrorCodes.sourceUnavailable,
        message: '来源网络客户端尚未接入',
      ),
    );
  }
}
