import 'local_date.dart';
import 'source.dart';

class NoticeSummary {
  NoticeSummary({
    required this.id,
    required this.title,
    this.department,
    this.publishedAtUtc,
    this.publishedDate,
    this.publishedText,
    required this.sourceRef,
  });

  final String id;
  final String title;
  final String? department;
  final DateTime? publishedAtUtc;
  final LocalDate? publishedDate;
  final String? publishedText;
  final SourceRef sourceRef;
}

class NoticeDetail extends NoticeSummary {
  NoticeDetail({
    required super.id,
    required super.title,
    super.department,
    super.publishedAtUtc,
    super.publishedDate,
    super.publishedText,
    required super.sourceRef,
    required this.text,
    this.sourceUrl,
    this.attachments = const [],
  });

  final String text;
  final Uri? sourceUrl;
  final List<NoticeAttachment> attachments;
}

class NoticeAttachment {
  NoticeAttachment({
    required this.id,
    required this.name,
    this.bytes,
    required this.downloadable,
  });

  final String id;
  final String name;
  final int? bytes;
  final bool downloadable;
}
