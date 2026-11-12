import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jlu_dela_api/api.dart';

import '../api/api_failure.dart';
import 'auth_gateway.dart';
import 'refresh_token_store.dart';
import 'session_models.dart';

class SessionController extends ChangeNotifier {
  SessionController._(this._gateway, this._refreshTokenStore);

  factory SessionController({
    required AuthGateway gateway,
    required RefreshTokenStore refreshTokenStore,
  }) {
    return SessionController._(gateway, refreshTokenStore);
  }

  static const remoteSignOutUnconfirmedMessage = '已从本机退出，但未能确认远端会话已撤销。';
  static const noRemoteSessionMessage = '当前没有可撤销的远端会话。';

  final AuthGateway _gateway;
  final RefreshTokenStore _refreshTokenStore;
  final List<void Function()> _privateCacheClearers = [];

  SessionPhase _phase = SessionPhase.restoring;
  Me? _currentUser;
  String? _accessToken;
  int _identityRevision = 0;
  int _sessionRevision = 0;
  int _signInSerial = 0;
  Future<void> _storeQueue = Future<void>.value();
  Future<SessionRefreshResult>? _refreshInFlight;
  int _refreshInFlightRevision = -1;
  Future<void>? _restoreInFlight;
  bool _disposed = false;

  SessionPhase get phase => _phase;

  Me? get currentUser => _currentUser;

  String? get accessToken => _accessToken;

  int get identityRevision => _identityRevision;

  int get sessionRevision => _sessionRevision;

  bool get isRefreshing =>
      _refreshInFlight != null && _refreshInFlightRevision == _sessionRevision;

  void registerPrivateCache(void Function() clear) {
    _privateCacheClearers.add(clear);
  }

  Future<void> restore() {
    return _restoreInFlight ??= _restore().whenComplete(() {
      _restoreInFlight = null;
    });
  }

  Future<void> retryRestore() {
    if (_phase != SessionPhase.unavailable) {
      return Future.value();
    }
    return restore();
  }

  Future<SignInOutcome> signIn(SessionCredentials credentials) async {
    final operation = ++_signInSerial;
    final revisionAtStart = _sessionRevision;
    final user = await _gateway.fetchMe(credentials.accessToken);

    final committed = await _serializeStore(() async {
      if (!_isOperationCurrent(operation, revisionAtStart)) {
        return false;
      }
      await _refreshTokenStore.write(credentials.refreshToken);
      if (!_isOperationCurrent(operation, revisionAtStart)) {
        await _clearStoredTokenIfEquals(credentials.refreshToken);
        return false;
      }

      _sessionRevision++;
      _accessToken = credentials.accessToken;
      _adoptUser(user);
      return true;
    });

    return committed ? SignInOutcome.signedIn : SignInOutcome.cancelled;
  }

  Future<SignOutResult> signOut() async {
    final accessToken = _accessToken;
    final revisionAfterBegin = _beginSignedOut();
    String? refreshToken;
    try {
      refreshToken = await _readStoredToken();
    } on Exception {
      refreshToken = null;
    }
    await _clearStoredToken(revisionAfterBegin);

    if (refreshToken == null || refreshToken.isEmpty) {
      return const SignOutResult(
        remoteRevoked: false,
        message: noRemoteSessionMessage,
      );
    }

    try {
      var currentAccessToken = accessToken;
      var currentRefreshToken = refreshToken;

      if (currentAccessToken == null) {
        final pair = await _gateway.refresh(currentRefreshToken);
        currentAccessToken = pair.accessToken;
        currentRefreshToken = pair.refreshToken;
      }

      try {
        await _gateway.revoke(
          accessToken: currentAccessToken,
          refreshToken: currentRefreshToken,
        );
        return const SignOutResult(remoteRevoked: true);
      } on ApiException catch (error) {
        final code = _apiErrorCode(error);
        if (_isRevokedCode(code)) {
          return const SignOutResult(remoteRevoked: true);
        }
        if (code != 'TOKEN_EXPIRED') {
          return const SignOutResult(
            remoteRevoked: false,
            message: remoteSignOutUnconfirmedMessage,
          );
        }

        final pair = await _gateway.refresh(currentRefreshToken);
        await _gateway.revoke(
          accessToken: pair.accessToken,
          refreshToken: pair.refreshToken,
        );
        return const SignOutResult(remoteRevoked: true);
      }
    } on ApiException catch (error) {
      if (_isRevokedCode(_apiErrorCode(error))) {
        return const SignOutResult(remoteRevoked: true);
      }
      return const SignOutResult(
        remoteRevoked: false,
        message: remoteSignOutUnconfirmedMessage,
      );
    } on Exception {
      return const SignOutResult(
        remoteRevoked: false,
        message: remoteSignOutUnconfirmedMessage,
      );
    }
  }

  Future<SessionRefreshResult> refreshSession() {
    final revision = _sessionRevision;
    final inFlight = _refreshInFlight;
    if (inFlight != null && _refreshInFlightRevision == revision) {
      return inFlight;
    }

    late final Future<SessionRefreshResult> future;
    future = _refresh(revision).whenComplete(() {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = future;
    _refreshInFlightRevision = revision;
    return future;
  }

  Future<void> invalidateSession() async {
    final revision = _beginSignedOut();
    await _clearStoredToken(revision);
  }

  Future<void> _restore() async {
    if (_phase != SessionPhase.restoring) {
      _phase = SessionPhase.restoring;
      _notify();
    }

    final revision = _sessionRevision;
    final result = await refreshSession();
    if (revision != _sessionRevision ||
        result != SessionRefreshResult.refreshed) {
      return;
    }

    final accessToken = _accessToken;
    if (accessToken == null) {
      await _enterSignedOut();
      return;
    }

    try {
      final user = await _gateway.fetchMe(accessToken);
      if (revision != _sessionRevision) {
        return;
      }
      _adoptUser(user);
    } on ApiException catch (error) {
      if (revision != _sessionRevision) {
        return;
      }
      if (error.code == 401) {
        await _enterSignedOut();
      } else {
        _setUnavailable();
      }
    } on Exception {
      if (revision != _sessionRevision) {
        return;
      }
      _setUnavailable();
    }
  }

  Future<SessionRefreshResult> _refresh(int revision) async {
    String? refreshToken;
    try {
      refreshToken = await _readStoredToken();
    } on Exception {
      if (revision != _sessionRevision) {
        return SessionRefreshResult.cancelled;
      }
      _setUnavailable();
      return SessionRefreshResult.unavailable;
    }

    if (refreshToken == null || refreshToken.isEmpty) {
      if (revision != _sessionRevision) {
        return SessionRefreshResult.cancelled;
      }
      await _enterSignedOut();
      return SessionRefreshResult.signedOut;
    }

    try {
      final pair = await _gateway.refresh(refreshToken);
      if (revision != _sessionRevision) {
        return SessionRefreshResult.cancelled;
      }

      final applied = await _serializeStore(() async {
        if (revision != _sessionRevision) {
          return false;
        }
        await _refreshTokenStore.write(pair.refreshToken);
        if (revision != _sessionRevision) {
          await _clearStoredTokenIfEquals(pair.refreshToken);
          return false;
        }

        _accessToken = pair.accessToken;
        if (_currentUser != null && _phase != SessionPhase.authenticated) {
          _phase = SessionPhase.authenticated;
        }
        _notify();
        return true;
      });
      return applied
          ? SessionRefreshResult.refreshed
          : SessionRefreshResult.cancelled;
    } on ApiException catch (error) {
      if (revision != _sessionRevision) {
        return SessionRefreshResult.cancelled;
      }
      if (error.code == 401) {
        await _enterSignedOut();
        return SessionRefreshResult.signedOut;
      }
      final failure = mapApiException(error);
      if (failure.kind == ApiFailureKind.network ||
          failure.kind == ApiFailureKind.timeout) {
        _setUnavailable();
        return SessionRefreshResult.networkFailure;
      }
      _setUnavailable();
      return SessionRefreshResult.unavailable;
    } on http.ClientException {
      if (revision != _sessionRevision) {
        return SessionRefreshResult.cancelled;
      }
      _setUnavailable();
      return SessionRefreshResult.networkFailure;
    } on SocketException {
      if (revision != _sessionRevision) {
        return SessionRefreshResult.cancelled;
      }
      _setUnavailable();
      return SessionRefreshResult.networkFailure;
    } on TimeoutException {
      if (revision != _sessionRevision) {
        return SessionRefreshResult.cancelled;
      }
      _setUnavailable();
      return SessionRefreshResult.networkFailure;
    } on Exception {
      if (revision != _sessionRevision) {
        return SessionRefreshResult.cancelled;
      }
      _setUnavailable();
      return SessionRefreshResult.unavailable;
    }
  }

  Future<void> _enterSignedOut() async {
    final revision = _beginSignedOut();
    await _clearStoredToken(revision);
  }

  int _beginSignedOut() {
    _sessionRevision++;
    _signInSerial++;
    final hadIdentity = _currentUser != null;
    _currentUser = null;
    _accessToken = null;
    _phase = SessionPhase.signedOut;
    if (hadIdentity) {
      _clearPrivateCaches();
      _identityRevision++;
    }
    _notify();
    return _sessionRevision;
  }

  Future<void> _clearStoredToken(int expectedRevision) {
    return _serializeStore(() async {
      if (_sessionRevision != expectedRevision) {
        return;
      }
      try {
        await _refreshTokenStore.clear();
      } on Exception {
        // The remote session is revoked separately; a local storage failure
        // must not keep the user signed in.
      }
    });
  }

  void _adoptUser(Me user) {
    final identityChanged = _currentUser?.id != user.id;
    _currentUser = user;
    _phase = SessionPhase.authenticated;
    if (identityChanged) {
      _clearPrivateCaches();
      _identityRevision++;
    }
    _notify();
  }

  void _setUnavailable() {
    _phase = SessionPhase.unavailable;
    _notify();
  }

  void _clearPrivateCaches() {
    for (final clear in List.of(_privateCacheClearers)) {
      clear();
    }
  }

  bool _isOperationCurrent(int operation, int revisionAtStart) {
    return !_disposed &&
        operation == _signInSerial &&
        revisionAtStart == _sessionRevision;
  }

  Future<String?> _readStoredToken() {
    return _serializeStore(() => _refreshTokenStore.read());
  }

  Future<void> _clearStoredTokenIfEquals(String token) async {
    try {
      if (await _refreshTokenStore.read() == token) {
        await _refreshTokenStore.clear();
      }
    } on Exception {
      // The session is already invalid; a storage failure must not revive it.
    }
  }

  Future<T> _serializeStore<T>(Future<T> Function() action) {
    final result = _storeQueue.then((_) => action());
    _storeQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  String? _apiErrorCode(ApiException error) {
    final body = error.message;
    if (body == null || body.isEmpty) {
      return null;
    }
    try {
      return apiFailureFromErrorBody(error.code, body).code;
    } on AssertionError {
      return null;
    }
  }

  bool _isRevokedCode(String? code) {
    return code == 'SESSION_REVOKED' ||
        code == 'INVALID_TOKEN' ||
        code == 'AUTH_REQUIRED';
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionRevision++;
    _signInSerial++;
    _privateCacheClearers.clear();
    super.dispose();
  }
}
