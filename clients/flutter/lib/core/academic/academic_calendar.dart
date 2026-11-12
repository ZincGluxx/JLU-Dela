import '../models/local_date.dart';

class OfficialAcademicCalendar {
  OfficialAcademicCalendar({
    required this.academicYear,
    required this.version,
    required this.sourceUrl,
    required this.sourceImageUrl,
    required this.publishedAt,
    required List<String> notes,
    required List<AcademicTerm> terms,
    required this.periodsSourceUrl,
    required this.periodsEffectiveFromTerm,
    required List<AcademicPeriod> periods,
    required List<AcademicEvent> events,
  }) : notes = List.unmodifiable(notes),
       terms = List.unmodifiable(terms),
       periods = List.unmodifiable(periods),
       events = List.unmodifiable(events);

  final String academicYear;
  final String version;
  final String sourceUrl;
  final String sourceImageUrl;
  final LocalDate publishedAt;
  final List<String> notes;
  final List<AcademicTerm> terms;
  final String periodsSourceUrl;
  final String periodsEffectiveFromTerm;
  final List<AcademicPeriod> periods;
  final List<AcademicEvent> events;
  String get timeZone => 'Asia/Shanghai';
  bool get includesMakeupDayRules => false;

  AcademicTerm? termOn(LocalDate date) {
    for (final term in terms) {
      if (date.compareTo(term.startDate) >= 0 &&
          date.compareTo(term.endDate) <= 0) {
        return term;
      }
    }
    return null;
  }
}

class AcademicTerm {
  const AcademicTerm({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.teachingWeeks,
  });

  final String id;
  final String name;
  final LocalDate startDate;
  final LocalDate endDate;
  final int teachingWeeks;

  int? teachingWeekOn(LocalDate date) {
    if (date.compareTo(startDate) < 0 || date.compareTo(endDate) > 0) {
      return null;
    }
    final week = date.differenceInDays(startDate) ~/ 7 + 1;
    return week <= teachingWeeks ? week : null;
  }
}

class AcademicPeriod {
  const AcademicPeriod({
    required this.number,
    required this.startMinute,
    required this.endMinute,
  });

  final int number;
  final int startMinute;
  final int endMinute;
}

enum AcademicEventType {
  teaching,
  exam,
  winterBreak,
  summerBreak,
  orientation,
  freshmanTeachingStart,
  holiday,
}

class AcademicEvent {
  const AcademicEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.termId,
  });

  final String id;
  final String title;
  final AcademicEventType type;
  final LocalDate startDate;
  final LocalDate endDate;
  final String? termId;
}

LocalDate parseAcademicDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException('Invalid academic calendar date: $value');
  }
  final date = LocalDate.parse(value);
  final normalized = LocalDate.fromDateTime(date.utcMidnight);
  if (date != normalized) {
    throw FormatException('Invalid academic calendar date: $value');
  }
  return date;
}
