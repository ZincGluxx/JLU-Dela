import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:jlu_dela_api/api.dart';

enum ApiFailureKind { network, timeout, server, protocol }

class ApiFailure implements Exception {
  const ApiFailure({
    required this.kind,
    required this.technicalMessage,
    this.code,
    this.requestId,
    this.statusCode,
    this.retryable = false,
    this.retryAfter,
    this.current,
  });

  final ApiFailureKind kind;
  final String technicalMessage;
  final String? code;
  final String? requestId;
  final int? statusCode;
  final bool retryable;
  final Duration? retryAfter;

  /// The server's version of the todo, present only for a revision conflict.
  final Todo? current;

  String get displayMessage {
    return switch (kind) {
      ApiFailureKind.network => '无法连接服务。请确认 API 地址与服务已启动。',
      ApiFailureKind.timeout => '连接服务超时。请检查网络后重试。',
      ApiFailureKind.protocol => '服务响应格式无法识别。',
      ApiFailureKind.server => switch (code) {
        'DATABASE_UNAVAILABLE' => '服务已连接，但数据库暂不可用。',
        'DATABASE_SCHEMA_MISSING' => '服务已连接，但数据库迁移尚未应用。',
        'REQUEST_TIMEOUT' => '服务处理请求超时。',
        _ => statusCode == null ? '服务返回错误。' : '服务返回错误（HTTP $statusCode）。',
      },
    };
  }

  @override
  String toString() => 'ApiFailure($kind, code: $code, status: $statusCode)';
}

ApiFailure mapApiException(ApiException error) {
  final inner = error.innerException;

  if (inner is SocketException ||
      inner is HttpException ||
      inner is TlsException) {
    return ApiFailure(
      kind: ApiFailureKind.network,
      technicalMessage: inner.toString(),
    );
  }
  if (inner is http.ClientException) {
    return ApiFailure(
      kind: ApiFailureKind.network,
      technicalMessage: inner.message,
    );
  }
  if (inner is TimeoutException) {
    return const ApiFailure(
      kind: ApiFailureKind.timeout,
      technicalMessage: 'The API request timed out.',
    );
  }

  final body = error.message;
  if (body != null && body.isNotEmpty) {
    return apiFailureFromErrorBody(error.code, body);
  }

  return ApiFailure(
    kind: ApiFailureKind.server,
    statusCode: error.code,
    technicalMessage: 'HTTP ${error.code}',
  );
}

ApiFailure apiFailureFromErrorBody(
  int statusCode,
  String body, {
  Duration? retryAfter,
}) {
  try {
    final decoded = jsonDecode(body);
    final response = ErrorResponse.fromJson(decoded);
    final detail = response?.error;
    if (detail != null) {
      Todo? current;
      if (detail.code == 'REVISION_CONFLICT') {
        try {
          current = RevisionConflictResponse.fromJson(decoded)?.error.current;
        } catch (_) {
          // A malformed conflict payload must not break error mapping.
        }
      }
      return ApiFailure(
        kind: ApiFailureKind.server,
        technicalMessage: detail.message,
        code: detail.code,
        requestId: detail.requestId,
        statusCode: statusCode,
        retryable: detail.retryable,
        retryAfter: retryAfter,
        current: current,
      );
    }
  } on FormatException {
    // Fall through to the generic server error below.
  } on TypeError {
    // Fall through to the generic server error below.
  }

  final trimmed = body.length > 240 ? '${body.substring(0, 240)}…' : body;
  return ApiFailure(
    kind: ApiFailureKind.server,
    statusCode: statusCode,
    technicalMessage: trimmed.isEmpty ? 'HTTP $statusCode' : trimmed,
    retryAfter: retryAfter,
  );
}
