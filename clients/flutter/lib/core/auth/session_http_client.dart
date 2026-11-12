import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api/api_failure.dart';
import 'session_controller.dart';
import 'session_models.dart';

class SessionHttpClient extends http.BaseClient {
  SessionHttpClient({
    required this.baseUri,
    required this.session,
    http.Client? inner,
  }) : _inner = inner ?? http.Client();

  static const _authPaths = {'/api/v1/auth/refresh', '/api/v1/auth/logout'};
  static const _replayableMethods = {'GET', 'HEAD', 'OPTIONS', 'DELETE'};
  static const _invalidTokenCodes = {
    'INVALID_TOKEN',
    'SESSION_REVOKED',
    'AUTH_REQUIRED',
  };

  final Uri baseUri;
  final SessionController session;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_isWorkbenchOrigin(request.url)) {
      return _inner.send(request);
    }

    final authRequest = _authPaths.contains(request.url.path);
    final usedToken = session.accessToken;
    final replayRequest = request is http.Request && _canReplay(request)
        ? _copy(request)
        : null;

    _authorize(request);
    final response = await _inner.send(request);
    if (response.statusCode != 401 || authRequest) {
      return response;
    }

    final bodyBytes = await response.stream.toBytes();
    final buffered = _buffered(response, bodyBytes);
    final errorCode = _errorCode(bodyBytes);
    final staleToken = usedToken != session.accessToken;

    if (errorCode == 'TOKEN_EXPIRED') {
      if (staleToken) {
        return _replay(replayRequest, buffered);
      }

      final result = await session.refreshSession();
      switch (result) {
        case SessionRefreshResult.refreshed:
          return _replay(replayRequest, buffered);
        case SessionRefreshResult.networkFailure:
          throw http.ClientException(
            'The session refresh failed because the network is unavailable.',
            request.url,
          );
        case SessionRefreshResult.signedOut:
        case SessionRefreshResult.unavailable:
          return buffered;
      }
    }

    if (_invalidTokenCodes.contains(errorCode)) {
      if (staleToken) {
        return _replay(replayRequest, buffered);
      }
      if (session.isRefreshing) {
        final result = await session.refreshSession();
        if (result == SessionRefreshResult.refreshed) {
          return _replay(replayRequest, buffered);
        }
        return buffered;
      }
      await session.invalidateSession();
    }

    return buffered;
  }

  @override
  void close() {
    _inner.close();
  }

  bool _isWorkbenchOrigin(Uri url) {
    return url.scheme == baseUri.scheme &&
        url.host == baseUri.host &&
        url.port == baseUri.port;
  }

  void _authorize(http.BaseRequest request) {
    final accessToken = session.accessToken;
    if (accessToken == null) {
      return;
    }
    request.headers['Authorization'] = 'Bearer $accessToken';
  }

  bool _canReplay(http.Request request) {
    if (_replayableMethods.contains(request.method.toUpperCase())) {
      return true;
    }
    return request.headers.keys.any(
      (name) => name.toLowerCase() == 'idempotency-key',
    );
  }

  http.Request _copy(http.Request request) {
    return http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
  }

  Future<http.StreamedResponse> _replay(
    http.Request? request,
    http.StreamedResponse fallback,
  ) {
    if (request == null || session.accessToken == null) {
      return Future.value(fallback);
    }
    _authorize(request);
    return _inner.send(request);
  }

  http.StreamedResponse _buffered(
    http.StreamedResponse response,
    List<int> bodyBytes,
  ) {
    return http.StreamedResponse(
      Stream<List<int>>.value(bodyBytes),
      response.statusCode,
      contentLength: bodyBytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  String? _errorCode(List<int> bodyBytes) {
    if (bodyBytes.isEmpty) {
      return null;
    }
    try {
      return apiFailureFromErrorBody(401, utf8.decode(bodyBytes)).code;
    } on FormatException {
      return null;
    } on AssertionError {
      return null;
    }
  }
}
