import '../models/source.dart';

abstract final class SourceErrorCodes {
  static const sourceAuthRequired = 'SOURCE_AUTH_REQUIRED';
  static const sourceNetwork = 'SOURCE_NETWORK';
  static const sourceTimeout = 'SOURCE_TIMEOUT';
  static const sourceProtocol = 'SOURCE_PROTOCOL';
  static const sourceUnavailable = 'SOURCE_UNAVAILABLE';
  static const sourceUnknown = 'SOURCE_UNKNOWN';
}

class SourceFailure {
  const SourceFailure({
    required this.code,
    required this.message,
    this.retryable = false,
    this.source,
  });

  final String code;
  final String message;
  final bool retryable;
  final SourceKind? source;

  SourceFailure withSource(SourceKind source) {
    return SourceFailure(
      code: code,
      message: message,
      retryable: retryable,
      source: this.source ?? source,
    );
  }

  @override
  String toString() => 'SourceFailure($code, retryable: $retryable)';
}

class SourceException implements Exception {
  const SourceException(this.failure);

  final SourceFailure failure;

  @override
  String toString() => 'SourceException(${failure.code}: ${failure.message})';
}

sealed class SourceResult<T> {
  const SourceResult();
}

class SourceSuccess<T> extends SourceResult<T> {
  const SourceSuccess({
    required this.value,
    required this.observedAt,
    required this.snapshot,
  });

  final T value;
  final DateTime observedAt;
  final SourceSnapshot snapshot;
}

class SourceFailed<T> extends SourceResult<T> {
  const SourceFailed({required this.failure, required this.snapshot});

  final SourceFailure failure;
  final SourceSnapshot snapshot;

  bool get hasCachedData => snapshot.hasCachedData;
}
