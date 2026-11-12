import 'package:jlu_dela/core/auth/account_gateway.dart';
import 'package:jlu_dela/core/auth/auth_gateway.dart';
import 'package:jlu_dela/core/auth/refresh_token_store.dart';
import 'package:jlu_dela/core/auth/session_models.dart';
import 'package:jlu_dela_api/api.dart';

class MemoryRefreshTokenStore implements RefreshTokenStore {
  MemoryRefreshTokenStore([this.token]);

  String? token;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async {
    token = value;
    writeCount++;
  }

  @override
  Future<void> clear() async {
    token = null;
    clearCount++;
  }
}

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.onRefresh, this.onFetchMe, this.onRevoke});

  Future<TokenPair> Function(String refreshToken)? onRefresh;
  Future<Me> Function(String accessToken)? onFetchMe;
  Future<void> Function(String accessToken, String refreshToken)? onRevoke;

  int refreshCount = 0;
  int fetchMeCount = 0;
  int revokeCount = 0;

  @override
  Future<TokenPair> refresh(String refreshToken) {
    refreshCount++;
    final handler = onRefresh;
    if (handler == null) {
      throw UnimplementedError('Unexpected refresh call.');
    }
    return handler(refreshToken);
  }

  @override
  Future<Me> fetchMe(String accessToken) {
    fetchMeCount++;
    final handler = onFetchMe;
    if (handler == null) {
      throw UnimplementedError('Unexpected fetchMe call.');
    }
    return handler(accessToken);
  }

  @override
  Future<void> revoke({
    required String accessToken,
    required String refreshToken,
  }) {
    revokeCount++;
    final handler = onRevoke;
    if (handler == null) {
      throw UnimplementedError('Unexpected revoke call.');
    }
    return handler(accessToken, refreshToken);
  }
}

class FakeAccountGateway implements AccountGateway {
  FakeAccountGateway({this.onActivate, this.onLogin});

  Future<SessionCredentials> Function(String inviteToken, String password)?
  onActivate;
  Future<SessionCredentials> Function(String login, String password)? onLogin;

  int activateCount = 0;
  int loginCount = 0;
  String? lastInviteToken;
  String? lastLogin;
  String? lastPassword;

  @override
  Future<SessionCredentials> activate({
    required String inviteToken,
    required String password,
  }) {
    activateCount++;
    lastInviteToken = inviteToken;
    lastPassword = password;
    final handler = onActivate;
    if (handler == null) {
      throw UnimplementedError('Unexpected activate call.');
    }
    return handler(inviteToken, password);
  }

  @override
  Future<SessionCredentials> login({
    required String login,
    required String password,
  }) {
    loginCount++;
    lastLogin = login;
    lastPassword = password;
    final handler = onLogin;
    if (handler == null) {
      throw UnimplementedError('Unexpected login call.');
    }
    return handler(login, password);
  }
}

Me testUser({String id = 'user-a', String displayName = '测试用户'}) {
  return Me(id: id, displayName: displayName, timezone: 'Asia/Shanghai');
}

TokenPair testTokenPair({
  String accessToken = 'access-a',
  String refreshToken = 'refresh-a',
  int expiresIn = 900,
}) {
  return TokenPair(
    accessToken: accessToken,
    refreshToken: refreshToken,
    tokenType: TokenPairTokenTypeEnum.bearer,
    expiresIn: expiresIn,
  );
}

SessionCredentials testCredentials({
  String accessToken = 'access-a',
  String refreshToken = 'refresh-a',
  int expiresIn = 900,
}) {
  return SessionCredentials(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresIn: expiresIn,
  );
}
