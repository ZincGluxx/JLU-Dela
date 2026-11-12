import '../models/assignment.dart';
import '../models/lesson.dart';
import '../models/local_date.dart';

abstract interface class LessonQuery {
  Future<List<Lesson>> lessonsBetween(LocalDate from, LocalDate to);
}

abstract interface class AssignmentQuery {
  Future<List<Assignment>> list({
    String? courseId,
    bool includeUndated = true,
    LocalDate? from,
    LocalDate? to,
  });
}
