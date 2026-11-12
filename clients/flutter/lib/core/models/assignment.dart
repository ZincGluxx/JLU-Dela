import 'local_date.dart';

enum AssignmentDueKind { exact, dateOnly, relative, unknown }

class Assignment {
  Assignment({
    required this.id,
    this.courseOfferingId,
    required this.title,
    required this.sourceStatus,
    this.sourceStatusText,
    required this.dueKind,
    this.dueDate,
    this.dueAtUtc,
    this.timingText,
    required this.observedAtUtc,
    this.readAtUtc,
    this.mutedAtUtc,
  });

  final String id;
  final String? courseOfferingId;
  final String title;
  final String sourceStatus;
  final String? sourceStatusText;
  final AssignmentDueKind dueKind;
  final LocalDate? dueDate;
  final DateTime? dueAtUtc;
  final String? timingText;
  final DateTime observedAtUtc;
  final DateTime? readAtUtc;
  final DateTime? mutedAtUtc;
}
