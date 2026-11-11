import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jlu_dela_api/api.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../features/diagnostics/diagnostics_models.dart';
import 'api_failure.dart';

typedef ClientVersionLoader = Future<String> Function();

class DiagnosticsService {
  DiagnosticsService({
    required this.apiBaseUri,
    required http.Client httpClient,
    ClientVersionLoader? clientVersionLoader,
    Duration timeout = const Duration(seconds: 8),
  }) : requestTimeout = timeout,
       _clientVersionLoader = clientVersionLoader ?? _loadClientVersion,
       _apiClient = ApiClient(basePath: apiBaseUri.toString()) {
    _apiClient.client = httpClient;
  }

  final Uri apiBaseUri;
  final Duration requestTimeout;
  final ClientVersionLoader _clientVersionLoader;
  final ApiClient _apiClient;

  Future<DiagnosticsReport> check() async {
    final clientVersionFuture = _clientVersionLoader();
    final live = await _request(() => HealthApi(_apiClient).getHealthLive());
    final meta = await _request(() => MetaApi(_apiClient).getMeta());
    final database = await _checkDatabase();
    final clientVersion = await clientVersionFuture;

    return DiagnosticsReport(
      clientVersion: clientVersion,
      apiBaseUri: apiBaseUri,
      live: live,
      meta: meta,
      database: database,
      checkedAt: DateTime.now(),
    );
  }

  Future<T> _request<T>(Future<T?> Function() request) async {
    try {
      final value = await request().timeout(requestTimeout);
      if (value == null) {
        throw const ApiFailure(
          kind: ApiFailureKind.protocol,
          technicalMessage: 'The API returned an empty response.',
        );
      }
      return value;
    } on ApiFailure {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiFailure(
        kind: ApiFailureKind.timeout,
        technicalMessage: error.toString(),
      );
    } on ApiException catch (error) {
      throw mapApiException(error);
    } on http.ClientException catch (error) {
      throw ApiFailure(
        kind: ApiFailureKind.network,
        technicalMessage: error.message,
      );
    } on FormatException catch (error) {
      throw ApiFailure(
        kind: ApiFailureKind.protocol,
        technicalMessage: error.message,
      );
    }
  }

  Future<DatabaseReadiness> _checkDatabase() async {
    try {
      final response = await HealthApi(
        _apiClient,
      ).getHealthReadyWithHttpInfo().timeout(requestTimeout);

      if (response.statusCode == 200) {
        final parsed = ReadyResponse.fromJson(jsonDecode(response.body));
        if (parsed == null) {
          throw const ApiFailure(
            kind: ApiFailureKind.protocol,
            technicalMessage: 'Ready response is missing required fields.',
          );
        }
        return DatabaseReadiness(
          ready: true,
          schemaVersion: parsed.data.schemaVersion,
          requestId: parsed.meta.requestId,
        );
      }

      if (response.statusCode == 503) {
        final failure = apiFailureFromErrorBody(
          response.statusCode,
          response.body,
        );
        return DatabaseReadiness(
          ready: false,
          message: failure.displayMessage,
          requestId: failure.requestId,
        );
      }

      throw apiFailureFromErrorBody(response.statusCode, response.body);
    } on ApiFailure {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiFailure(
        kind: ApiFailureKind.timeout,
        technicalMessage: error.toString(),
      );
    } on ApiException catch (error) {
      throw mapApiException(error);
    } on http.ClientException catch (error) {
      throw ApiFailure(
        kind: ApiFailureKind.network,
        technicalMessage: error.message,
      );
    } on FormatException catch (error) {
      throw ApiFailure(
        kind: ApiFailureKind.protocol,
        technicalMessage: error.message,
      );
    }
  }

  static Future<String> _loadClientVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (info.buildNumber.isEmpty) {
      return info.version;
    }
    return '${info.version}+${info.buildNumber}';
  }
}
