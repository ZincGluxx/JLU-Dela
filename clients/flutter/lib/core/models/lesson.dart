class Lesson {
  Lesson({
    required this.id,
    required this.courseOfferingId,
    required this.title,
    required this.startsAtUtc,
    required this.endsAtUtc,
    this.location,
    this.periodStart,
    this.periodEnd,
  });

  final String id;
  final String courseOfferingId;
  final String title;
  final DateTime startsAtUtc;
  final DateTime endsAtUtc;
  final String? location;
  final int? periodStart;
  final int? periodEnd;
}
