import 'source.dart';

enum MaterialKind { folder, file }

class Material {
  Material({
    required this.id,
    required this.courseOfferingId,
    this.parentId,
    required this.name,
    required this.kind,
    this.bytes,
    required this.downloadable,
    required this.sourceRef,
  });

  final String id;
  final String courseOfferingId;
  final String? parentId;
  final String name;
  final MaterialKind kind;
  final int? bytes;
  final bool downloadable;
  final SourceRef sourceRef;
}
