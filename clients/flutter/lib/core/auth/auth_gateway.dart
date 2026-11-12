import 'package:http/http.dart' as http;
import 'package:jlu_dela_api/api.dart';

abstract interface class AuthGateway {
  Future<TokenPair> refresh(String refreshToken);

  Future<Me> fetchMe(String accessToken);

  Future<void> revoke({
    required String accessToken,
    required String refreshToken,
  });
}

class HttpAuthGateway implements AuthGateway {
  HttpAuthGateway({required this.baseUri, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final Uri baseUri;
  final http.Client _httpClient;

  ApiClient _apiClient({String? accessToken}) {
    final apiClient = ApiClient(basePath: baseUri.toString());
    apiClient.client = accessToken == null
        ? _httpClient
        : _AuthorizedClient(_httpClient, accessToken);
    return apiClient;
  }

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    final response = await AuthApi(
      _apiClient(),
    ).refreshSession(RefreshRequest(refreshToken: refreshToken));
    final pair = response?.data;
    if (pair == null) {
      throw const FormatException('The refresh response has no token pair.');
    }
    return pair;
  }

  @override
  Future<Me> fetchMe(String accessToken) async {
    final response = await MeApi(_apiClient(accessToken: accessToken)).getMe();
    final user = response?.data;
    if (user == null) {
      throw const FormatException('The me response has no user.');
    }
    return user;
  }

  @override
  Future<void> revoke({
    required String accessToken,
    required String refreshToken,
  }) {
    return AuthApi(
      _apiClient(accessToken: accessToken),
    ).logoutSession(LogoutRequest(refreshToken: refreshToken));
  }
}

class _AuthorizedClient extends http.BaseClient {
  _AuthorizedClient(this._inner, this._accessToken);

  final http.Client _inner;
  final String _accessToken;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }
}
