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
  int _generation = 0;
  Future<SessionRefreshResult>? _refreshInFlight;
  Future<void>? _restoreInFlight;
  bool _disposed = false;

  SessionPhase get phase => _phase;

  Me? get currentUser => _currentUser;

  String? get accessToken => _accessToken;

  int get identityRevision => _identityRevision;

  bool get isRefreshing => _refreshInFlight != null;

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

  Future<void> signIn(SessionCredentials credentials) async {
    final user = await _gateway.fetchMe(credentials.accessToken);
    _generation++;
    await _refreshTokenStore.write(credentials.refreshToken);
    _accessToken = credentials.accessToken;
    _adoptUser(user);
  }

  Future<SignOutResult> signOut() async {
    final accessToken = _accessToken;
    String? refreshToken;
    try {
      refreshToken = await _refreshTokenStore.read();
    } on Exception {
      refreshToken = null;
    }

    await _enterSignedOut();

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
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<SessionRefreshResult> future;
    future = _refresh().whenComplete(() {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = future;
    return future;
  }

  Future<void> invalidateSession() => _enterSignedOut();

  Future<void> _restore() async {
    if (_phase != SessionPhase.restoring) {
      _phase = SessionPhase.restoring;
      _notify();
    }

    final generation = _generation;
    final result = await refreshSession();
    if (generation != _generation || result != SessionRefreshResult.refreshed) {
      return;
    }

    final accessToken = _accessToken;
    if (accessToken == null) {
      await _enterSignedOut();
      return;
    }

    try {
      final user = await _gateway.fetchMe(accessToken);
      if (generation != _generation) {
        return;
      }
      _adoptUser(user);
    } on ApiException catch (error) {
      if (generation != _generation) {
        return;
      }
      if (error.code == 401) {
        await _enterSignedOut();
      } else {
        _setUnavailable();
      }
    } on Exception {
      if (generation != _generation) {
        return;
      }
      _setUnavailable();
    }
  }

  Future<SessionRefreshResult> _refresh() async {
    final generation = _generation;
    String? refreshToken;
    try {
      refreshToken = await _refreshTokenStore.read();
    } on Exception {
      if (generation != _generation) {
        return SessionRefreshResult.unavailable;
      }
      _setUnavailable();
      return SessionRefreshResult.unavailable;
    }

    if (refreshToken == null || refreshToken.isEmpty) {
      await _enterSignedOut();
      return SessionRefreshResult.signedOut;
    }

    try {
      final pair = await _gateway.refresh(refreshToken);
      if (generation != _generation) {
        return SessionRefreshResult.unavailable;
      }

      await _refreshTokenStore.write(pair.refreshToken);
      if (generation != _generation) {
        try {
          if (await _refreshTokenStore.read() == pair.refreshToken) {
            await _refreshTokenStore.clear();
          }
        } on Exception {
          // The session was already signed out; do not keep the stale token.
        }
        return SessionRefreshResult.unavailable;
      }

      _accessToken = pair.accessToken;
      if (_currentUser != null && _phase != SessionPhase.authenticated) {
        _phase = SessionPhase.authenticated;
      }
      _notify();
      return SessionRefreshResult.refreshed;
    } on ApiException catch (error) {
      if (generation != _generation) {
        return SessionRefreshResult.unavailable;
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
      if (generation != _generation) {
        return SessionRefreshResult.unavailable;
      }
      _setUnavailable();
      return SessionRefreshResult.networkFailure;
    } on SocketException {
      if (generation != _generation) {
        return SessionRefreshResult.unavailable;
      }
      _setUnavailable();
      return SessionRefreshResult.networkFailure;
    } on TimeoutException {
      if (generation != _generation) {
        return SessionRefreshResult.unavailable;
      }
      _setUnavailable();
      return SessionRefreshResult.networkFailure;
    } on Exception {
      if (generation != _generation) {
        return SessionRefreshResult.unavailable;
      }
      _setUnavailable();
      return SessionRefreshResult.unavailable;
    }
  }

  Future<void> _enterSignedOut() async {
    _generation++;
    final hadIdentity = _currentUser != null;
    _currentUser = null;
    _accessToken = null;
    _phase = SessionPhase.signedOut;
    if (hadIdentity) {
      _clearPrivateCaches();
      _identityRevision++;
    }
    _notify();

    try {
      await _refreshTokenStore.clear();
    } on Exception {
      // The remote session is revoked separately; a local storage failure must
      // not keep the user signed in.
    }
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
    _privateCacheClearers.clear();
    super.dispose();
  }
}
