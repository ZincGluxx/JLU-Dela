import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/features/assignments/assignment_grouping.dart';
import 'package:jlu_dela/features/assignments/chaoxing_models.dart';

ChaoxingWork _work({
  String id = 'w',
  String title = '作业',
  String status = '未交',
  String timing = '',
  String? detailTiming,
  DateTime? readAt,
  DateTime? mutedAt,
}) {
  return ChaoxingWork(
    id: id,
    title: title,
    status: status,
    timing: timing,
    detailTiming: detailTiming,
    readAt: readAt,
    mutedAt: mutedAt,
  );
}

void main() {
  final now = DateTime.parse('2026-11-03T10:00:00+08:00');

  group('workSection', () {
    test('separates overdue, soon, later, undated and completed work', () {
      expect(
        workSection(_work(timing: '截止时间：2026-11-01 23:59'), now),
        WorkSection.overdue,
      );
      expect(
        workSection(_work(timing: '截止时间：2026-11-05 23:59'), now),
        WorkSection.soon,
      );
      expect(
        workSection(_work(timing: '截止时间：2026-12-20 23:59'), now),
        WorkSection.later,
      );
      expect(workSection(_work(timing: '剩余2天'), now), WorkSection.undated);
      expect(workSection(_work(), now), WorkSection.undated);
      expect(
        workSection(_work(status: '已提交', timing: '截止时间：2026-11-01 23:59'), now),
        WorkSection.done,
      );
      for (final status in <String>['待批阅', 'To be marked', 'reviewd']) {
        expect(
          workSection(_work(status: status, timing: '剩余2天'), now),
          WorkSection.done,
          reason: status,
        );
      }
    });

    test(
      'uses inclusive boundaries for the due instant and the 7-day window',
      () {
        expect(
          workSection(_work(timing: '截止时间：2026-11-03 10:00'), now),
          WorkSection.soon,
        );
        expect(
          workSection(_work(timing: '截止时间：2026-11-03 09:59'), now),
          WorkSection.overdue,
        );
        expect(
          workSection(_work(timing: '截止时间：2026-11-10 10:00'), now),
          WorkSection.soon,
        );
        expect(
          workSection(_work(timing: '截止时间：2026-11-10 10:01'), now),
          WorkSection.later,
        );
        expect(
          workSection(_work(timing: '截止日期：2026-11-03'), now),
          WorkSection.soon,
        );
      },
    );

    test('ignored work wins over completed work', () {
      final muted = _work(
        status: '已提交',
        mutedAt: DateTime.utc(2026, 11, 3),
        timing: '截止时间：2026-11-05 23:59',
      );
      expect(workSection(muted, now), WorkSection.ignored);
    });

    test('read marks never move work into the completed section', () {
      final read = _work(
        readAt: DateTime.utc(2026, 11, 3),
        timing: '截止时间：2026-11-05 23:59',
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
        _work(id: '1', title: '无时间', timing: '剩余2天'),
        _work(id: '2', title: '之后', timing: '截止时间：2026-12-20 23:59'),
        _work(id: '3', title: '逾期', timing: '截止时间：2026-11-01 23:59'),
        _work(
          id: '4',
          title: '已完成',
          status: '已提交',
          timing: '截止时间：2026-11-02 23:59',
        ),
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
        _work(id: '1', title: '待完成', timing: '截止时间：2026-11-05 23:59'),
        _work(id: '2', title: '已忽略', mutedAt: DateTime.utc(2026, 11, 3)),
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

  group('compareWorkDue', () {
    test('sorts by the nearest deadline with undated work last', () {
      final items = [
        _work(id: '1', title: '无时间', timing: '剩余2天'),
        _work(id: '2', title: '之后', timing: '截止时间：2026-12-20 23:59'),
        _work(id: '3', title: '逾期', timing: '截止时间：2026-11-01 23:59'),
        _work(
          id: '4',
          title: '已完成',
          status: '已提交',
          timing: '截止时间：2026-11-02 23:59',
        ),
      ];
      items.sort(compareWorkDue);
      expect(items.map((item) => item.title), ['逾期', '已完成', '之后', '无时间']);
    });

    test('breaks deadline ties by title', () {
      final items = [
        _work(id: '1', title: 'B', timing: '截止时间：2026-11-05 23:59'),
        _work(id: '2', title: 'A', timing: '截止时间：2026-11-05 23:59'),
      ];
      items.sort(compareWorkDue);
      expect(items.map((item) => item.title), ['A', 'B']);
    });
  });

  group('reminderStage', () {
    final reminderNow = DateTime.parse('2026-11-03T12:00:00+08:00');
    ChaoxingWork dueTomorrow() => _work(detailTiming: '截止时间：2026-11-04 08:00');

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
        for (final value in <ChaoxingWork>[
          _work(detailTiming: '截止时间：2026-11-10 08:00'),
          _work(detailTiming: '截止时间：2026-10-01 08:00'),
          _work(detailTiming: '截止日期：2026-11-04'),
          _work(timing: '剩余2天'),
          _work(status: '已提交', detailTiming: '截止时间：2026-11-04 08:00'),
          _work(status: 'To be marked', detailTiming: '截止时间：2026-11-04 08:00'),
          _work(
            detailTiming: '截止时间：2026-11-04 08:00',
            mutedAt: DateTime.utc(2026, 11, 3),
          ),
        ]) {
          expect(reminderStage(value, reminderNow), isNull);
        }
      },
    );

    test('uses the full deadline supplied by the list itself', () {
      final listed = _work(timing: '截止时间：2026-11-04 08:00');
      expect(reminderStage(listed, reminderNow)?.stage, ReminderStage.soon);
      expect(reminderKey(listed, ReminderStage.soon), '2026-11-04T08:00|soon');
    });

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
        reminderKey(_work(timing: '截止时间：2026-11-04 09:00'), ReminderStage.soon),
        isNot(reminderKey(dueTomorrow(), ReminderStage.soon)),
      );
    });
  });
}
