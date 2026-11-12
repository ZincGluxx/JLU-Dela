/// 学习通课程页、作业列表页、作业详情页的解析与快照合并。
///
/// 行为移植自 `app/src/main/chaoxing/api.ts`、`app/src/shared/chaoxing-collectors.ts`
/// 与 `app/src/main/chaoxing/test/api.test.ts`（GPL-3.0-or-later）。
library;

import 'package:jlu_dela/features/assignments/assignment_deadline.dart';
import 'package:jlu_dela/features/assignments/chaoxing_html.dart';
import 'package:jlu_dela/features/assignments/chaoxing_models.dart';

const String pageStructureChanged = '学习通页面结构无法识别，本地缓存未更新';

class ChaoxingPageFormatException implements Exception {
  const ChaoxingPageFormatException([this.message = pageStructureChanged]);

  final String message;

  @override
  String toString() => message;
}

final RegExp _emptyCourseList = RegExp('暂无课程|还没有课程');
final RegExp _emptyWorkList = RegExp('暂无作业|没有作业|未发布作业');
final RegExp _yearPrefix = RegExp(r'^20\d{2}[-/.年]');
final RegExp _whitespace = RegExp(r'\s+');

/// 课程列表页：解析课程卡片，保留来源顺序；同名课程各用来源 ID 区分。
List<ChaoxingCourse> parseCoursesPage(String html) {
  final document = HtmlParser.parse(html);
  final cards = document.querySelectorAll('.course.learnCourse');
  if (cards.isEmpty) {
    if (_emptyCourseList.hasMatch(document.text)) return const [];
    throw const ChaoxingPageFormatException();
  }
  return cards.map(_courseFromCard).toList(growable: false);
}

ChaoxingCourse _courseFromCard(HtmlNode card) {
  final link = card.querySelector('h3 a') ?? card.querySelector('a');
  final url = Uri.tryParse(link?.attr('href') ?? '');
  final courseId = url?.queryParameters['courseid'];
  final classId = url?.queryParameters['clazzid'];
  final nameNode = card.querySelector('.course-name');
  final title = nameNode?.attr('title')?.trim();
  final name = title != null && title.isNotEmpty
      ? title
      : nameNode?.text.trim() ?? '';
  if (courseId == null ||
      classId == null ||
      courseId.isEmpty ||
      classId.isEmpty ||
      name.isEmpty) {
    throw const ChaoxingPageFormatException();
  }
  return ChaoxingCourse(
    id: '$courseId:$classId',
    name: name,
    teacher: card.querySelector('.course-info .color3')?.text.trim() ?? '',
    ended: card.querySelector('.not-open-tip') != null,
  );
}

/// 作业列表页：解析每行作业，并判断是否需要再读详情页补齐截止时间。
List<ChaoxingWorkListItem> parseWorksPage(String html, {required Uri pageUrl}) {
  final document = HtmlParser.parse(html);
  final container = document.querySelector('.bottomList');
  if (container == null) throw const ChaoxingPageFormatException();
  final rows = container
      .querySelectorAll('li')
      .where((row) => row.attr('role') == 'link' && row.attr('data') != null)
      .toList(growable: false);
  if (rows.isEmpty && !_emptyWorkList.hasMatch(document.text)) {
    throw const ChaoxingPageFormatException();
  }
  return rows.map((row) => _workFromRow(row, pageUrl)).toList(growable: false);
}

ChaoxingWorkListItem _workFromRow(HtmlNode row, Uri pageUrl) {
  final rawUrl = row.attr('data')?.trim() ?? '';
  final relative = Uri.tryParse(rawUrl);
  final resolved = relative == null ? null : pageUrl.resolveUri(relative);
  final workId = resolved?.queryParameters['workId'];
  final title =
      row.querySelector('.right-content .overHidden2')?.text.trim() ?? '';
  if (workId == null || workId.isEmpty || title.isEmpty) {
    throw const ChaoxingPageFormatException();
  }
  final timeNode = row.querySelector('.time');
  final timing = timeNode?.text.trim() ?? '';
  final titleAttr = timeNode?.attr('title')?.trim();
  final detailTiming = _listDetailTiming(titleAttr);
  final work = ChaoxingWork(
    id: workId,
    title: title,
    status: row.querySelector('.status')?.text.trim() ?? '',
    timing: timing,
    detailTiming: detailTiming,
  );
  final needsDetail =
      parseChaoxingDeadline(detailTiming ?? '') == null &&
      parseChaoxingDeadline(timing) == null;
  return ChaoxingWorkListItem(work: work, needsDetail: needsDetail);
}

String? _listDetailTiming(String? titleAttr) {
  if (titleAttr == null || titleAttr.isEmpty) return null;
  if (_yearPrefix.hasMatch(titleAttr)) return '截止时间：$titleAttr';
  return parseChaoxingDeadline(titleAttr) == null ? null : titleAttr;
}

final RegExp _deadlineRange = RegExp(
  r'(?:作答时间|起止时间|answering time|answer time)\s*[:：]?\s*(.+?)\s*'
  r'(?:至|~|～|—|\bto\b)\s*(.+)',
  caseSensitive: false,
);

final RegExp _labelledPartialDeadline = RegExp(
  r'(?:截止时间|截止日期|截止|deadline|due(?:\s+date)?|end\s*(?:time|date))\s*[:：]?\s*'
  r'((?:20\d{2}[-/.年])?\d{1,2}[-/.月]\d{1,2}日?(?:\s*\d{1,2}:\d{2}(?::\d{2})?)?)',
  caseSensitive: false,
);

final RegExp _partialDeadline = RegExp(
  r'^(\d{1,2})[-/.月](\d{1,2})日?\s+(\d{1,2}):(\d{2})(?::(\d{2}))?$',
);

final RegExp _serverCurrentTime = RegExp(
  r'''window\s*\[\s*["']currentTime["']\s*\]\s*=\s*["'](\d{13})["']''',
);

final RegExp _remainingCountdown = RegExp(
  r'^(?:剩余\s*(\d+)\s*小时\s*(\d+)\s*分钟|(\d+)\s*hours?\s*(\d+)\s*minutes?\s+left)$',
  caseSensitive: false,
);

const Set<String> _excludedClassNames = {
  'mark_table',
  'ans-cc',
  'workTextWrap',
  'question',
};

/// 解析作业详情页的截止时间行；读不到可识别的时间时返回 null。
///
/// 只输出「截止时间：…」原文，缺少年份时标记「年份待确认」，不推算日期。
String? parseWorkDetailTiming(
  String html, {
  String listTiming = '',
  Duration elapsed = Duration.zero,
}) {
  final document = HtmlParser.parse(html);
  final scriptText = document
      .querySelectorAll('script')
      .map((node) => node.text)
      .join('\n');
  final serverTime = _serverCurrentTime.firstMatch(scriptText);
  final countdown = _remainingCountdown.firstMatch(_clean(listTiming));
  final candidates = document.querySelectorAll(
    '.infoHead p, .infoHead span, p, li, label, dd, dt, td, th, span, div',
  );
  final lines = <String>[];
  for (final element in candidates) {
    if (lines.length >= 10) break;
    if (_isInvisible(element)) continue;
    final text = _clean(element.text);
    if (text.isEmpty || text.length > 180) continue;
    final rangeTimes = element.matches('.infoHead p')
        ? element.querySelectorAll('em')
        : const <HtmlNode>[];
    final range = _deadlineRange.firstMatch(text);
    final labelled = _labelledPartialDeadline.firstMatch(text);
    final deadline = _clean(
      rangeTimes.length == 2
          ? rangeTimes[1].text
          : range?.group(2) ?? labelled?.group(1) ?? '',
    );
    if (deadline.isEmpty) continue;
    final partial = _partialDeadline.firstMatch(deadline);
    final String resolved;
    if (partial != null) {
      final month = int.parse(partial.group(1)!);
      final day = int.parse(partial.group(2)!);
      final hour = int.parse(partial.group(3)!);
      final minute = int.parse(partial.group(4)!);
      final second = partial.group(5) == null
          ? null
          : int.parse(partial.group(5)!);
      if (!_isPartialDateValid(month, day, hour, minute, second)) continue;
      final year = _confirmYear(
        serverTime: serverTime,
        countdown: countdown,
        month: month,
        day: day,
        hour: hour,
        minute: minute,
        second: second,
        elapsed: elapsed,
      );
      final monthText = month.toString().padLeft(2, '0');
      final dayText = day.toString().padLeft(2, '0');
      final hourText = hour.toString().padLeft(2, '0');
      final minuteText = minute.toString().padLeft(2, '0');
      final secondText = second == null
          ? ''
          : ':${second.toString().padLeft(2, '0')}';
      resolved =
          '${year == null ? '' : '$year-'}$monthText-$dayText '
          '$hourText:$minuteText$secondText'
          '${year == null ? '（年份待确认）' : ''}';
    } else if (_yearPrefix.hasMatch(deadline)) {
      resolved = deadline;
    } else {
      continue;
    }
    final line = '截止时间：$resolved';
    if (!lines.contains(line)) lines.add(line);
  }
  return lines.isEmpty ? null : lines.join('\n');
}

bool _isPartialDateValid(
  int month,
  int day,
  int hour,
  int minute,
  int? second,
) {
  final normalizedSecond = second ?? 0;
  if (hour > 23 || minute > 59) return false;
  final value = DateTime.utc(2000, month, day, hour, minute, normalizedSecond);
  return value.year == 2000 &&
      value.month == month &&
      value.day == day &&
      value.hour == hour &&
      value.minute == minute &&
      value.second == normalizedSecond;
}

int? _confirmYear({
  required RegExpMatch? serverTime,
  required RegExpMatch? countdown,
  required int month,
  required int day,
  required int hour,
  required int minute,
  required int? second,
  required Duration elapsed,
}) {
  if (serverTime == null || countdown == null) return null;
  final minutes =
      int.parse(countdown.group(1) ?? countdown.group(3)!) * 60 +
      int.parse(countdown.group(2) ?? countdown.group(4)!);
  final expected =
      int.parse(serverTime.group(1)!) +
      minutes * Duration.millisecondsPerMinute;
  final candidateYear = DateTime.fromMillisecondsSinceEpoch(
    expected,
    isUtc: true,
  ).add(const Duration(hours: 8)).year;
  final candidate = DateTime.tryParse(
    '$candidateYear-${month.toString().padLeft(2, '0')}-'
    '${day.toString().padLeft(2, '0')}T'
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:'
    '${second == null ? '00' : second.toString().padLeft(2, '0')}+08:00',
  );
  if (candidate == null) return null;
  final difference = (candidate.toUtc().millisecondsSinceEpoch - expected)
      .abs();
  return difference <=
          Duration.millisecondsPerMinute * 2 + elapsed.inMilliseconds
      ? candidateYear
      : null;
}

bool _isInvisible(HtmlNode node) {
  HtmlNode? current = node;
  while (current != null) {
    if (_isExcludedElement(current)) return true;
    final style = (current.attr('style') ?? '')
        .replaceAll(_whitespace, '')
        .toLowerCase();
    if (style.contains('display:none') || style.contains('visibility:hidden')) {
      return true;
    }
    current = current.parent;
  }
  return _hasExcludedDescendant(node);
}

bool _isExcludedElement(HtmlNode node) {
  if (node.tag == 'script' ||
      node.tag == 'style' ||
      node.tag == 'textarea' ||
      node.tag == 'input') {
    return true;
  }
  if (node.hasAttr('hidden') || node.hasAttr('contenteditable')) return true;
  if (node.attr('aria-hidden') == 'true') return true;
  final classes = (node.attr('class') ?? '').split(_whitespace);
  return classes.any(_excludedClassNames.contains);
}

bool _hasExcludedDescendant(HtmlNode node) {
  for (final child in node.children) {
    if (_isExcludedElement(child) || _hasExcludedDescendant(child)) return true;
  }
  return false;
}

/// 把新一次来源快照合并进旧快照：明确日期覆盖旧详情时间，相对时间保留旧详情，
/// 个人标记不随刷新丢失。
List<ChaoxingWork> mergeWorkSnapshot({
  required List<ChaoxingWork> previous,
  required List<ChaoxingWork> incoming,
  required DateTime observedAt,
}) {
  final saved = {for (final work in previous) work.id: work};
  return [
    for (final work in incoming) _mergeWork(work, saved[work.id], observedAt),
  ];
}

ChaoxingWork _mergeWork(
  ChaoxingWork work,
  ChaoxingWork? saved,
  DateTime observedAt,
) {
  final detailTiming = work.detailTiming?.trim();
  final hasDetail = detailTiming != null && detailTiming.isNotEmpty;
  final listHasDeadline = parseChaoxingDeadline(work.timing) != null;
  return ChaoxingWork(
    id: work.id,
    title: work.title,
    status: work.status,
    timing: work.timing,
    detailTiming: hasDetail
        ? detailTiming
        : (listHasDeadline ? null : saved?.detailTiming),
    detailSyncedAt: hasDetail
        ? observedAt
        : (listHasDeadline ? null : saved?.detailSyncedAt),
    detailError: work.detailError,
    readAt: work.readAt ?? saved?.readAt,
    mutedAt: work.mutedAt ?? saved?.mutedAt,
    observedAt: observedAt,
  );
}

String _clean(String value) => value.replaceAll(_whitespace, ' ').trim();
