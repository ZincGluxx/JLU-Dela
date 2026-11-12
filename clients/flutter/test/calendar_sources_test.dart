import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/features/planner/calendar_sources.dart';
import 'package:jlu_dela/features/planner/calendar_time.dart';

void main() {
  final successAt = DateTime.utc(2026, 11, 12, 2);
  final failureAt = DateTime.utc(2026, 11, 12, 3);

  CalendarSourceStatus status({
    required bool connected,
    List<SourceSnapshot> snapshots = const [],
  }) {
    return CalendarSourceStatus.from(
      source: SourceKind.chaoxing,
      connected: connected,
      snapshots: snapshots,
    );
  }

  test('未登录来源不展示同步时间', () {
    final value = status(
      connected: false,
      snapshots: [
        SourceSnapshot(
          source: SourceKind.chaoxing,
          resource: 'assignments',
          lastSuccessAtUtc: successAt,
        ),
      ],
    );
    expect(value.summary, '学习通：未登录来源');
    expect(value.needsLogin, isTrue);
    expect(value.loginLabel, '登录学习通');
  });

  test('已登录但从未同步', () {
    expect(status(connected: true).summary, '学习通：已登录 · 尚未同步');
  });

  test('上次成功显示北京时间', () {
    final value = status(
      connected: true,
      snapshots: [
        SourceSnapshot(
          source: SourceKind.chaoxing,
          resource: 'assignments',
          lastSuccessAtUtc: successAt,
        ),
      ],
    );
    expect(value.summary, '学习通：上次成功 ${calendarTimestampLabel(successAt)}');
  });

  test('失败晚于成功时标记旧缓存仍在', () {
    final value = status(
      connected: true,
      snapshots: [
        SourceSnapshot(
          source: SourceKind.chaoxing,
          resource: 'assignments',
          lastSuccessAtUtc: successAt,
        ),
        SourceSnapshot(
          source: SourceKind.chaoxing,
          resource: 'assignments',
          lastAttemptAtUtc: failureAt,
          lastErrorCode: 'SOURCE_NETWORK',
          lastErrorMessage: '网络不可用',
        ),
      ],
    );
    expect(
      value.summary,
      '学习通：上次失败（旧缓存仍在 · 上次成功 '
      '${calendarTimestampLabel(successAt)}）',
    );
  });

  test('从未成功过的失败如实说明', () {
    final value = status(
      connected: true,
      snapshots: [
        SourceSnapshot(
          source: SourceKind.chaoxing,
          resource: 'assignments',
          lastAttemptAtUtc: failureAt,
          lastErrorCode: 'SOURCE_AUTH_REQUIRED',
        ),
      ],
    );
    expect(value.summary, '学习通：上次失败（未同步成功过）');
  });

  test('成功后清理旧错误按成功展示', () {
    final value = status(
      connected: true,
      snapshots: [
        SourceSnapshot(
          source: SourceKind.chaoxing,
          resource: 'assignments',
          lastAttemptAtUtc: failureAt,
          lastSuccessAtUtc: successAt,
          lastErrorCode: null,
        ),
      ],
    );
    expect(value.summary, '学习通：上次成功 ${calendarTimestampLabel(successAt)}');
  });

  test('其他来源的快照不混入', () {
    final value = CalendarSourceStatus.from(
      source: SourceKind.jluIedu,
      connected: true,
      snapshots: [
        SourceSnapshot(
          source: SourceKind.chaoxing,
          resource: 'assignments',
          lastSuccessAtUtc: successAt,
        ),
      ],
    );
    expect(value.summary, '教务系统：已登录 · 尚未同步');
  });
}
