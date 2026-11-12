/// 学习通来源模型。个人标记（已读/忽略）与学校状态分开保存、分开解释。
///
/// 行为移植自 `app/src/shared/chaoxing.ts` 与 `app/src/shared/chaoxing-calendar.ts`
/// （GPL-3.0-or-later）。
library;

enum AssignmentDueKind { exact, dateOnly, relative, unknown }

enum WorkSection { overdue, soon, later, undated, done, ignored }

class DueDeadline {
  const DueDeadline({required this.date, this.time});

  /// 校园日历日，`YYYY-MM-DD`。只有日期时表示当天全天。
  final String date;

  /// 来源给出的时刻，`HH:MM` 或 `HH:MM:SS`；为空表示具体时刻待确认。
  final String? time;

  bool get hasTime => time != null;

  @override
  bool operator ==(Object other) =>
      other is DueDeadline && other.date == date && other.time == time;

  @override
  int get hashCode => Object.hash(date, time);

  @override
  String toString() => 'DueDeadline($date${time == null ? '' : ' $time'})';
}

class ChaoxingCourse {
  const ChaoxingCourse({
    required this.id,
    required this.name,
    this.teacher = '',
    this.ended = false,
    this.remark,
  });

  /// 来源课程标识，`courseid:clazzid`。
  final String id;
  final String name;
  final String teacher;
  final bool ended;

  /// 本机备注名；只影响展示与排序，不改写来源课程名。
  final String? remark;

  String get label => (remark?.isNotEmpty ?? false) ? remark! : name;
}

class ChaoxingWork {
  const ChaoxingWork({
    required this.id,
    required this.title,
    this.status = '',
    this.timing = '',
    this.detailTiming,
    this.detailSyncedAt,
    this.detailError,
    this.readAt,
    this.mutedAt,
    this.observedAt,
  });

  /// 来源作业标识（列表 URL 的 `workId`）。
  final String id;
  final String title;

  /// 来源状态原文，例如「未交」「To be marked」。
  final String status;

  /// 列表页相对时间原文，例如「剩余2天」。
  final String timing;

  /// 详情页读到的截止时间原文，例如「截止时间：2026-11-04 20:00」。
  final String? detailTiming;
  final DateTime? detailSyncedAt;
  final String? detailError;

  /// 本机标记，与学校提交状态无关。
  final DateTime? readAt;
  final DateTime? mutedAt;

  /// 这份来源状态的采集时间；相对时间只按该时刻解释。
  final DateTime? observedAt;
}

class ChaoxingWorkListItem {
  const ChaoxingWorkListItem({required this.work, required this.needsDetail});

  final ChaoxingWork work;

  /// 列表没有给出完整年月日截止时间，需要读取详情页补齐。
  final bool needsDetail;
}
