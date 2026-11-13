import 'package:http/http.dart' as http;
import 'package:jlu_dela_api/api.dart';

import '../files/files_gateway.dart';
import 'auth_gateway.dart';
import 'refresh_token_store.dart';
import 'session_controller.dart';
import 'session_http_client.dart';

class WorkbenchApi {
  WorkbenchApi({
    required Uri baseUri,
    AuthGateway? authGateway,
    RefreshTokenStore? refreshTokenStore,
    http.Client? httpClient,
  }) : session = SessionController(
         gateway: authGateway ?? HttpAuthGateway(baseUri: baseUri),
         refreshTokenStore: refreshTokenStore ?? SecureRefreshTokenStore(),
       ),
       _httpClient = httpClient ?? http.Client() {
    _apiClient = ApiClient(basePath: baseUri.toString())
      ..client = SessionHttpClient(
        baseUri: baseUri,
        session: session,
        inner: _httpClient,
      );
  }

  final SessionController session;
  final http.Client _httpClient;
  late final ApiClient _apiClient;

  ApiClient get apiClient => _apiClient;

  TodosApi get todos => TodosApi(_apiClient);

  MeApi get me => MeApi(_apiClient);

  FilesGateway get files => FilesGateway(_apiClient);

  void close() {
    session.dispose();
    _httpClient.close();
  }
}
