import 'package:http/http.dart' as http;
import 'package:jlu_dela_api/api.dart';

import '../api/api_failure.dart';
import 'session_models.dart';

abstract interface class AccountGateway {
  Future<SessionCredentials> activate({
    required String inviteToken,
    required String password,
  });

  Future<SessionCredentials> login({
    required String login,
    required String password,
  });
}

class HttpAccountGateway implements AccountGateway {
  HttpAccountGateway({required this.baseUri, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final Uri baseUri;
  final http.Client _httpClient;

  ApiClient get _apiClient =>
      ApiClient(basePath: baseUri.toString())..client = _httpClient;

  @override
  Future<SessionCredentials> activate({
    required String inviteToken,
    required String password,
  }) async {
    final response = await _send(
      () => AuthApi(_apiClient).activateAccountWithHttpInfo(
        ActivateRequest(inviteToken: inviteToken, password: password),
      ),
    );
    return _credentialsFrom(response);
  }

  @override
  Future<SessionCredentials> login({
    required String login,
    required String password,
  }) async {
    final response = await _send(
      () => AuthApi(_apiClient).loginAccountWithHttpInfo(
        LoginRequest(login: login, password: password),
      ),
    );
    return _credentialsFrom(response);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on ApiException catch (error) {
      throw mapApiException(error);
    }
  }

  Future<SessionCredentials> _credentialsFrom(http.Response response) async {
    if (response.statusCode >= 400) {
      throw apiFailureFromErrorBody(
        response.statusCode,
        response.body,
        retryAfter: _retryAfter(response),
      );
    }

    final decoded = await _apiClient.deserializeAsync(
      response.body,
      'TokenPairResponse',
    );
    final pair = decoded is TokenPairResponse ? decoded.data : null;
    if (pair == null) {
      throw const FormatException('The auth response has no token pair.');
    }
    return SessionCredentials(
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      expiresIn: pair.expiresIn,
    );
  }

  Duration? _retryAfter(http.Response response) {
    if (response.statusCode != 429) {
      return null;
    }
    String? header;
    for (final entry in response.headers.entries) {
      if (entry.key.toLowerCase() == 'retry-after') {
        header = entry.value;
        break;
      }
    }
    final seconds = int.tryParse(header?.trim() ?? '');
    if (seconds == null || seconds < 0) {
      return null;
    }
    return Duration(seconds: seconds);
  }

  @override
  String toString() => 'HttpAccountGateway($baseUri)';
}
