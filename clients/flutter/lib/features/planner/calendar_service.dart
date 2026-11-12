import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:jlu_dela_api/api.dart';

import '../../core/api/api_failure.dart';
import 'school_time.dart';

/// 学习日历接口。
///
/// 只读 /api/v1/calendar：一次取回课程、作业、个人待办和来源状态。错误统一折成
/// [ApiFailure]，展示文案由 [calendarFailureMessage] 补齐。
class CalendarService {
  CalendarService({
    required this.apiBaseUri,
    required http.Client httpClient,
    Duration timeout = const Duration(seconds: 8),
    String? Function()? accessToken,
  }) : requestTimeout = timeout,
       _apiClient = ApiClient(
         basePath: apiBaseUri.toString(),
         authentication: accessToken == null
             ? null
             : (HttpBearerAuth()..accessToken = accessToken),
       ) {
    _apiClient.client = httpClient;
  }

  final Uri apiBaseUri;
  final Duration requestTimeout;
  final ApiClient _apiClient;

  /// 读取 [from]（含）到 [to]（不含）之间的日历，两端都按北京时间日历日解释。
  ///
  /// 这里直接走 [ApiClient.invokeAPI] 而不是生成的 [CalendarApi]：后者把 [DateTime]
  /// 序列化成 RFC3339 时刻，而服务端只接受补零的 YYYY-MM-DD，会直接判 422。
  Future<CalendarData> load({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _send(from, to);
    final body = _bodyText(response);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw apiFailureFromErrorBody(response.statusCode, body);
    }
    return _parse(body);
  }

  Future<http.Response> _send(DateTime from, DateTime to) async {
    try {
      return await _apiClient
          .invokeAPI(
            '/api/v1/calendar',
            'GET',
            [
              QueryParam('from', formatDay(from)),
              QueryParam('to', formatDay(to)),
            ],
            null,
            <String, String>{},
            <String, String>{},
            null,
          )
          .timeout(requestTimeout);
    } on ApiException catch (error) {
      throw mapApiException(error);
    } on TimeoutException {
      throw const ApiFailure(
        kind: ApiFailureKind.timeout,
        technicalMessage: 'The calendar request timed out.',
      );
    } on http.ClientException catch (error) {
      throw ApiFailure(
        kind: ApiFailureKind.network,
        technicalMessage: error.message,
      );
    }
  }

  CalendarData _parse(String body) {
    try {
      final payload = CalendarResponse.fromJson(jsonDecode(body));
      final data = payload?.data;
      if (data == null) {
        throw const ApiFailure(
          kind: ApiFailureKind.protocol,
          technicalMessage: 'The calendar response has no data.',
        );
      }
      return data;
    } on ApiFailure {
      rethrow;
    } on FormatException catch (error) {
      throw ApiFailure(
        kind: ApiFailureKind.protocol,
        technicalMessage: error.message,
      );
    } on TypeError catch (error) {
      throw ApiFailure(
        kind: ApiFailureKind.protocol,
        technicalMessage: error.toString(),
      );
    }
  }

  /// 服务端不声明 charset，按 UTF-8 自行解码，避免中文标题被当成 latin1 读坏。
  String _bodyText(http.Response response) =>
      utf8.decode(response.bodyBytes, allowMalformed: true);
}

/// 日历请求的展示文案。
///
/// [ApiFailure.displayMessage] 只区分传输层错误和状态码，日历特有的 401、409、422
/// 在这里补上用户能照着做的说明；[ApiFailure] 本身仍原样抛给调用方。
String calendarFailureMessage(ApiFailure failure) {
  if (failure.kind != ApiFailureKind.server) {
    return failure.displayMessage;
  }
  return switch (failure.statusCode) {
    401 => '登录状态已失效，请重新登录后再查看日历。',
    409 => '有课程来源需要重新连接，日历可能不完整。',
    422 => '日期区间不合法，无法读取日历。',
    _ => failure.displayMessage,
  };
}
