import 'local_date.dart';

enum TodoDueKind { none, dateOnly, exact }

enum CalendarColor { rose, peach, sand, sage, teal, blue, lilac, slate }

class TodoDue {
  const TodoDue.none() : kind = TodoDueKind.none, date = null, atUtc = null;

  const TodoDue.dateOnly(LocalDate this.date)
    : kind = TodoDueKind.dateOnly,
      atUtc = null;

  const TodoDue.exact(DateTime this.atUtc)
    : kind = TodoDueKind.exact,
      date = null;

  final TodoDueKind kind;
  final LocalDate? date;
  final DateTime? atUtc;
}

class Todo {
  Todo({
    required this.id,
    required this.userId,
    required this.title,
    required this.notes,
    required this.dueKind,
    this.dueDate,
    this.dueAtUtc,
    this.color,
    required this.showInCalendar,
    required this.completed,
    this.completedAtUtc,
    required this.revision,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final String id;
  final String userId;
  String title;
  String notes;
  TodoDueKind dueKind;
  LocalDate? dueDate;
  DateTime? dueAtUtc;
  CalendarColor? color;
  bool showInCalendar;
  bool completed;
  DateTime? completedAtUtc;
  int revision;
  final DateTime createdAtUtc;
  DateTime updatedAtUtc;
}
