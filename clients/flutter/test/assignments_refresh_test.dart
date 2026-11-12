import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/features/assignments/chaoxing_models.dart';
import 'package:jlu_dela/features/assignments/chaoxing_parse.dart';

ChaoxingWork _work({
  String id = 'w1',
  String title = '报告',
  String status = '未交',
  String timing = '',
  String? detailTiming,
  DateTime? detailSyncedAt,
  String? detailError,
  DateTime? readAt,
  DateTime? mutedAt,
}) {
  return ChaoxingWork(
    id: id,
    title: title,
    status: status,
    timing: timing,
    detailTiming: detailTiming,
    detailSyncedAt: detailSyncedAt,
    detailError: detailError,
    readAt: readAt,
    mutedAt: mutedAt,
  );
}

void main() {
  final observedAt = DateTime.utc(2026, 11, 3, 4);

  test('retains a detail deadline across relative refreshes, but lets a newer '
      'explicit list date replace it', () {
    var snapshot = mergeWorkSnapshot(
      previous: const [],
      incoming: [_work(timing: '剩余2天')],
      observedAt: observedAt,
    );
    expect(snapshot.single.detailTiming, isNull);

    snapshot = mergeWorkSnapshot(
      previous: snapshot,
      incoming: [_work(timing: '剩余2天', detailTiming: '截止时间：2026-11-02 20:00')],
      observedAt: observedAt,
    );
    expect(snapshot.single.detailTiming, '截止时间：2026-11-02 20:00');
    final detailSyncedAt = snapshot.single.detailSyncedAt;
    expect(detailSyncedAt, observedAt);

    snapshot = mergeWorkSnapshot(
      previous: snapshot,
      incoming: [_work(timing: '剩余1天')],
      observedAt: observedAt.add(const Duration(hours: 1)),
    );
    expect(snapshot.single.detailTiming, '截止时间：2026-11-02 20:00');
    expect(snapshot.single.detailSyncedAt, detailSyncedAt);

    snapshot = mergeWorkSnapshot(
      previous: snapshot,
      incoming: [_work(timing: '截止时间：2026-11-04 21:00')],
      observedAt: observedAt.add(const Duration(hours: 2)),
    );
    expect(snapshot.single.detailTiming, isNull);
    expect(snapshot.single.detailSyncedAt, isNull);
    expect(
      snapshot.single.observedAt,
      observedAt.add(const Duration(hours: 2)),
    );
  });

  test('keeps the earlier detail time and its source note when the detail read '
      'fails', () {
    final previous = [
      _work(
        timing: '剩余2小时0分钟',
        detailTiming: '截止时间：2026-11-07 20:00',
        detailSyncedAt: observedAt,
      ),
    ];
    final merged = mergeWorkSnapshot(
      previous: previous,
      incoming: [
        _work(status: 'reviewd', timing: '', detailError: '作业详情暂时无法读取，请稍后刷新'),
      ],
      observedAt: observedAt.add(const Duration(hours: 3)),
    );
    expect(merged.single.status, 'reviewd');
    expect(merged.single.detailTiming, '截止时间：2026-11-07 20:00');
    expect(merged.single.detailSyncedAt, observedAt);
    expect(merged.single.detailError, '作业详情暂时无法读取，请稍后刷新');
  });

  test(
    'keeps personal read and ignore marks when the source refresh succeeds',
    () {
      final readAt = DateTime.utc(2026, 11, 3, 1);
      final mutedAt = DateTime.utc(2026, 11, 3, 2);
      final previous = [
        _work(status: '未交', timing: '剩余2天', readAt: readAt, mutedAt: mutedAt),
      ];
      final merged = mergeWorkSnapshot(
        previous: previous,
        incoming: [_work(status: '待批阅', timing: '剩余1天')],
        observedAt: observedAt,
      );
      expect(merged.single.status, '待批阅');
      expect(merged.single.timing, '剩余1天');
      expect(merged.single.readAt, readAt);
      expect(merged.single.mutedAt, mutedAt);
    },
  );

  test(
    'treats an unconfirmed detail deadline as a fresh detail observation',
    () {
      final timing = '截止时间：11-07 20:00（年份待确认）';
      final merged = mergeWorkSnapshot(
        previous: [
          _work(
            detailTiming: '截止时间：2026-11-07 20:00',
            detailSyncedAt: observedAt,
          ),
        ],
        incoming: [_work(timing: '剩余3天', detailTiming: timing)],
        observedAt: observedAt.add(const Duration(hours: 1)),
      );
      expect(merged.single.detailTiming, timing);
      expect(
        merged.single.detailSyncedAt,
        observedAt.add(const Duration(hours: 1)),
      );
    },
  );
}
