enum SourceKind {
  jluIedu('jlu_iedu', '教务系统'),
  chaoxing('chaoxing', '学习通'),
  jluOa('jlu_oa', '电子校务');

  const SourceKind(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static SourceKind fromDatabaseValue(String value) {
    return SourceKind.values.firstWhere(
      (source) => source.databaseValue == value,
    );
  }
}

class SourceRef {
  const SourceRef({
    required this.source,
    required this.sourceScope,
    required this.sourceId,
  });

  final SourceKind source;
  final String sourceScope;
  final String sourceId;
}

class SourceSnapshot {
  const SourceSnapshot({
    required this.source,
    required this.resource,
    this.scopeKey = '',
    this.lastSuccessAtUtc,
    this.lastAttemptAtUtc,
    this.lastErrorCode,
    this.lastErrorMessage,
  });

  final SourceKind source;
  final String resource;
  final String scopeKey;
  final DateTime? lastSuccessAtUtc;
  final DateTime? lastAttemptAtUtc;
  final String? lastErrorCode;
  final String? lastErrorMessage;

  bool get hasCachedData => lastSuccessAtUtc != null;
}
