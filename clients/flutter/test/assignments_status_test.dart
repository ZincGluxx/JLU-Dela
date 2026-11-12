import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/features/assignments/assignment_status.dart';
import 'package:jlu_dela/features/assignments/chaoxing_models.dart';

void main() {
  group('parseSourceStatus', () {
    test('maps the platform status vocabulary onto canonical values', () {
      expect(
        parseSourceStatus('To be Submitted'),
        ChaoxingSourceStatus.notSubmitted,
      );
      for (final value in <String>[
        '未交',
        '未提交',
        '未完成',
        'Not submitted',
        'unsubmitted',
      ]) {
        expect(
          parseSourceStatus(value),
          ChaoxingSourceStatus.notSubmitted,
          reason: value,
        );
      }
      for (final value in <String>[
        '待批阅',
        '待批改',
        '待评分',
        'To be marked',
        'pending review',
        'pending grading',
      ]) {
        expect(
          parseSourceStatus(value),
          ChaoxingSourceStatus.awaitingReview,
          reason: value,
        );
      }
      for (final value in <String>[
        '已批阅',
        '已批改',
        '已评分',
        'reviewd',
        'Reviewed',
        'graded',
        'marked',
      ]) {
        expect(
          parseSourceStatus(value),
          ChaoxingSourceStatus.marked,
          reason: value,
        );
      }
      for (final value in <String>['已交', '已提交', 'submitted']) {
        expect(
          parseSourceStatus(value),
          ChaoxingSourceStatus.submitted,
          reason: value,
        );
      }
      for (final value in <String>['已完成', 'completed']) {
        expect(
          parseSourceStatus(value),
          ChaoxingSourceStatus.completed,
          reason: value,
        );
      }
      for (final value in <String>['已退回', '未知', 'uncompleted', '已截止', '']) {
        expect(
          parseSourceStatus(value),
          ChaoxingSourceStatus.unknown,
          reason: value,
        );
      }
    });

    test('canonical codes are stable for local snapshots', () {
      expect(ChaoxingSourceStatus.values.map((status) => status.code), [
        'not_submitted',
        'awaiting_review',
        'marked',
        'submitted',
        'completed',
        'unknown',
      ]);
    });
  });

  group('sourceStatusLabel', () {
    test('shows readable labels while keeping unknown states unresolved', () {
      expect(sourceStatusLabel('To be Submitted'), '未提交');
      expect(sourceStatusLabel('To be marked'), '已提交 · 待批阅');
      expect(sourceStatusLabel('reviewd'), '已批阅');
      expect(sourceStatusLabel('已交'), '已提交');
      expect(sourceStatusLabel('Completed'), '已完成');
      expect(sourceStatusLabel('已退回'), '已退回');
      expect(sourceStatusLabel('  '), '状态待确认');
    });

    test('keeps the collapsed source text for snapshot storage', () {
      expect(sourceStatusText('  未交  '), '未交');
      expect(sourceStatusText('To be\n marked'), 'To be marked');
      expect(sourceStatusText('   '), isNull);
    });
  });

  group('isWorkCompleted', () {
    test('requires an explicit completion status', () {
      expect(isWorkCompleted('已提交'), isTrue);
      for (final value in <String>[
        '未提交',
        '未完成',
        '已截止',
        'Uncompleted',
        'Not submitted',
        '已退回',
        '',
        '未知',
      ]) {
        expect(isWorkCompleted(value), isFalse, reason: value);
      }
    });

    test('counts review-pending and graded states as submitted', () {
      for (final value in <String>[
        '待批阅',
        '待批改',
        'To be marked',
        'reviewd',
        'Reviewed',
        'Completed',
      ]) {
        expect(isWorkCompleted(value), isTrue, reason: value);
      }
    });

    test('never derives submission from local read or ignore marks', () {
      final work = ChaoxingWork(
        id: 'w',
        title: '报告',
        status: '未交',
        readAt: DateTime.utc(2026, 11, 3),
        mutedAt: DateTime.utc(2026, 11, 3),
      );
      expect(isWorkCompleted(work.status), isFalse);
      expect(sourceStatusLabel(work.status), '未提交');
    });
  });
}
