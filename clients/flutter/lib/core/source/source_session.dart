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
    this.timeout = const Duration(seconds: 30),
  });

  final Uri uri;
  final String method;
  final Map<String, String> headers;
  final String? body;
  final Duration timeout;
}

class SourceResponse {
  const SourceResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
    this.finalUri,
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final Uri? finalUri;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

abstract interface class SourceHttpClient {
  Future<SourceResponse> send(SourceRequest request);
}

class SourceCookie {
  const SourceCookie({
    required this.name,
    required this.value,
    required this.domain,
    this.path = '/',
    this.secure = false,
    this.httpOnly = false,
    this.hostOnly = false,
    this.expiresAtUtc,
  });

  final String name;
  final String value;
  final String domain;
  final String path;
  final bool secure;
  final bool httpOnly;
  final bool hostOnly;
  final DateTime? expiresAtUtc;
}

class SourceSessionRegistry {
  SourceSessionRegistry({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Map<SourceAuthGroup, List<SourceCookie>> _cookies = {};
  final DateTime Function() _now;

  List<SourceCookie> cookiesForUri(SourceKind source, Uri uri) {
    final saved = _cookies[sourceAuthGroup(source)] ?? const <SourceCookie>[];
    return List.unmodifiable(saved.where((cookie) => _matches(cookie, uri)));
  }

  Map<String, String> cookieHeaderFor(SourceKind source, Uri uri) {
    final cookies = cookiesForUri(source, uri).toList()
      ..sort((left, right) => right.path.length.compareTo(left.path.length));
    final header = <String, String>{};
    for (final cookie in cookies) {
      header.putIfAbsent(cookie.name, () => cookie.value);
    }
    return header;
  }

  bool hasSession(SourceKind source) {
    final saved = _cookies[sourceAuthGroup(source)] ?? const <SourceCookie>[];
    return saved.any((cookie) => !_isExpired(cookie));
  }

  SourceConnectionState stateFor(SourceKind source) {
    return hasSession(source)
        ? SourceConnectionState.connected
        : SourceConnectionState.disconnected;
  }

  void save(SourceAuthGroup group, Iterable<SourceCookie> cookies) {
    final saved = cookies.toList();
    if (saved.isEmpty) {
      _cookies.remove(group);
      return;
    }
    _cookies[group] = saved;
  }

  void clearGroup(SourceAuthGroup group) {
    _cookies.remove(group);
  }

  void clearAll() {
    _cookies.clear();
  }

  bool _matches(SourceCookie cookie, Uri uri) {
    if (_isExpired(cookie)) {
      return false;
    }
    if (cookie.secure && uri.scheme != 'https') {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (host.isEmpty) {
      return false;
    }
    final domain = cookie.domain.startsWith('.')
        ? cookie.domain.substring(1).toLowerCase()
        : cookie.domain.toLowerCase();
    if (cookie.hostOnly) {
      if (host != domain) {
        return false;
      }
    } else if (host != domain && !host.endsWith('.$domain')) {
      return false;
    }
    final requestPath = uri.path.isEmpty ? '/' : uri.path;
    final cookiePath = cookie.path.isEmpty ? '/' : cookie.path;
    if (requestPath == cookiePath) {
      return true;
    }
    if (!requestPath.startsWith(cookiePath)) {
      return false;
    }
    return cookiePath.endsWith('/') || requestPath[cookiePath.length] == '/';
  }

  bool _isExpired(SourceCookie cookie) {
    final expiresAt = cookie.expiresAtUtc;
    return expiresAt != null && !expiresAt.toUtc().isAfter(_now().toUtc());
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
