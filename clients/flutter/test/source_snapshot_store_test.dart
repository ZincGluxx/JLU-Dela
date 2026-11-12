import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_executor.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/source_snapshot_store.dart';

import 'support/local_database_test_support.dart';

void main() {
  late LocalDatabase database;
  late SourceSnapshotStore snapshots;

  setUp(() async {
    database = await openTestDatabase();
    snapshots = SourceSnapshotStore(database, 'user-a');
  });

  tearDown(() => database.close());

  test('a failure keeps the last success and records the error', () async {
    final successAt = DateTime.utc(2026, 11, 10, 8);
    await snapshots.recordSuccess(
      SourceKind.chaoxing,
      'assignments',
      observedAt: successAt,
    );

    await snapshots.recordFailure(
      SourceKind.chaoxing,
      'assignments',
      attemptedAt: DateTime.utc(2026, 11, 11, 9),
      code: SourceErrorCodes.sourceNetwork,
      message: '断网',
    );

    final snapshot = await snapshots.read(SourceKind.chaoxing, 'assignments');
    expect(snapshot.lastSuccessAtUtc, successAt);
    expect(snapshot.lastAttemptAtUtc, DateTime.utc(2026, 11, 11, 9));
    expect(snapshot.lastErrorCode, SourceErrorCodes.sourceNetwork);
    expect(snapshot.lastErrorMessage, '断网');
    expect(snapshot.hasCachedData, isTrue);
  });

  test('an unscoped snapshot is empty', () async {
    final snapshot = await snapshots.read(SourceKind.jluIedu, 'timetable');
    expect(snapshot.lastSuccessAtUtc, isNull);
    expect(snapshot.lastAttemptAtUtc, isNull);
    expect(snapshot.hasCachedData, isFalse);
  });

  test('a success clears the previous error', () async {
    await snapshots.recordFailure(
      SourceKind.jluOa,
      'notices',
      attemptedAt: DateTime.utc(2026, 11, 10),
      code: SourceErrorCodes.sourceTimeout,
    );
    await snapshots.recordSuccess(
      SourceKind.jluOa,
      'notices',
      observedAt: DateTime.utc(2026, 11, 11),
    );

    final snapshot = await snapshots.read(SourceKind.jluOa, 'notices');
    expect(snapshot.lastErrorCode, isNull);
    expect(snapshot.lastSuccessAtUtc, DateTime.utc(2026, 11, 11));
  });

  test('scope keys are isolated', () async {
    await snapshots.recordSuccess(
      SourceKind.chaoxing,
      'materials',
      scopeKey: 'course-a',
      observedAt: DateTime.utc(2026, 11, 11),
    );
    final courseB = await snapshots.read(
      SourceKind.chaoxing,
      'materials',
      scopeKey: 'course-b',
    );
    expect(courseB.hasCachedData, isFalse);
    expect(await snapshots.list(), hasLength(1));
  });

  test('the executor persists data and records success', () async {
    final executor = SourceExecutor(
      snapshots: snapshots,
      now: () => DateTime.utc(2026, 11, 12, 10),
    );
    final persisted = <String>[];

    final result = await executor.run<List<String>>(
      source: SourceKind.jluIedu,
      resource: 'courses',
      fetch: () async => ['课程一'],
      persist: (value, observedAt) async => persisted.addAll(value),
    );

    expect(result, isA<SourceSuccess<List<String>>>());
    expect(persisted, ['课程一']);
    final snapshot = await snapshots.read(SourceKind.jluIedu, 'courses');
    expect(snapshot.lastSuccessAtUtc, DateTime.utc(2026, 11, 12, 10));
  });

  test('the executor records failures without persisting', () async {
    await snapshots.recordSuccess(
      SourceKind.chaoxing,
      'assignments',
      observedAt: DateTime.utc(2026, 11, 10),
    );
    final executor = SourceExecutor(
      snapshots: snapshots,
      now: () => DateTime.utc(2026, 11, 12, 10),
    );
    var persisted = false;

    final result = await executor.run<List<String>>(
      source: SourceKind.chaoxing,
      resource: 'assignments',
      fetch: () async => throw const SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceAuthRequired,
          message: '需要重新登录',
        ),
      ),
      persist: (value, observedAt) async => persisted = true,
    );

    expect(result, isA<SourceFailed<List<String>>>());
    final failed = result as SourceFailed<List<String>>;
    expect(failed.failure.code, SourceErrorCodes.sourceAuthRequired);
    expect(failed.failure.source, SourceKind.chaoxing);
    expect(failed.hasCachedData, isTrue);
    expect(persisted, isFalse);
    expect(failed.snapshot.lastSuccessAtUtc, DateTime.utc(2026, 11, 10));
  });

  test('network failures are retryable and timeouts map to their code', () {
    final timeout = sourceFailureOf(
      TimeoutException('late'),
      source: SourceKind.jluIedu,
    );
    expect(timeout.code, SourceErrorCodes.sourceTimeout);
    expect(timeout.retryable, isTrue);
    expect(timeout.source, SourceKind.jluIedu);
  });
}
