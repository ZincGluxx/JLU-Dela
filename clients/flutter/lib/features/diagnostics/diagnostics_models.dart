import 'package:jlu_dela_api/api.dart';

class DatabaseReadiness {
  const DatabaseReadiness({
    required this.ready,
    this.schemaVersion,
    this.message,
    this.requestId,
  });

  final bool ready;
  final String? schemaVersion;
  final String? message;
  final String? requestId;
}

class DiagnosticsReport {
  const DiagnosticsReport({
    required this.clientVersion,
    required this.apiBaseUri,
    required this.live,
    required this.meta,
    required this.database,
    required this.checkedAt,
  });

  final String clientVersion;
  final Uri apiBaseUri;
  final LiveResponse live;
  final MetaResponse meta;
  final DatabaseReadiness database;
  final DateTime checkedAt;
}
