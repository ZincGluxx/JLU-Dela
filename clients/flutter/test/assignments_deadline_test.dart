import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/assignment.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/features/assignments/assignment_deadline.dart';
import 'package:jlu_dela/features/assignments/chaoxing_models.dart';

ChaoxingWork _work({
  String id = 'w',
  String title = '作业',
  String status = '未交',
  String timing = '',
  String? detailTiming,
}) {
  return ChaoxingWork(
    id: id,
    title: title,
    status: status,
    timing: timing,
    detailTiming: detailTiming,
  );
}

Assignment _assignment({
  String id = 'a',
  String title = '作业',
  String sourceStatus = 'not_submitted',
  AssignmentDueKind dueKind = AssignmentDueKind.unknown,
  LocalDate? dueDate,
  DateTime? dueAtUtc,
  String? timingText,
}) {
  return Assignment(
    id: id,
    title: title,
    sourceStatus: sourceStatus,
    dueKind: dueKind,
    dueDate: dueDate,
    dueAtUtc: dueAtUtc,
    timingText: timingText,
    observedAtUtc: DateTime.utc(2026, 11, 3),
  );
}

void main() {
  group('parseChaoxingDeadline', () {
    test(
      'uses an explicitly labelled end date rather than the publication date',
      () {
        expect(
          parseChaoxingDeadline('开始时间：2026-10-01 08:00 截止时间：2026-11-02 23:59'),
          const DueDeadline(date: '2026-11-02', time: '23:59'),
        );
        expect(
          parseChaoxingDeadline('截止时间：2026年11月2日23:59:12'),
          const DueDeadline(date: '2026-11-02', time: '23:59:12'),
        );
        expect(
          parseChaoxingDeadline('截止日期：2026年11月2日'),
          const DueDeadline(date: '2026-11-02'),
        );
        expect(
          parseChaoxingDeadline('Deadline: 2026/1/5 8:00'),
          const DueDeadline(date: '2026-01-05', time: '08:00'),
        );
        expect(
          parseChaoxingDeadline('End Date: 2026.12.31'),
          const DueDeadline(date: '2026-12-31'),
        );
        expect(
          parseChaoxingDeadline('截止：2026年1月5日 9:05:06'),
          const DueDeadline(date: '2026-01-05', time: '09:05:06'),
        );
      },
    );

    test(
      'does not invent deadlines from relative, unlabeled, or invalid dates',
      () {
        for (final value in <String>[
          '剩余2天',
          '2026-11-02 23:59',
          '发布时间：2026-11-02',
          '截止时间：2026-02-30 12:00',
          '截止时间：2026-02-29 12:00',
          '截止：2026-11-02 24:00',
          '截止：2026-11-02 23:60',
          '截止：2026-11-123',
          '截止：2026-11-02 23:5',
          '截止：2026-11-02 23:59:99',
          '',
        ]) {
          expect(parseChaoxingDeadline(value), isNull, reason: value);
        }
      },
    );

    test('does not infer a missing year for partial dates', () {
      expect(parseChaoxingDeadline('截止时间：11-07 20:00（年份待确认）'), isNull);
      expect(parseChaoxingDeadline('截止时间：11-07 20:00'), isNull);
    });

    test('keeps the detail deadline ahead of the list timing', () {
      final work = _work(
        timing: '截止时间：2026-11-02 23:59',
        detailTiming: '截止时间：2026-11-04 20:00',
      );
      expect(
        workDeadline(work),
        const DueDeadline(date: '2026-11-04', time: '20:00'),
      );
    });
  });

  group('assignmentDueKind', () {
    test('separates exact, date-only, relative and unknown deadlines', () {
      expect(
        assignmentDueKind(_work(timing: '截止时间：2026-11-04 20:00')),
        AssignmentDueKind.exact,
      );
      expect(
        assignmentDueKind(_work(timing: '截止日期：2026-11-04')),
        AssignmentDueKind.dateOnly,
      );
      expect(
        assignmentDueKind(_work(timing: '剩余2天')),
        AssignmentDueKind.relative,
      );
      expect(
        assignmentDueKind(_work(timing: '2 days left')),
        AssignmentDueKind.relative,
      );
      expect(assignmentDueKind(_work()), AssignmentDueKind.unknown);
      expect(
        assignmentDueKind(_work(detailTiming: '截止时间：11-07 20:00（年份待确认）')),
        AssignmentDueKind.unknown,
      );
    });
  });

  group('assignmentDueAtMillis', () {
    test(
      'treats a date-only deadline as the end of that day in Beijing time',
      () {
        expect(
          assignmentDueAtMillis(
            _assignment(
              dueKind: AssignmentDueKind.dateOnly,
              dueDate: const LocalDate(2026, 11, 3),
            ),
          ),
          DateTime.parse('2026-11-03T23:59:00+08:00').millisecondsSinceEpoch,
        );
        expect(
          assignmentDueAtMillis(
            _assignment(
              dueKind: AssignmentDueKind.relative,
              timingText: '剩余2天',
            ),
          ),
          isNull,
        );
        expect(assignmentDueAtMillis(_assignment()), isNull);
      },
    );

    test('uses the exact time when the source provides one', () {
      expect(
        assignmentDueAtMillis(
          _assignment(
            dueKind: AssignmentDueKind.exact,
            dueAtUtc: DateTime.parse('2026-11-04T08:00:00+08:00').toUtc(),
          ),
        ),
        DateTime.parse('2026-11-04T08:00:00+08:00').millisecondsSinceEpoch,
      );
    });
  });

  group('assignmentTimeText', () {
    final now = DateTime.parse('2026-11-03T12:00:00+08:00');

    test('shows a countdown only for concrete deadlines', () {
      expect(
        assignmentTimeText(
          _assignment(
            dueKind: AssignmentDueKind.exact,
            dueAtUtc: DateTime.parse('2026-11-04T08:00:00+08:00').toUtc(),
          ),
          now,
        ),
        '截止 2026-11-04 08:00 · 剩余20小时',
      );
      expect(
        assignmentTimeText(
          _assignment(
            dueKind: AssignmentDueKind.exact,
            dueAtUtc: DateTime.parse('2026-11-03T12:30:00+08:00').toUtc(),
          ),
          now,
        ),
        '截止 2026-11-03 12:30 · 剩余30分钟',
      );
      expect(
        assignmentTimeText(
          _assignment(
            dueKind: AssignmentDueKind.exact,
            dueAtUtc: DateTime.parse('2026-11-02T23:59:00+08:00').toUtc(),
          ),
          now,
        ),
        '截止 2026-11-02 23:59 · 已过截止时间',
      );
    });

    test('does not attach a countdown to date-only or completed work', () {
      expect(
        assignmentTimeText(
          _assignment(
            dueKind: AssignmentDueKind.dateOnly,
            dueDate: const LocalDate(2026, 11, 3),
          ),
          now,
        ),
        '截止 2026-11-03（具体时刻待确认）',
      );
      expect(
        assignmentTimeText(
          _assignment(
            sourceStatus: 'submitted',
            dueKind: AssignmentDueKind.exact,
            dueAtUtc: DateTime.parse('2026-11-04T08:00:00+08:00').toUtc(),
          ),
          now,
        ),
        '截止 2026-11-04 08:00',
      );
    });

    test('keeps relative and unconfirmed source text instead of guessing', () {
      expect(
        assignmentTimeText(
          _assignment(dueKind: AssignmentDueKind.relative, timingText: '剩余2天'),
          now,
        ),
        '上次同步显示：剩余2天',
      );
      expect(assignmentTimeText(_assignment(), now), '尚未读到截止时间，请打开原网页查看');
      expect(
        assignmentTimeText(
          _assignment(timingText: '截止时间：11-07 20:00（年份待确认）'),
          now,
        ),
        '截止时间：11-07 20:00（年份待确认）',
      );
    });
  });
}
