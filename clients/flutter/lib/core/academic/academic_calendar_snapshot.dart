import '../api/api_failure.dart';
import 'academic_calendar.dart';

class AcademicCalendarSnapshot {
  const AcademicCalendarSnapshot({
    required this.academicYear,
    this.calendar,
    this.isRefreshing = false,
    this.error,
    this.cacheError,
    this.lastSyncedAt,
  });

  final String academicYear;
  final OfficialAcademicCalendar? calendar;
  final bool isRefreshing;
  final ApiFailure? error;
  final String? cacheError;
  final DateTime? lastSyncedAt;
}
