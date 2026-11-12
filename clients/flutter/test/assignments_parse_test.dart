import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/features/assignments/assignment_deadline.dart';
import 'package:jlu_dela/features/assignments/chaoxing_models.dart';
import 'package:jlu_dela/features/assignments/chaoxing_parse.dart';

String _fixture(String name) =>
    File('test/fixtures/chaoxing/$name').readAsStringSync();

void main() {
  group('parseCoursesPage', () {
    test('reads course id, name, teacher and ended flag from cards', () {
      final courses = parseCoursesPage(_fixture('courses.html'));
      expect(courses, hasLength(2));
      expect(courses[0].id, '100:200');
      expect(courses[0].name, '示例课程甲');
      expect(courses[0].teacher, '示例教师甲');
      expect(courses[0].ended, isFalse);
      expect(courses[0].label, '示例课程甲');
      expect(courses[1].id, '101:201');
      expect(courses[1].ended, isTrue);
    });

    test('keeps same-name courses separate by source id', () {
      const html = '''
        <div class="course learnCourse">
          <h3><a href="?courseid=1&clazzid=2">同名课程</a></h3>
          <p class="course-name">同名课程</p>
        </div>
        <div class="course learnCourse">
          <h3><a href="?courseid=3&clazzid=4">同名课程</a></h3>
          <p class="course-name">同名课程</p>
        </div>
      ''';
      final courses = parseCoursesPage(html);
      expect(courses.map((course) => course.id), ['1:2', '3:4']);
      expect(courses.map((course) => course.name), ['同名课程', '同名课程']);
    });

    test('shows the local remark instead of the source course name', () {
      const course = ChaoxingCourse(
        id: '1:2',
        name: 'Android软件开发',
        remark: '安卓课',
      );
      expect(course.label, '安卓课');
      expect(course.name, 'Android软件开发');
    });

    test('returns an empty list for an empty course page', () {
      expect(
        parseCoursesPage(
          '<html><body><div class="course-list">暂无课程</div></body></html>',
        ),
        isEmpty,
      );
    });

    test('rejects unknown page structure and malformed cards', () {
      expect(
        () => parseCoursesPage('<html><body>系统维护中</body></html>'),
        throwsA(isA<ChaoxingPageFormatException>()),
      );
      expect(
        () => parseCoursesPage('''
          <div class="course learnCourse">
            <h3><a href="?courseid=1">缺少班级标识</a></h3>
            <p class="course-name">缺少班级标识</p>
          </div>
        '''),
        throwsA(isA<ChaoxingPageFormatException>()),
      );
    });
  });

  group('parseWorksPage', () {
    final pageUrl = Uri.parse(
      'https://mooc1.chaoxing.com/mooc2/work/list?courseId=100',
    );

    test('reads work rows and decides which need the detail page', () {
      final items = parseWorksPage(_fixture('works.html'), pageUrl: pageUrl);
      expect(items, hasLength(4));

      final first = items[0];
      expect(first.work.id, 'work-1');
      expect(first.work.title, '示例作业一');
      expect(first.work.status, '未交');
      expect(first.work.timing, '剩余1天');
      expect(first.work.detailTiming, '截止时间：2026-11-04 20:00');
      expect(first.needsDetail, isFalse);

      expect(items[1].work.status, 'To be marked');
      expect(items[1].work.detailTiming, isNull);
      expect(items[1].needsDetail, isTrue);

      expect(items[2].work.detailTiming, isNull);
      expect(items[2].needsDetail, isTrue);

      expect(items[3].work.id, 'work-4');
      expect(items[3].work.title, '示例作业四');
      expect(items[3].work.status, '');
      expect(items[3].work.timing, '截止日期：2026-11-09');
      expect(items[3].needsDetail, isFalse);
    });

    test(
      'does not ask for detail when the list already has a full deadline',
      () {
        final items = parseWorksPage('''
        <div class="bottomList">
          <li role="link" data="?workId=w1">
            <div class="right-content"><p class="overHidden2">列表带截止</p></div>
            <span class="status">未交</span>
            <span class="time">截止时间：2026-11-04 08:00</span>
          </li>
        </div>
        ''', pageUrl: pageUrl);
        expect(items.single.needsDetail, isFalse);
      },
    );

    test('returns an empty list for an empty work list', () {
      expect(
        parseWorksPage(
          '<html><body><div class="bottomList">暂无作业</div></body></html>',
          pageUrl: pageUrl,
        ),
        isEmpty,
      );
    });

    test('rejects unknown structure and rows without a work id', () {
      expect(
        () =>
            parseWorksPage('<html><body>系统维护中</body></html>', pageUrl: pageUrl),
        throwsA(isA<ChaoxingPageFormatException>()),
      );
      expect(
        () => parseWorksPage(
          '<div class="bottomList"><li role="link" data="/task"><span class="status">未交</span></li></div>',
          pageUrl: pageUrl,
        ),
        throwsA(isA<ChaoxingPageFormatException>()),
      );
    });
  });

  group('parseWorkDetailTiming', () {
    test('reads the labelled deadline from the detail page', () {
      final timing = parseWorkDetailTiming(_fixture('work_detail.html'));
      expect(timing, '截止时间：2026-11-04 20:00');
      expect(
        parseChaoxingDeadline(timing!),
        const DueDeadline(date: '2026-11-04', time: '20:00'),
      );
    });

    test('reads the end of an answering-time range', () {
      const html = '''
        <div class="infoHead">
          <p><em>开始时间：2026-11-01 08:00</em> 至 <em>2026-11-05 23:59</em></p>
        </div>
      ''';
      expect(parseWorkDetailTiming(html), '截止时间：2026-11-05 23:59');
    });

    test('marks partial dates without a year as unconfirmed', () {
      final timing = parseWorkDetailTiming('<p>截止时间：11-07 20:00</p>');
      expect(timing, '截止时间：11-07 20:00（年份待确认）');
      expect(parseChaoxingDeadline(timing!), isNull);
    });

    test('confirms the year from server time plus the countdown', () {
      final now = DateTime.parse('2026-11-07T18:00:00+08:00');
      final html =
          '''
        <script>window["currentTime"] = "${now.millisecondsSinceEpoch}";</script>
        <p>截止时间：11-07 20:00</p>
      ''';
      expect(
        parseWorkDetailTiming(html, listTiming: '剩余2小时0分钟'),
        '截止时间：2026-11-07 20:00',
      );
    });

    test('confirms a year that rolls over into the next year', () {
      final now = DateTime.parse('2026-12-31T23:30:00+08:00');
      final html =
          '''
        <script>window["currentTime"] = "${now.millisecondsSinceEpoch}";</script>
        <p>截止时间：01-01 01:30</p>
      ''';
      expect(
        parseWorkDetailTiming(html, listTiming: '剩余2小时0分钟'),
        '截止时间：2027-01-01 01:30',
      );
    });

    test('does not confirm a year when the countdown contradicts it', () {
      final now = DateTime.parse('2026-12-31T23:30:00+08:00');
      final html =
          '''
        <script>window["currentTime"] = "${now.millisecondsSinceEpoch}";</script>
        <p>截止时间：01-01 01:30</p>
      ''';
      expect(
        parseWorkDetailTiming(html, listTiming: '剩余5小时0分钟'),
        '截止时间：01-01 01:30（年份待确认）',
      );
    });

    test('ignores impossible partial dates and out-of-range times', () {
      expect(parseWorkDetailTiming('<p>截止时间：02-30 12:00</p>'), isNull);
      expect(parseWorkDetailTiming('<p>截止时间：11-07 24:00</p>'), isNull);
      expect(parseWorkDetailTiming('<p>截止时间：13-01 12:00</p>'), isNull);
    });

    test(
      'keeps an invalid full date as source text for the deadline parser',
      () {
        const html = '<p>截止时间：2026-02-30 12:00</p>';
        final timing = parseWorkDetailTiming(html);
        expect(timing, '截止时间：2026-02-30 12:00');
        expect(parseChaoxingDeadline(timing!), isNull);
      },
    );

    test('ignores hidden, script, question and answer blocks', () {
      const html = '''
        <div class="question"><p>题干预置截止时间：2026-12-01 10:00</p></div>
        <div class="ans-cc"><p>答案里的截止时间：2026-12-01 10:00</p></div>
        <script>document.write('脚本里的截止时间：2026-12-02 10:00');</script>
        <p hidden>隐藏的截止时间：2026-12-03 10:00</p>
        <textarea>备注里的截止时间：2026-12-04 10:00</textarea>
        <p>截止时间：2026-11-04 20:00</p>
      ''';
      expect(parseWorkDetailTiming(html), '截止时间：2026-11-04 20:00');
    });

    test('returns null when the page has no readable deadline', () {
      expect(parseWorkDetailTiming('<html><body>维护中</body></html>'), isNull);
      expect(parseWorkDetailTiming('<p>截止时间：待通知</p>'), isNull);
    });
  });
}
