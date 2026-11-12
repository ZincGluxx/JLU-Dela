import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/source.dart';
import 'campus_source_policy.dart';
import 'source.dart';
import 'source_session.dart';

const _redirectStatuses = {301, 302, 303, 307, 308};

class CookieSourceHttpClient implements SourceHttpClient {
  CookieSourceHttpClient({
    required this.sessions,
    http.Client? client,
    this.maxRedirects = 5,
  }) : _client = client ?? http.Client();

  final SourceSessionRegistry sessions;
  final int maxRedirects;
  final http.Client _client;

  @override
  Future<SourceResponse> send(SourceRequest request) async {
    try {
      return await _followRedirects(request).timeout(request.timeout);
    } on TimeoutException {
      throw const SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceTimeout,
          message: '来源请求超时，请检查网络或校园网/VPN 后重试',
          retryable: true,
        ),
      );
    } on SourceException {
      rethrow;
    } on http.ClientException {
      throw const SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceNetwork,
          message: '无法连接来源服务，请检查网络或校园网/VPN',
          retryable: true,
        ),
      );
    } on SocketException {
      throw const SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceNetwork,
          message: '无法连接来源服务，请检查网络或校园网/VPN',
          retryable: true,
        ),
      );
    }
  }

  Future<SourceResponse> _followRedirects(SourceRequest request) async {
    final initialSource = sourceForAllowedUri(request.uri);
    if (!isAllowedSourceUri(request.uri) || initialSource == null) {
      throw const SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceProtocol,
          message: '只能访问白名单内的校园来源地址',
        ),
      );
    }
    final group = sourceAuthGroup(initialSource);
    final endpoints = CampusSourceEndpoints.forSource(initialSource);
    var uri = request.uri;
    var method = request.method;
    var body = request.body;
    for (var redirects = 0; ; redirects++) {
      final source = sourceForAllowedUri(uri);
      if (source == null || sourceAuthGroup(source) != group) {
        throw const SourceException(
          SourceFailure(
            code: SourceErrorCodes.sourceProtocol,
            message: '来源请求跳转到了其他来源，已停止',
          ),
        );
      }
      final outgoing = http.Request(method, uri)
        ..followRedirects = false
        ..headers.addAll(_requestHeaders(request.headers, source, uri));
      if (body != null) {
        outgoing.body = body;
      }
      final response = await http.Response.fromStream(
        await _client.send(outgoing),
      );
      final status = response.statusCode;
      final location = response.headers['location'];
      if (_redirectStatuses.contains(status) && location != null) {
        final target = uri.resolve(location);
        if (isSourceLoginUri(target)) {
          throw _authRequired(endpoints);
        }
        final targetSource = sourceForAllowedUri(target);
        if (!isAllowedSourceUri(target) || targetSource == null) {
          throw const SourceException(
            SourceFailure(
              code: SourceErrorCodes.sourceProtocol,
              message: '来源返回了白名单之外的跳转，已停止',
            ),
          );
        }
        if (sourceAuthGroup(targetSource) != group) {
          throw const SourceException(
            SourceFailure(
              code: SourceErrorCodes.sourceProtocol,
              message: '来源请求跳转到了其他来源，已停止',
            ),
          );
        }
        if (redirects >= maxRedirects) {
          throw const SourceException(
            SourceFailure(
              code: SourceErrorCodes.sourceProtocol,
              message: '来源重定向次数过多，已停止',
            ),
          );
        }
        if ((status == 301 || status == 302 || status == 303) &&
            method != 'GET' &&
            method != 'HEAD') {
          method = 'GET';
          body = null;
        }
        uri = target;
        continue;
      }
      final page = SourceResponse(
        statusCode: status,
        body: response.body,
        headers: response.headers,
        finalUri: uri,
      );
      if (status == 401 || endpoints.looksLikeLoginPage(page)) {
        throw _authRequired(endpoints);
      }
      if (status == 408) {
        throw const SourceException(
          SourceFailure(
            code: SourceErrorCodes.sourceTimeout,
            message: '来源服务响应超时，请稍后重试',
            retryable: true,
          ),
        );
      }
      if (status == 429 || status >= 500) {
        throw SourceException(
          SourceFailure(
            code: SourceErrorCodes.sourceUnavailable,
            message: '来源服务暂时不可用（HTTP $status），请稍后重试',
            retryable: true,
          ),
        );
      }
      if (!page.isSuccess) {
        throw SourceException(
          SourceFailure(
            code: SourceErrorCodes.sourceProtocol,
            message: '来源请求失败（HTTP $status），请检查账号权限或校园网/VPN',
          ),
        );
      }
      return page;
    }
  }

  Map<String, String> _requestHeaders(
    Map<String, String> headers,
    SourceKind source,
    Uri uri,
  ) {
    final result = <String, String>{};
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'cookie') {
        continue;
      }
      result[entry.key] = entry.value;
    }
    final cookies = sessions.cookieHeaderFor(source, uri);
    if (cookies.isNotEmpty) {
      result['cookie'] = cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }
    return result;
  }

  SourceException _authRequired(CampusSourceEndpoints endpoints) {
    return SourceException(
      SourceFailure(
        code: SourceErrorCodes.sourceAuthRequired,
        message: '${endpoints.source.label}登录已失效，请重新登录来源',
        source: endpoints.source,
      ),
    );
  }
}
