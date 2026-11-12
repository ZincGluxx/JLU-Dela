import 'teaching_week_pattern.dart';

const String _fieldMismatch = '吉大课表字段与预期不一致，本地课表未更新';
const String _missingData = '吉大教务响应缺少有效课表数据';
const String _unrecognizedPeriodTime = '教务节次时间无法识别，本地课表未更新';
const String _weekFormat = '教务课表的教学周格式无法识别';

/// 教务响应无法解析时抛出，消息为可直接展示的中文原因。
class JluParseException implements Exception {
  const JluParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 一条教务课表记录，周次、节次与教师标识已规范化。
///
/// 字段沿用旧 Electron 实现的语义；[sourceId] 只保证本次解析内唯一，
/// 数据库唯一键在 TeachingStore 中单独定义。
class JluLesson {
  JluLesson({
    required this.sourceId,
    required this.kbId,
    required this.courseCode,
    required this.courseName,
    required this.className,
    required this.teacher,
    required this.campus,
    required this.classroom,
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    required this.periodsText,
    required this.weeksText,
    required List<int> weekNumbers,
    required this.credits,
    required this.note,
    required this.startMinute,
    required this.endMinute,
  }) : weekNumbers = List.unmodifiable(weekNumbers);

  final String sourceId;
  final String kbId;
  final String courseCode;
  final String courseName;
  final String? className;
  final String? teacher;
  final String? campus;
  final String? classroom;
  final int weekday;
  final int startPeriod;
  final int endPeriod;
  final String periodsText;
  final String weeksText;
  final List<int> weekNumbers;
  final double? credits;
  final String? note;
  final int startMinute;
  final int endMinute;
}

/// 一学期已规范化的课表与校历信息。
class JluTimetable {
  JluTimetable({
    required this.semesterStart,
    required this.totalWeeks,
    required List<JluLesson> lessons,
    required List<String> warnings,
  }) : lessons = List.unmodifiable(lessons),
       warnings = List.unmodifiable(warnings);

  final String semesterStart;
  final int? totalWeeks;
  final List<JluLesson> lessons;
  final List<String> warnings;
}

/// 校验 EMAP 响应信封并取出指定模块的行。
///
/// 吉大未分页查询以 `totalSize = -1` 表示未统计总数，此时行仍有效；
/// 若声明了分页大小且行数达到分页大小，则无法判断是否被截断，按不完整处理。
List<Object?> parseEmapRows(Object? payload, String key) {
  final structureError = '吉大教务响应结构无法识别（$key），本地课表未更新';
  final envelope = _object(payload, structureError);
  if (envelope.containsKey('code')) {
    final code = envelope['code'];
    if (code is! String && code is! num) {
      throw JluParseException(structureError);
    }
    if (code.toString() != '0' && code.toString() != '200') {
      throw JluParseException(structureError);
    }
  }
  final datas = _object(envelope['datas'], structureError);
  final missingError = '$_missingData（$key），本地课表未更新';
  final block = _object(datas[key], missingError);
  final rows = _array(block['rows'], missingError);
  final totalSize = _optionalInteger(
    block,
    'totalSize',
    min: -1,
    message: missingError,
  );
  final pageSize = _optionalInteger(
    block,
    'pageSize',
    min: 0,
    message: missingError,
  );
  if (totalSize != null && totalSize > rows.length) {
    throw const JluParseException('吉大教务返回的数据不完整，本地课表未更新');
  }
  if ((totalSize == null || totalSize == -1) &&
      pageSize != null &&
      pageSize > 0 &&
      rows.length >= pageSize) {
    throw const JluParseException('吉大教务返回了未统计总数的分页数据，本地课表未更新');
  }
  return List<Object?>.unmodifiable(rows);
}

/// 校验当前学期响应并返回形如 `2026-2027-1` 的学期代码。
String parseCurrentJluSemester(Object? rows) {
  const message = '教务当前学期格式无法识别，本地课表未更新';
  final list = _array(rows, message);
  if (list.isEmpty) throw const JluParseException(message);
  final row = _object(list.first, message);
  final semester = _text(row['DM'], message);
  if (!RegExp(r'^\d{4}-\d{4}-[123]$').hasMatch(semester)) {
    throw const JluParseException(message);
  }
  return semester;
}

/// 旧版教务 `SKZC` 位掩码：第 n 位为 `1` 表示第 n 周上课。
List<int> jluWeekNumbers(String value) {
  if (!RegExp(r'^[01]{1,64}$').hasMatch(value)) {
    throw const JluParseException(_weekFormat);
  }
  return <int>[
    for (var index = 0; index < value.length; index++)
      if (value[index] == '1') index + 1,
  ];
}

/// 解析 `1-6,9周(单)` 一类的教学周文本。
///
/// 语法与校验复用 #20 合并后的 [parseTeachingWeekPattern]；
/// 这里把英文 [FormatException] 转成可展示的中文原因。
List<int> parseJluWeekText(String value, {required int totalWeeks}) {
  if (totalWeeks < 1) {
    throw const JluParseException('教务校历总周数无效，无法校验教学周');
  }
  try {
    return parseTeachingWeekPattern(value, totalWeeks: totalWeeks);
  } on FormatException catch (error) {
    final reason = switch (error.message) {
      'Teaching weeks are outside the valid range' => '超出校历总周数（$totalWeeks 周）',
      'Teaching week pattern selects no weeks' => '没有选中任何周次',
      _ => '格式无法识别',
    };
    throw JluParseException('教务教学周$reason：$value');
  }
}

/// 优先按教务位掩码解析，其次按周次文本解析；有校历总周数时校验越界。
List<int> jluWeekSelector(String value, {int? totalWeeks}) {
  final trimmed = value.trim();
  if (RegExp(r'^[01]{1,64}$').hasMatch(trimmed)) {
    final weeks = jluWeekNumbers(trimmed);
    if (totalWeeks != null && weeks.isNotEmpty && weeks.last > totalWeeks) {
      throw JluParseException('教务课表的教学周超出校历总周数（$totalWeeks 周），本地课表未更新');
    }
    return weeks;
  }
  if (totalWeeks == null) {
    throw const JluParseException('$_weekFormat，或校历缺少总周数无法校验');
  }
  return parseJluWeekText(trimmed, totalWeeks: totalWeeks);
}

/// 把旧版 `normalizeJluTimetable` 的相对周次课表规范化为可持久化的记录。
///
/// 原课次按 `SKZC` 展开；调停课按旧版顺序应用：倒序处理，缺省新时间视为停课，
/// 带新时间视为调课。无法匹配原课程的调停课与未排定课程只收集为警告。
JluTimetable normalizeJluTimetable({
  required Object? courses,
  required Object? periods,
  required Object? calendar,
  Object? changes = const <Object?>[],
  Object? unscheduled = const <Object?>[],
}) {
  final courseRows = _array(
    courses,
    _fieldMismatch,
  ).map(_CourseRow.fromJson).toList(growable: false);
  final periodRows = _array(
    periods,
    _fieldMismatch,
  ).map(_PeriodRow.fromJson).toList(growable: false);
  final calendarRows = _array(
    calendar,
    _fieldMismatch,
  ).map(_CalendarRow.fromJson).toList(growable: false);
  final changeRows = _array(
    changes,
    _fieldMismatch,
  ).map(_ChangeRow.fromJson).toList(growable: false);
  final unscheduledRows = _array(unscheduled, _fieldMismatch);

  final semesterStart = _semesterStart(calendarRows);
  final totalWeeks = calendarRows.isEmpty
      ? null
      : _totalWeeks(calendarRows.first.totalWeeksText);
  final availablePeriods = _availablePeriods(periodRows);

  final warnings = <String>[
    if (unscheduledRows.isNotEmpty)
      '教务另有 ${unscheduledRows.length} 条未排定时间的课程，未计入日历',
  ];
  final lessons = <_MutableLesson>[];
  for (var index = 0; index < courseRows.length; index++) {
    final row = courseRows[index];
    final campus = row.campusCode.isEmpty ? row.campusName : row.campusCode;
    final times = _periodTimes(
      availablePeriods,
      campus,
      row.startPeriod,
      row.endPeriod,
    );
    lessons.add(
      _MutableLesson(
        sourceId:
            '${_firstNonEmpty([row.kbId, row.classId, row.courseCode, row.courseName])}:$index',
        kbId: row.kbId,
        campusCode: campus,
        courseCode: row.courseCode,
        courseName: row.courseName,
        className: row.className.isEmpty ? null : row.className,
        teacher: _teacher(row.teacherText),
        campus: _firstOrNull([row.campusDisplay, row.campusName]),
        classroom: row.classroom.isEmpty ? null : row.classroom,
        weekday: row.weekday,
        startPeriod: row.startPeriod,
        endPeriod: row.endPeriod,
        periodsText: '${row.startPeriod}–${row.endPeriod}节',
        weekNumbers: jluWeekSelector(row.weekSelector, totalWeeks: totalWeeks),
        credits: _credits(row.creditsText),
        note: null,
        startMinute: times.startMinute,
        endMinute: times.endMinute,
      ),
    );
  }

  for (var index = 0; index < changeRows.length; index++) {
    final change = changeRows[changeRows.length - 1 - index];
    final affected = lessons.where((lesson) => lesson.kbId == change.kbId);
    if (affected.isEmpty) {
      warnings.add('有调停课记录未匹配到原课程，请对照教务原课表核查');
      continue;
    }
    final cancelledWeeks = jluWeekSelector(
      change.weekSelector,
      totalWeeks: totalWeeks,
    );
    final hasNewTime = [
      change.newWeekSelector,
      change.newWeekdayText,
      change.newStartPeriodText,
      change.newEndPeriodText,
    ].any((value) => value.isNotEmpty);
    if (!hasNewTime) {
      for (final lesson in affected) {
        lesson.weekNumbers.removeWhere(cancelledWeeks.contains);
      }
      continue;
    }

    const changeTimeError = '调课记录缺少新时间，本地课表未更新';
    final newWeekday = _tryPositiveInteger(change.newWeekdayText, max: 7);
    final newStartPeriod = _tryPositiveInteger(
      change.newStartPeriodText,
      max: 30,
    );
    final newEndPeriod = _tryPositiveInteger(change.newEndPeriodText, max: 30);
    if (newWeekday == null ||
        newStartPeriod == null ||
        newEndPeriod == null ||
        newEndPeriod < newStartPeriod ||
        change.newWeekSelector.isEmpty) {
      throw const JluParseException(changeTimeError);
    }

    final first = affected.first;
    final times = _periodTimes(
      availablePeriods,
      first.campusCode,
      newStartPeriod,
      newEndPeriod,
    );
    final movedWeeks = jluWeekSelector(
      change.newWeekSelector,
      totalWeeks: totalWeeks,
    );
    final classroom = _firstOrNull([
      change.newClassroom,
      change.classroom,
      first.classroom,
    ]);
    final teacher =
        _teacher(change.newTeacher) ??
        _teacher(change.originalTeacher) ??
        first.teacher;
    for (final lesson in affected) {
      lesson.weekNumbers.removeWhere(cancelledWeeks.contains);
    }
    _MutableLesson? existing;
    for (final lesson in lessons) {
      if (lesson.kbId == change.kbId &&
          lesson.weekday == newWeekday &&
          lesson.startPeriod == newStartPeriod &&
          lesson.endPeriod == newEndPeriod &&
          lesson.classroom == classroom &&
          lesson.teacher == teacher) {
        existing = lesson;
        break;
      }
    }
    if (existing != null) {
      existing.weekNumbers = <int>{
        ...existing.weekNumbers,
        ...movedWeeks,
      }.toList()..sort();
    } else {
      lessons.add(
        _MutableLesson(
          sourceId: '${first.sourceId}:change:$index',
          kbId: first.kbId,
          campusCode: first.campusCode,
          courseCode: first.courseCode,
          courseName: first.courseName,
          className: first.className,
          teacher: teacher,
          campus: first.campus,
          classroom: classroom,
          weekday: newWeekday,
          startPeriod: newStartPeriod,
          endPeriod: newEndPeriod,
          periodsText: '$newStartPeriod–$newEndPeriod节',
          weekNumbers: movedWeeks,
          credits: first.credits,
          note: '教务调课',
          startMinute: times.startMinute,
          endMinute: times.endMinute,
        ),
      );
    }
  }

  final normalized = <JluLesson>[
    for (final lesson in lessons)
      if (lesson.weekNumbers.isNotEmpty)
        JluLesson(
          sourceId: lesson.sourceId,
          kbId: lesson.kbId,
          courseCode: lesson.courseCode,
          courseName: lesson.courseName,
          className: lesson.className,
          teacher: lesson.teacher,
          campus: lesson.campus,
          classroom: lesson.classroom,
          weekday: lesson.weekday,
          startPeriod: lesson.startPeriod,
          endPeriod: lesson.endPeriod,
          periodsText: lesson.periodsText,
          weeksText: '${lesson.weekNumbers.join('、')}周',
          weekNumbers: lesson.weekNumbers,
          credits: lesson.credits,
          note: lesson.note,
          startMinute: lesson.startMinute,
          endMinute: lesson.endMinute,
        ),
  ];
  return JluTimetable(
    semesterStart: semesterStart,
    totalWeeks: totalWeeks,
    lessons: normalized,
    warnings: warnings.toSet().toList(),
  );
}

class _CourseRow {
  const _CourseRow({
    required this.kbId,
    required this.classId,
    required this.courseCode,
    required this.courseName,
    required this.teacherText,
    required this.classroom,
    required this.className,
    required this.campusName,
    required this.campusCode,
    required this.campusDisplay,
    required this.creditsText,
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    required this.weekSelector,
  });

  factory _CourseRow.fromJson(Object? value) {
    final row = _object(value, _fieldMismatch);
    final courseName = _text(row['KCM'], _fieldMismatch);
    if (courseName.isEmpty) throw const JluParseException(_fieldMismatch);
    final startPeriod = _positiveInteger(row['KSJC'], _fieldMismatch, max: 30);
    final endPeriod = _positiveInteger(row['JSJC'], _fieldMismatch, max: 30);
    if (endPeriod < startPeriod) throw const JluParseException(_fieldMismatch);
    return _CourseRow(
      kbId: _text(row['KBID'], _fieldMismatch),
      classId: _text(row['JXBID'], _fieldMismatch),
      courseCode: _text(row['KCH'], _fieldMismatch),
      courseName: courseName,
      teacherText: _text(row['SKJS'], _fieldMismatch),
      classroom: _text(row['JASMC'], _fieldMismatch),
      className: _text(row['JXBMC'], _fieldMismatch),
      campusName: _text(row['XXXQ'], _fieldMismatch),
      campusCode: _text(row['XXXQDM'], _fieldMismatch),
      campusDisplay: _text(row['XXXQDM_DISPLAY'], _fieldMismatch),
      creditsText: _text(row['XF'], _fieldMismatch),
      weekday: _positiveInteger(row['SKXQ'], _fieldMismatch, max: 7),
      startPeriod: startPeriod,
      endPeriod: endPeriod,
      weekSelector: _text(row['SKZC'], _fieldMismatch),
    );
  }

  final String kbId;
  final String classId;
  final String courseCode;
  final String courseName;
  final String teacherText;
  final String classroom;
  final String className;
  final String campusName;
  final String campusCode;
  final String campusDisplay;
  final String creditsText;
  final int weekday;
  final int startPeriod;
  final int endPeriod;
  final String weekSelector;
}

class _PeriodRow {
  const _PeriodRow({
    required this.period,
    required this.campus,
    required this.startTime,
    required this.endTime,
    required this.enabled,
  });

  factory _PeriodRow.fromJson(Object? value) {
    final row = _object(value, _fieldMismatch);
    return _PeriodRow(
      period: _positiveInteger(row['DM'], _fieldMismatch, max: 30),
      campus: _text(row['XXXQ'], _fieldMismatch),
      startTime: _text(row['KSSJ'], _fieldMismatch),
      endTime: _text(row['JSSJ'], _fieldMismatch),
      enabled: _text(row['SFSY'], _fieldMismatch),
    );
  }

  final int period;
  final String campus;
  final String startTime;
  final String endTime;
  final String enabled;
}

class _CalendarRow {
  const _CalendarRow({required this.startDate, required this.totalWeeksText});

  factory _CalendarRow.fromJson(Object? value) {
    final row = _object(value, _fieldMismatch);
    return _CalendarRow(
      startDate: _text(row['XQKSRQ'], _fieldMismatch),
      totalWeeksText: _text(row['ZZC'], _fieldMismatch),
    );
  }

  final String startDate;
  final String totalWeeksText;
}

class _ChangeRow {
  const _ChangeRow({
    required this.kbId,
    required this.weekSelector,
    required this.newWeekSelector,
    required this.newWeekdayText,
    required this.newStartPeriodText,
    required this.newEndPeriodText,
    required this.newClassroom,
    required this.classroom,
    required this.newTeacher,
    required this.originalTeacher,
  });

  factory _ChangeRow.fromJson(Object? value) {
    final row = _object(value, _fieldMismatch);
    final kbId = _text(row['KBID'], _fieldMismatch);
    if (kbId.isEmpty) throw const JluParseException(_fieldMismatch);
    return _ChangeRow(
      kbId: kbId,
      weekSelector: _text(row['SKZC'], _fieldMismatch),
      newWeekSelector: _text(row['XSKZC'], _fieldMismatch),
      newWeekdayText: _text(row['XSKXQ'], _fieldMismatch),
      newStartPeriodText: _text(row['XKSJC'], _fieldMismatch),
      newEndPeriodText: _text(row['XJSJC'], _fieldMismatch),
      newClassroom: _text(row['XJASMC'], _fieldMismatch),
      classroom: _text(row['JASMC'], _fieldMismatch),
      newTeacher: _text(row['XSKJS'], _fieldMismatch),
      originalTeacher: _text(row['YSKJS'], _fieldMismatch),
    );
  }

  final String kbId;
  final String weekSelector;
  final String newWeekSelector;
  final String newWeekdayText;
  final String newStartPeriodText;
  final String newEndPeriodText;
  final String newClassroom;
  final String classroom;
  final String newTeacher;
  final String originalTeacher;
}

class _PeriodTime {
  const _PeriodTime({
    required this.period,
    required this.campus,
    required this.startMinute,
    required this.endMinute,
  });

  final int period;
  final String campus;
  final int startMinute;
  final int endMinute;
}

class _MutableLesson {
  _MutableLesson({
    required this.sourceId,
    required this.kbId,
    required this.campusCode,
    required this.courseCode,
    required this.courseName,
    required this.className,
    required this.teacher,
    required this.campus,
    required this.classroom,
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    required this.periodsText,
    required this.weekNumbers,
    required this.credits,
    required this.note,
    required this.startMinute,
    required this.endMinute,
  });

  final String sourceId;
  final String kbId;
  final String campusCode;
  final String courseCode;
  final String courseName;
  final String? className;
  String? teacher;
  final String? campus;
  String? classroom;
  final int weekday;
  final int startPeriod;
  final int endPeriod;
  final String periodsText;
  List<int> weekNumbers;
  final double? credits;
  String? note;
  final int startMinute;
  final int endMinute;
}

String _semesterStart(List<_CalendarRow> calendar) {
  const message = '吉大教务校历缺少有效的开学日期，本地课表未更新';
  if (calendar.isEmpty) throw const JluParseException(message);
  final raw = calendar.first.startDate;
  final start = raw.length > 10 ? raw.substring(0, 10) : raw;
  if (!_isCalendarDate(start)) throw const JluParseException(message);
  return start;
}

bool _isCalendarDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return false;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1) return false;
  return day <= DateTime.utc(year, month + 1, 0).day;
}

int? _totalWeeks(String value) {
  final parsed = double.tryParse(value);
  if (parsed == null ||
      !parsed.isFinite ||
      parsed != parsed.truncateToDouble() ||
      parsed <= 0) {
    return null;
  }
  return parsed.toInt();
}

List<_PeriodTime> _availablePeriods(List<_PeriodRow> rows) {
  const message = '吉大教务没有有效节次时间，本地课表未更新';
  final available = <_PeriodTime>[
    for (final row in rows)
      if (!const ['0', '否', 'false'].contains(row.enabled))
        _PeriodTime(
          period: row.period,
          campus: row.campus,
          startMinute: _minute(row.startTime),
          endMinute: _minute(row.endTime),
        ),
  ];
  if (available.isEmpty ||
      available.any((period) => period.endMinute <= period.startMinute)) {
    throw const JluParseException(message);
  }
  return available;
}

int _minute(String value) {
  final match =
      RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value) ??
      RegExp(r'^(\d{1,2})(\d{2})$').firstMatch(value);
  if (match == null) throw const JluParseException(_unrecognizedPeriodTime);
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) {
    throw const JluParseException(_unrecognizedPeriodTime);
  }
  return hour * 60 + minute;
}

({int startMinute, int endMinute}) _periodTimes(
  List<_PeriodTime> periods,
  String campus,
  int startPeriod,
  int endPeriod,
) {
  final matched = periods.where((period) => period.campus == campus).toList();
  final candidates = matched.isEmpty ? periods : matched;
  final starts = candidates
      .where((period) => period.period == startPeriod)
      .map((period) => period.startMinute)
      .toSet();
  final ends = candidates
      .where((period) => period.period == endPeriod)
      .map((period) => period.endMinute)
      .toSet();
  if (starts.length != 1 || ends.length != 1) {
    throw const JluParseException('课程的校区节次时间不明确，本地课表未更新');
  }
  final startMinute = starts.single;
  final endMinute = ends.single;
  if (endMinute <= startMinute) {
    throw const JluParseException('课程的上课时间无效，本地课表未更新');
  }
  return (startMinute: startMinute, endMinute: endMinute);
}

String? _teacher(String value) {
  final names = value
      .split(RegExp('[,，]'))
      .map((part) => part.split('/').first.trim())
      .where((part) => part.isNotEmpty)
      .join('、');
  return names.isEmpty ? null : names;
}

double? _credits(String value) {
  if (value.isEmpty) return null;
  final parsed = double.tryParse(value);
  return parsed != null && parsed.isFinite ? parsed : null;
}

String _firstNonEmpty(List<String> values) =>
    values.firstWhere((value) => value.isNotEmpty, orElse: () => '');

String? _firstOrNull(List<String?> values) {
  for (final value in values) {
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

Map<String, Object?> _object(Object? value, String message) {
  if (value is Map<String, Object?>) return value;
  throw JluParseException(message);
}

List<Object?> _array(Object? value, String message) {
  if (value is List) return List<Object?>.of(value);
  throw JluParseException(message);
}

String _text(Object? value, String message) {
  return switch (value) {
    null => '',
    String text => text.trim(),
    num number => number.toString().trim(),
    _ => throw JluParseException(message),
  };
}

int _positiveInteger(Object? value, String message, {int? max}) {
  final number = switch (value) {
    num value => value.toDouble(),
    String value => double.tryParse(value.trim()),
    _ => null,
  };
  if (number == null ||
      !number.isFinite ||
      number <= 0 ||
      number != number.truncateToDouble()) {
    throw JluParseException(message);
  }
  final integer = number.toInt();
  if (max != null && integer > max) throw JluParseException(message);
  return integer;
}

int? _tryPositiveInteger(String value, {int? max}) {
  final number = double.tryParse(value.trim());
  if (number == null ||
      !number.isFinite ||
      number <= 0 ||
      number != number.truncateToDouble()) {
    return null;
  }
  final integer = number.toInt();
  if (max != null && integer > max) return null;
  return integer;
}

int? _optionalInteger(
  Map<String, Object?> row,
  String key, {
  required int min,
  required String message,
}) {
  if (!row.containsKey(key)) return null;
  final number = switch (row[key]) {
    null => 0.0,
    num value => value.toDouble(),
    String value => double.tryParse(value.trim()),
    _ => null,
  };
  if (number == null ||
      !number.isFinite ||
      number != number.truncateToDouble() ||
      number < min) {
    throw JluParseException(message);
  }
  return number.toInt();
}
