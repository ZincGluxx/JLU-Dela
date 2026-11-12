/// 作业看板的分组、排序与截止提醒判定。
///
/// 行为移植自 `app/src/shared/chaoxing-calendar.ts`（GPL-3.0-or-later）。
/// 分组优先级：已忽略 > 已完成 > 逾期 / 7 天内 / 之后 / 未定。
library;

import 'package:jlu_dela/features/assignments/assignment_deadline.dart';
import 'package:jlu_dela/features/assignments/assignment_status.dart';
import 'package:jlu_dela/features/assignments/chaoxing_models.dart';

const int defaultSoonDays = 7;

const List<WorkSection> workSections = [
  WorkSection.overdue,
  WorkSection.soon,
  WorkSection.later,
  WorkSection.undated,
  WorkSection.done,
  WorkSection.ignored,
];

const Map<WorkSection, String> workSectionLabels = {
  WorkSection.overdue: '已过截止时间',
  WorkSection.soon: '7 天内截止',
  WorkSection.later: '之后截止',
  WorkSection.undated: '截止时间待确认',
  WorkSection.done: '已完成 / 已批阅',
  WorkSection.ignored: '已忽略',
};

class WorkSummary {
  const WorkSummary({
    required this.total,
    required this.pending,
    required this.done,
    required this.overdue,
    required this.undated,
    required this.ignored,
  });

  final int total;
  final int pending;
  final int done;
  final int overdue;
  final int undated;
  final int ignored;

  @override
  bool operator ==(Object other) =>
      other is WorkSummary &&
      other.total == total &&
      other.pending == pending &&
      other.done == done &&
      other.overdue == overdue &&
      other.undated == undated &&
      other.ignored == ignored;

  @override
  int get hashCode =>
      Object.hash(total, pending, done, overdue, undated, ignored);

  @override
  String toString() =>
      'WorkSummary(total: $total, pending: $pending, done: $done, '
      'overdue: $overdue, undated: $undated, ignored: $ignored)';
}

WorkSection workSection(
  ChaoxingWork work,
  DateTime now, {
  int soonDays = defaultSoonDays,
}) {
  if (work.mutedAt != null) return WorkSection.ignored;
  if (isWorkCompleted(work.status)) return WorkSection.done;
  final due = workDueAtMillis(work);
  if (due == null) return WorkSection.undated;
  final remaining = due - now.millisecondsSinceEpoch;
  if (remaining < 0) return WorkSection.overdue;
  return remaining <= soonDays * Duration.millisecondsPerDay
      ? WorkSection.soon
      : WorkSection.later;
}

WorkSummary workSummary(
  Iterable<ChaoxingWork> works,
  DateTime now, {
  int soonDays = defaultSoonDays,
}) {
  var total = 0;
  var pending = 0;
  var done = 0;
  var overdue = 0;
  var undated = 0;
  var ignored = 0;
  for (final work in works) {
    total += 1;
    switch (workSection(work, now, soonDays: soonDays)) {
      case WorkSection.ignored:
        ignored += 1;
      case WorkSection.done:
        done += 1;
      case WorkSection.overdue:
        pending += 1;
        overdue += 1;
      case WorkSection.undated:
        pending += 1;
        undated += 1;
      case WorkSection.soon:
      case WorkSection.later:
        pending += 1;
    }
  }
  return WorkSummary(
    total: total,
    pending: pending,
    done: done,
    overdue: overdue,
    undated: undated,
    ignored: ignored,
  );
}

/// 按截止时间由近到远排序，没有截止时间的排最后；同一时间按标题排序。
int compareWorkDue(ChaoxingWork left, ChaoxingWork right) {
  final leftDue = workDueAtMillis(left) ?? _undatedSortKey;
  final rightDue = workDueAtMillis(right) ?? _undatedSortKey;
  if (leftDue != rightDue) return leftDue.compareTo(rightDue);
  return left.title.compareTo(right.title);
}

const int _undatedSortKey = 1 << 62;

enum ReminderStage { soon, urgent, overdue }

class ReminderCheck {
  const ReminderCheck({required this.stage, required this.dueAtMillis});

  final ReminderStage stage;
  final int dueAtMillis;

  @override
  bool operator ==(Object other) =>
      other is ReminderCheck &&
      other.stage == stage &&
      other.dueAtMillis == dueAtMillis;

  @override
  int get hashCode => Object.hash(stage, dueAtMillis);

  @override
  String toString() => 'ReminderCheck(${stage.name}, $dueAtMillis)';
}

/// 此刻应触发的提醒阶段；不需要提醒时返回 null。
///
/// 只提醒已读到具体时刻、未完成、未忽略的作业；逾期超过 24 小时不再补提醒。
ReminderCheck? reminderStage(ChaoxingWork work, DateTime now) {
  if (work.mutedAt != null || isWorkCompleted(work.status)) return null;
  final deadline = workDeadline(work);
  final dueAt = workDueAtMillis(work);
  if (dueAt == null || deadline?.time == null) return null;
  final remaining = dueAt - now.millisecondsSinceEpoch;
  if (remaining > Duration.millisecondsPerDay ||
      remaining <= -Duration.millisecondsPerDay) {
    return null;
  }
  final stage = remaining <= 0
      ? ReminderStage.overdue
      : remaining <= Duration.millisecondsPerHour
      ? ReminderStage.urgent
      : ReminderStage.soon;
  return ReminderCheck(stage: stage, dueAtMillis: dueAt);
}

/// 提醒去重键：截止时刻变化或进入下一阶段时会重新提醒。
String reminderKey(ChaoxingWork work, ReminderStage stage) {
  final deadline = workDeadline(work);
  return '${deadline?.date ?? ''}T${deadline?.time ?? ''}|${stage.name}';
}
