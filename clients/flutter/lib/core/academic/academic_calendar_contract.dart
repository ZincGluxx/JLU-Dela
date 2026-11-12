import 'package:jlu_dela_api/api.dart' as api;

import '../models/local_date.dart';
import 'academic_calendar.dart';

OfficialAcademicCalendar academicCalendarFromContract(
  api.AcademicCalendar data,
) {
  if (data.includesMakeupDayRules ||
      data.timeZone.toJson() != 'Asia/Shanghai') {
    throw const FormatException('Unsupported academic calendar rules.');
  }
  final terms = data.terms.map((term) {
    final start = LocalDate.fromDateTime(term.startDate);
    final end = LocalDate.fromDateTime(term.endDate);
    if (end.compareTo(start) < 0 || term.teachingWeeks < 1) {
      throw const FormatException('Invalid academic term range.');
    }
    return AcademicTerm(
      id: term.id,
      name: term.name,
      startDate: start,
      endDate: end,
      teachingWeeks: term.teachingWeeks,
    );
  }).toList();
  final periods = data.periods.map((period) {
    final start = _minute(period.startTime);
    final end = _minute(period.endTime);
    if (end <= start || period.number < 1 || period.number > 12) {
      throw const FormatException('Invalid academic period range.');
    }
    return AcademicPeriod(
      number: period.number,
      startMinute: start,
      endMinute: end,
    );
  }).toList();
  final events = data.events.map((event) {
    final start = LocalDate.fromDateTime(event.startDate);
    final end = LocalDate.fromDateTime(event.endDate);
    if (end.compareTo(start) < 0 ||
        (event.termId != null &&
            !terms.any((term) => term.id == event.termId))) {
      throw const FormatException('Invalid academic event range or term.');
    }
    final type = switch (event.type.toJson()) {
      'teaching' => AcademicEventType.teaching,
      'exam' => AcademicEventType.exam,
      'winter_break' => AcademicEventType.winterBreak,
      'summer_break' => AcademicEventType.summerBreak,
      'orientation' => AcademicEventType.orientation,
      'freshman_teaching_start' => AcademicEventType.freshmanTeachingStart,
      'holiday' => AcademicEventType.holiday,
      _ => throw const FormatException('Unknown academic event type.'),
    };
    return AcademicEvent(
      id: event.id,
      title: event.title,
      type: type,
      startDate: start,
      endDate: end,
      termId: event.termId,
    );
  }).toList();
  return OfficialAcademicCalendar(
    academicYear: data.academicYear,
    version: data.version,
    sourceUrl: data.source_.url,
    sourceImageUrl: data.source_.imageUrl,
    publishedAt: LocalDate.fromDateTime(data.source_.publishedAt),
    notes: data.notes,
    terms: terms,
    periodsSourceUrl: data.periodsSource.url,
    periodsEffectiveFromTerm: data.periodsSource.effectiveFromTerm,
    periods: periods,
    events: events,
  );
}

int _minute(String value) {
  if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
    throw FormatException('Invalid academic period time: $value');
  }
  return int.parse(value.substring(0, 2)) * 60 + int.parse(value.substring(3));
}

void validateAcademicDates(Object? value) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (const {
            'start_date',
            'end_date',
            'published_at',
          }.contains(entry.key) &&
          entry.value != null) {
        parseAcademicDate(entry.value as String);
      } else {
        validateAcademicDates(entry.value);
      }
    }
  } else if (value is List) {
    for (final item in value) {
      validateAcademicDates(item);
    }
  }
}
