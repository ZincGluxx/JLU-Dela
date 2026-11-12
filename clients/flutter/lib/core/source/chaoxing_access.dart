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

class MaterialChildrenPage {
  const MaterialChildrenPage({
    required this.entries,
    required this.page,
    required this.observedAt,
    this.totalPages,
  });

  final List<MaterialEntry> entries;
  final int page;
  final int? totalPages;
  final DateTime observedAt;
}

enum SourceAccessMode { signedUrl, sourcePage }

class SourceAccess {
  const SourceAccess({
    required this.uri,
    required this.mode,
    required this.requiresSourceSession,
    this.filename,
    this.expiresAtUtc,
  });

  final Uri uri;
  final SourceAccessMode mode;
  final String? filename;
  final bool requiresSourceSession;
  final DateTime? expiresAtUtc;
}

abstract interface class ChaoxingAccess {
  Future<MaterialChildrenPage> listMaterialChildren({
    required String courseOfferingId,
    String? parentSourceId,
    int page = 1,
  });

  Future<SourceAccess> accessMaterial({
    required String courseOfferingId,
    required String sourceId,
  });

  Future<SourceAccess> openAssignment({required String assignmentId});
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
  Future<MaterialChildrenPage> listMaterialChildren({
    required String courseOfferingId,
    String? parentSourceId,
    int page = 1,
  }) async {
    throw _failure;
  }

  @override
  Future<SourceAccess> accessMaterial({
    required String courseOfferingId,
    required String sourceId,
  }) async {
    throw _failure;
  }

  @override
  Future<SourceAccess> openAssignment({required String assignmentId}) async {
    throw _failure;
  }
}
