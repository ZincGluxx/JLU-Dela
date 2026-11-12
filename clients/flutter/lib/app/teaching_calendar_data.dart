import '../core/models/teaching_timeline.dart';
import '../core/academic/academic_calendar_service.dart';
import '../core/storage/local_workspace.dart';
import '../features/teaching/teaching_store.dart';

List<TeachingPeriod> effectiveTeachingPeriods(
  List<TeachingPeriod> personal,
  AcademicCalendarService? service,
) {
  if (personal.isNotEmpty) return personal;
  final official = service
      ?.snapshotForYear(AcademicCalendarService.currentAcademicYear)
      .calendar;
  return [
    for (final period in official?.periods ?? [])
      TeachingPeriod(
        period: period.number,
        campus: '',
        startMinute: period.startMinute,
        endMinute: period.endMinute,
      ),
  ];
}

Future<List<TeachingPeriod>> loadTeachingPeriods(
  LocalWorkspace workspace,
) async {
  final store = TeachingStore(
    workspace.database,
    workspace.userId,
    workspace.sources,
    workspace.courses,
  );
  final periods = await store.periodTimes();
  return [
    for (final period in periods)
      TeachingPeriod(
        period: period.period,
        campus: period.campus,
        startMinute: period.startMinute,
        endMinute: period.endMinute,
      ),
  ];
}
