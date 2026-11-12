import 'local_date.dart';
import 'source.dart';

class CourseOffering {
  CourseOffering({
    required this.id,
    required this.userId,
    required this.sourceRef,
    this.semesterId,
    required this.name,
    this.teacher,
    this.remark,
    required this.retained,
  });

  final String id;
  final String userId;
  final SourceRef sourceRef;
  String? semesterId;
  String name;
  String? teacher;
  String? remark;
  bool retained;
}

class Semester {
  Semester({
    required this.id,
    required this.name,
    this.startsOn,
    this.endsOn,
    required this.sourceRef,
    required this.isCurrent,
  });

  final String id;
  final String name;
  final LocalDate? startsOn;
  final LocalDate? endsOn;
  final SourceRef sourceRef;
  final bool isCurrent;
}
