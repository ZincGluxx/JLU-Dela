import '../models/material.dart';
import '../models/source.dart';
import 'source.dart';

class MaterialEntry {
  const MaterialEntry({
    required this.id,
    required this.name,
    required this.kind,
    this.parentId,
    this.bytes,
    this.downloadable = false,
  });

  final String id;
  final String name;
  final MaterialKind kind;
  final String? parentId;
  final int? bytes;
  final bool downloadable;
}

class SourceAccess {
  const SourceAccess({required this.uri, this.expiresAtUtc});

  final Uri uri;
  final DateTime? expiresAtUtc;
}

abstract interface class ChaoxingAccess {
  Future<List<MaterialEntry>> listMaterialChildren(String materialId);

  Future<SourceAccess> accessMaterial(String materialId);

  Future<SourceAccess> openAssignment(String assignmentId);
}

class UnavailableChaoxingAccess implements ChaoxingAccess {
  const UnavailableChaoxingAccess();

  static const _failure = SourceException(
    SourceFailure(
      code: SourceErrorCodes.sourceUnavailable,
      message: '学习通来源尚未接入',
      source: SourceKind.chaoxing,
    ),
  );

  @override
  Future<List<MaterialEntry>> listMaterialChildren(String materialId) async {
    throw _failure;
  }

  @override
  Future<SourceAccess> accessMaterial(String materialId) async {
    throw _failure;
  }

  @override
  Future<SourceAccess> openAssignment(String assignmentId) async {
    throw _failure;
  }
}
