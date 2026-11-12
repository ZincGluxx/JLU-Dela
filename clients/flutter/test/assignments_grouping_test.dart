import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/assignment.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/features/assignments/assignment_grouping.dart';

Assignment _assignment({
  String id = 'a',
  String title = '作业',
  String sourceStatus = 'not_submitted',
  AssignmentDueKind dueKind = AssignmentDueKind.unknown,
  LocalDate? dueDate,
  DateTime? dueAtUtc,
  String? timingText,
  DateTime? readAtUtc,
  DateTime? mutedAtUtc,
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
    readAtUtc: readAtUtc,
    mutedAtUtc: mutedAtUtc,
  );
}

Assignment _exact(String value, {String status = 'not_submitted'}) {
  return _assignment(
    sourceStatus: status,
    dueKind: AssignmentDueKind.exact,
    dueAtUtc: DateTime.parse('$value+08:00').toUtc(),
  );
}

void main() {
  final now = DateTime.parse('2026-11-03T10:00:00+08:00');

  group('workSection', () {
    test('separates overdue, soon, later, undated and completed work', () {
      expect(
        workSection(_exact('2026-11-01T23:59:00'), now),
        WorkSection.overdue,
      );
      expect(workSection(_exact('2026-11-05T23:59:00'), now), WorkSection.soon);
      expect(
        workSection(_exact('2026-12-20T23:59:00'), now),
        WorkSection.later,
      );
      expect(
        workSection(
          _assignment(dueKind: AssignmentDueKind.relative, timingText: '剩余2天'),
          now,
        ),
        WorkSection.undated,
      );
      expect(workSection(_assignment(), now), WorkSection.undated);
      expect(
        workSection(_exact('2026-11-01T23:59:00', status: 'submitted'), now),
        WorkSection.done,
      );
      for (final status in <String>[
        'awaiting_review',
        'marked',
        'submitted',
        'completed',
      ]) {
        expect(
          workSection(
            _assignment(
              sourceStatus: status,
              dueKind: AssignmentDueKind.relative,
            ),
            now,
          ),
          WorkSection.done,
          reason: status,
        );
      }
    });

    test(
      'uses inclusive boundaries for the due instant and the 7-day window',
      () {
        expect(
          workSection(_exact('2026-11-03T10:00:00'), now),
          WorkSection.soon,
        );
        expect(
          workSection(_exact('2026-11-03T09:59:00'), now),
          WorkSection.overdue,
        );
        expect(
          workSection(_exact('2026-11-10T10:00:00'), now),
          WorkSection.soon,
        );
        expect(
          workSection(_exact('2026-11-10T10:01:00'), now),
          WorkSection.later,
        );
        expect(
          workSection(
            _assignment(
              dueKind: AssignmentDueKind.dateOnly,
              dueDate: const LocalDate(2026, 11, 3),
            ),
            now,
          ),
          WorkSection.soon,
        );
      },
    );

    test('ignored work wins over completed work', () {
      final muted = _assignment(
        sourceStatus: 'submitted',
        dueKind: AssignmentDueKind.exact,
        dueAtUtc: DateTime.parse('2026-11-05T23:59:00+08:00').toUtc(),
        mutedAtUtc: DateTime.utc(2026, 11, 3),
      );
      expect(workSection(muted, now), WorkSection.ignored);
    });

    test('read marks never move work into the completed section', () {
      final read = _assignment(
        dueKind: AssignmentDueKind.exact,
        dueAtUtc: DateTime.parse('2026-11-05T23:59:00+08:00').toUtc(),
        readAtUtc: DateTime.utc(2026, 11, 3),
      );
      expect(workSection(read, now), WorkSection.soon);
      expect(workSummary([read], now).pending, 1);
      expect(workSummary([read], now).done, 0);
      expect(workSummary([read], now).ignored, 0);
    });
  });

  group('workSummary', () {
    test('counts pending work, completed work and ignored work separately', () {
      final items = [
        _assignment(
          id: '1',
          title: '无时间',
          dueKind: AssignmentDueKind.relative,
          timingText: '剩余2天',
        ),
        _exact('2026-12-20T23:59:00'),
        _exact('2026-11-01T23:59:00'),
        _exact('2026-11-02T23:59:00', status: 'submitted'),
      ];
      expect(
        workSummary(items, now),
        const WorkSummary(
          total: 4,
          pending: 3,
          done: 1,
          overdue: 1,
          undated: 1,
          ignored: 0,
        ),
      );
    });

    test('moves ignored work out of the pending counts', () {
      final items = [
        _exact('2026-11-05T23:59:00'),
        _assignment(mutedAtUtc: DateTime.utc(2026, 11, 3)),
      ];
      expect(
        workSummary(items, now),
        const WorkSummary(
          total: 2,
          pending: 1,
          done: 0,
          overdue: 0,
          undated: 0,
          ignored: 1,
        ),
      );
    });
  });

  group('compareAssignmentDue', () {
    test('sorts by the nearest deadline with undated work last', () {
      final items = [
        _assignment(id: '1', title: '无时间', dueKind: AssignmentDueKind.relative),
        _assignment(
          id: '2',
          title: '之后',
          dueKind: AssignmentDueKind.exact,
          dueAtUtc: DateTime.parse('2026-12-20T23:59:00+08:00').toUtc(),
        ),
        _assignment(
          id: '3',
          title: '逾期',
          dueKind: AssignmentDueKind.exact,
          dueAtUtc: DateTime.parse('2026-11-01T23:59:00+08:00').toUtc(),
        ),
        _assignment(
          id: '4',
          title: '已完成',
          dueKind: AssignmentDueKind.exact,
          dueAtUtc: DateTime.parse('2026-11-02T23:59:00+08:00').toUtc(),
        ),
      ];
      items.sort(compareAssignmentDue);
      expect(items.map((item) => item.title), ['逾期', '已完成', '之后', '无时间']);
    });

    test('breaks deadline ties by title', () {
      final items = [
        _assignment(
          id: '1',
          title: 'B',
          dueKind: AssignmentDueKind.exact,
          dueAtUtc: DateTime.parse('2026-11-05T23:59:00+08:00').toUtc(),
        ),
        _assignment(
          id: '2',
          title: 'A',
          dueKind: AssignmentDueKind.exact,
          dueAtUtc: DateTime.parse('2026-11-05T23:59:00+08:00').toUtc(),
        ),
      ];
      items.sort(compareAssignmentDue);
      expect(items.map((item) => item.title), ['A', 'B']);
    });
  });

  group('reminderStage', () {
    final reminderNow = DateTime.parse('2026-11-03T12:00:00+08:00');
    Assignment dueTomorrow() => _exact('2026-11-04T08:00:00');

    test('moves through soon, urgent and overdue stages', () {
      expect(
        reminderStage(dueTomorrow(), reminderNow),
        ReminderCheck(
          stage: ReminderStage.soon,
          dueAtMillis: DateTime.parse(
            '2026-11-04T08:00:00+08:00',
          ).millisecondsSinceEpoch,
        ),
      );
      expect(
        reminderStage(
          dueTomorrow(),
          reminderNow.add(const Duration(hours: 19)),
        )?.stage,
        ReminderStage.urgent,
      );
      expect(
        reminderStage(
          dueTomorrow(),
          reminderNow.add(const Duration(hours: 21)),
        )?.stage,
        ReminderStage.overdue,
      );
    });

    test(
      'only reminds for dated, unfinished, unignored work within 24 hours',
      () {
        for (final value in <Assignment>[
          _exact('2026-11-10T08:00:00'),
          _exact('2026-10-01T08:00:00'),
          _assignment(
            dueKind: AssignmentDueKind.dateOnly,
            dueDate: const LocalDate(2026, 11, 4),
          ),
          _assignment(dueKind: AssignmentDueKind.relative, timingText: '剩余2天'),
          _exact('2026-11-04T08:00:00', status: 'submitted'),
          _exact('2026-11-04T08:00:00', status: 'marked'),
          _assignment(
            dueKind: AssignmentDueKind.exact,
            dueAtUtc: DateTime.parse('2026-11-04T08:00:00+08:00').toUtc(),
            mutedAtUtc: DateTime.utc(2026, 11, 3),
          ),
        ]) {
          expect(reminderStage(value, reminderNow), isNull);
        }
      },
    );

    test('keys reminders by deadline and stage', () {
      expect(
        reminderKey(dueTomorrow(), ReminderStage.soon),
        '2026-11-04T08:00|soon',
      );
      expect(
        reminderKey(dueTomorrow(), ReminderStage.urgent),
        isNot(reminderKey(dueTomorrow(), ReminderStage.soon)),
      );
      expect(
        reminderKey(dueTomorrow(), ReminderStage.overdue),
        isNot(reminderKey(dueTomorrow(), ReminderStage.urgent)),
      );
      expect(
        reminderKey(_exact('2026-11-04T09:00:00'), ReminderStage.soon),
        isNot(reminderKey(dueTomorrow(), ReminderStage.soon)),
      );
    });
  });
}
