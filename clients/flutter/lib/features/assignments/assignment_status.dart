/// 学习通提交状态的规范值与展示文案。
///
/// 行为移植自 `app/src/shared/chaoxing-calendar.ts`（GPL-3.0-or-later）。
/// 已读/忽略是本机标记，永远不参与这里的完成判定。
library;

enum ChaoxingSourceStatus {
  notSubmitted('not_submitted', '未提交'),
  awaitingReview('awaiting_review', '已提交 · 待批阅'),
  marked('marked', '已批阅'),
  submitted('submitted', '已提交'),
  completed('completed', '已完成'),
  unknown('unknown', '状态待确认');

  const ChaoxingSourceStatus(this.code, this.label);

  /// 写入本地快照的规范值；无法判断时为 `unknown`。
  final String code;
  final String label;

  bool get countsAsCompleted =>
      this != ChaoxingSourceStatus.notSubmitted &&
      this != ChaoxingSourceStatus.unknown;
}

final RegExp _notSubmitted = RegExp(
  r'^(未交|未提交|未完成|to be submitted|not submitted|unsubmitted)$',
  caseSensitive: false,
);
final RegExp _awaitingReview = RegExp(
  r'^(待批阅|待批改|待评分|to be marked|pending review|pending grading)$',
  caseSensitive: false,
);
final RegExp _marked = RegExp(
  r'^(已批阅|已批改|已评分|reviewd|reviewed|graded|marked)$',
  caseSensitive: false,
);
final RegExp _submitted = RegExp(r'^(已交|已提交|submitted)$', caseSensitive: false);
final RegExp _completed = RegExp(r'^(已完成|completed)$', caseSensitive: false);

String normalizeStatusText(String status) =>
    status.trim().replaceAll(RegExp(r'\s+'), ' ');

ChaoxingSourceStatus parseSourceStatus(String status) {
  final value = normalizeStatusText(status);
  if (value.isEmpty) return ChaoxingSourceStatus.unknown;
  if (_notSubmitted.hasMatch(value)) return ChaoxingSourceStatus.notSubmitted;
  if (_awaitingReview.hasMatch(value)) {
    return ChaoxingSourceStatus.awaitingReview;
  }
  if (_marked.hasMatch(value)) return ChaoxingSourceStatus.marked;
  if (_submitted.hasMatch(value)) return ChaoxingSourceStatus.submitted;
  if (_completed.hasMatch(value)) return ChaoxingSourceStatus.completed;
  return ChaoxingSourceStatus.unknown;
}

/// 界面展示用文案；未知状态保留来源原文，空状态显示「状态待确认」。
String sourceStatusLabel(String status) {
  final parsed = parseSourceStatus(status);
  if (parsed != ChaoxingSourceStatus.unknown) return parsed.label;
  final value = normalizeStatusText(status);
  return value.isEmpty ? ChaoxingSourceStatus.unknown.label : value;
}

/// 来源状态原文，写入 `source_status_text`；空值不保存。
String? sourceStatusText(String status) {
  final value = normalizeStatusText(status);
  return value.isEmpty ? null : value;
}

bool isWorkCompleted(String status) =>
    parseSourceStatus(status).countsAsCompleted;
