import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/source.dart';
import '../storage/source_snapshot_store.dart';
import 'source.dart';

SourceFailure sourceFailureOf(Object error, {required SourceKind source}) {
  if (error is SourceException) {
    return error.failure.withSource(source);
  }
  if (error is TimeoutException) {
    return SourceFailure(
      code: SourceErrorCodes.sourceTimeout,
      message: '来源请求超时',
      retryable: true,
      source: source,
    );
  }
  if (error is SocketException || error is http.ClientException) {
    return SourceFailure(
      code: SourceErrorCodes.sourceNetwork,
      message: '无法连接来源',
      retryable: true,
      source: source,
    );
  }
  return SourceFailure(
    code: SourceErrorCodes.sourceUnknown,
    message: '$error',
    source: source,
  );
}

class SourceExecutor {
  SourceExecutor({required this.snapshots, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SourceSnapshotStore snapshots;
  final DateTime Function() _now;

  Future<SourceResult<T>> run<T>({
    required SourceKind source,
    required String resource,
    String scopeKey = '',
    required Future<T> Function() fetch,
    required Future<void> Function(T value, DateTime observedAt) persist,
  }) async {
    final attemptAt = _now().toUtc();
    final T value;
    try {
      value = await fetch();
    } on Exception catch (error) {
      final failure = sourceFailureOf(error, source: source);
      await snapshots.recordFailure(
        source,
        resource,
        scopeKey: scopeKey,
        attemptedAt: attemptAt,
        code: failure.code,
        message: failure.message,
      );
      final snapshot = await snapshots.read(
        source,
        resource,
        scopeKey: scopeKey,
      );
      return SourceFailed(failure: failure, snapshot: snapshot);
    }

    final observedAt = _now().toUtc();
    await persist(value, observedAt);
    await snapshots.recordSuccess(
      source,
      resource,
      scopeKey: scopeKey,
      observedAt: observedAt,
    );
    final snapshot = await snapshots.read(source, resource, scopeKey: scopeKey);
    return SourceSuccess(
      value: value,
      observedAt: observedAt,
      snapshot: snapshot,
    );
  }
}
