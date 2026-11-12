/// 学习通截止时间解析与本地截止语义。
///
/// 行为移植自 `app/src/shared/chaoxing-calendar.ts`（GPL-3.0-or-later）。
/// 只接受完整年月日，时间可选；不推算缺失的年份。
library;

import 'package:jlu_dela/core/models/assignment.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/features/assignments/assignment_status.dart';
import 'package:jlu_dela/features/assignments/chaoxing_models.dart';

final RegExp _labelledDeadline = RegExp(
  r'(?:截止时间|截止日期|截止|deadline|due(?:\s+date)?|end\s*(?:time|date))\s*[:：]?\s*'
  r'(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})日?'
  r'(?:[ T]*(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
  caseSensitive: false,
);

final RegExp _trailingDigits = RegExp(r'^[\d:]');
final RegExp _trailingPartialTime = RegExp(r'^\s*[T\d]');
final RegExp _relativeTiming = RegExp(
  r'left|remaining|剩余',
  caseSensitive: false,
);

/// 解析来源给出的截止时间原文；读不到完整年月日时返回 null。
DueDeadline? parseChaoxingDeadline(String timing) {
  final match = _labelledDeadline.firstMatch(timing);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hourText = match.group(4);
  final minuteText = match.group(5);
  final secondText = match.group(6);
  final remainder = timing.substring(match.end);
  if (_trailingDigits.hasMatch(remainder)) return null;
  if (hourText == null && _trailingPartialTime.hasMatch(remainder)) return null;
  if (!_isCalendarDate(year, month, day)) return null;
  final hour = hourText == null ? null : int.parse(hourText);
  final minute = minuteText == null ? null : int.parse(minuteText);
  final second = secondText == null ? null : int.parse(secondText);
  if (hour != null &&
      (hour > 23 || minute! > 59 || (second != null && second > 59))) {
    return null;
  }
  final date =
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  final String? time;
  if (hour == null || minute == null) {
    time = null;
  } else {
    time =
        '${hour.toString().padLeft(2, '0')}'
        ':${minute.toString().padLeft(2, '0')}'
        '${second == null ? '' : ':${second.toString().padLeft(2, '0')}'}';
  }
  return DueDeadline(date: date, time: time);
}

bool _isCalendarDate(int year, int month, int day) {
  final value = DateTime.utc(year, month, day);
  return value.year == year && value.month == month && value.day == day;
}

/// 详情页时间优先于列表时间；两者都没有完整年月日时返回 null。
DueDeadline? workDeadline(ChaoxingWork work) =>
    parseChaoxingDeadline(work.detailTiming ?? '') ??
    parseChaoxingDeadline(work.timing);

/// 来源作业的截止类型；缺年份的日期归为未知，不推算。
AssignmentDueKind assignmentDueKind(ChaoxingWork work) {
  final deadline = workDeadline(work);
  if (deadline != null) {
    return deadline.time == null
        ? AssignmentDueKind.dateOnly
        : AssignmentDueKind.exact;
  }
  final text = '${work.detailTiming ?? ''} ${work.timing} ${work.status}';
  return _relativeTiming.hasMatch(text)
      ? AssignmentDueKind.relative
      : AssignmentDueKind.unknown;
}

/// 截止时刻（UTC 毫秒）。只有日期时按北京时间当天 23:59 计算，当天不算逾期。
int? assignmentDueAtMillis(Assignment assignment) {
  switch (assignment.dueKind) {
    case AssignmentDueKind.exact:
      return assignment.dueAtUtc?.millisecondsSinceEpoch;
    case AssignmentDueKind.dateOnly:
      final date = assignment.dueDate;
      if (date == null) return null;
      return _endOfDayMillis(date);
    case AssignmentDueKind.relative:
    case AssignmentDueKind.unknown:
      return null;
  }
}

/// 排序键：明确时刻在前，只有日期按校园当天 00:00，未定日期排在最后。
int assignmentSortKey(Assignment assignment) {
  switch (assignment.dueKind) {
    case AssignmentDueKind.exact:
      return assignment.dueAtUtc?.millisecondsSinceEpoch ?? undatedSortKey;
    case AssignmentDueKind.dateOnly:
      final date = assignment.dueDate;
      if (date == null) return undatedSortKey;
      return date.utcMidnight.millisecondsSinceEpoch;
    case AssignmentDueKind.relative:
    case AssignmentDueKind.unknown:
      return undatedSortKey;
  }
}

const int undatedSortKey = 1 << 62;

/// 明确时刻的 UTC 时间；只有日期或未知时返回 null。
DateTime? dueInstantOf(DueDeadline deadline) {
  final time = deadline.time;
  if (time == null) return null;
  final stamp = time.length == 5 ? '$time:00' : time;
  return DateTime.tryParse('${deadline.date}T$stamp+08:00')?.toUtc();
}

int _endOfDayMillis(LocalDate date) {
  final value = DateTime.tryParse('${date.toIso8601String()}T23:59:00+08:00');
  return value?.toUtc().millisecondsSinceEpoch ?? undatedSortKey;
}

/// 看板上的截止时间文案；没有完整时间时保留上次同步的原文，不伪造倒计时。
String assignmentTimeText(Assignment assignment, DateTime now) {
  final snapshot = assignment.timingText?.trim() ?? '';
  switch (assignment.dueKind) {
    case AssignmentDueKind.exact:
      final dueAt = assignment.dueAtUtc;
      if (dueAt == null) return _snapshotText(snapshot);
      final label = '截止 ${_formatShanghai(dueAt)}';
      if (isCompletedSourceStatus(assignment.sourceStatus)) return label;
      final remaining =
          dueAt.millisecondsSinceEpoch - now.millisecondsSinceEpoch;
      if (remaining <= 0) return '$label · 已过截止时间';
      final minutes = (remaining / Duration.millisecondsPerMinute).ceil();
      final days = minutes ~/ 1440;
      final hours = (minutes % 1440) ~/ 60;
      final dayText = days > 0 ? '$days天' : '';
      final hourText = hours > 0 ? '$hours小时' : '';
      final minuteText = days == 0 && (minutes % 60 != 0 || hours == 0)
          ? '${minutes % 60}分钟'
          : '';
      return '$label · 剩余$dayText$hourText$minuteText';
    case AssignmentDueKind.dateOnly:
      final date = assignment.dueDate;
      if (date == null) return _snapshotText(snapshot);
      return '截止 ${date.toIso8601String()}（具体时刻待确认）';
    case AssignmentDueKind.relative:
    case AssignmentDueKind.unknown:
      return _snapshotText(snapshot);
  }
}

String _snapshotText(String snapshot) {
  if (snapshot.contains('（年份待确认）')) return snapshot;
  return snapshot.isEmpty ? '尚未读到截止时间，请打开原网页查看' : '上次同步显示：$snapshot';
}

String _formatShanghai(DateTime utc) {
  final local = utc.toUtc().add(const Duration(hours: 8));
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
