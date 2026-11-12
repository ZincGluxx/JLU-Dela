import 'dart:math' as math;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/course.dart';
import '../../core/models/local_date.dart';
import '../../core/models/material.dart';
import '../../core/models/notice.dart';
import '../../core/models/source.dart';
import '../../core/source/chaoxing_access.dart';
import '../../core/source/source.dart';
import '../../core/source/source_context.dart';
import '../../core/source/source_executor.dart';
import '../../core/source/source_session.dart';
import '../../core/storage/course_store.dart';
import '../../core/storage/local_database.dart';
import '../../core/storage/local_workspace.dart';
import '../../core/storage/source_snapshot_store.dart';
import 'oa_notice_parser.dart';

const _noticeResource = 'notices';
const _noticeDetailResource = 'notice_detail';
const _materialResource = 'materials';
const _maxNoticeRefreshPages = 20;
const _maxMaterialRefreshPages = 20;
const _noticePageSizeHint = 500;

class ContentAccessException implements Exception {
  const ContentAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NoticeCacheStatus {
  const NoticeCacheStatus({
    this.lastSuccessAtUtc,
    this.lastAttemptAtUtc,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.totalPages,
    this.fetchedPages,
    this.lastCompleteAtUtc,
  });

  final DateTime? lastSuccessAtUtc;
  final DateTime? lastAttemptAtUtc;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final int? totalPages;
  final int? fetchedPages;
  final DateTime? lastCompleteAtUtc;

  bool get hasCachedData => lastSuccessAtUtc != null;

  bool get coversAllPages =>
      totalPages != null &&
      fetchedPages != null &&
      fetchedPages! >= totalPages!;
}

class NoticeRefreshSummary {
  const NoticeRefreshSummary({
    required this.fetchedPages,
    required this.totalPages,
    required this.complete,
    required this.storedCount,
  });

  final int fetchedPages;
  final int? totalPages;
  final bool complete;
  final int storedCount;
}

class MaterialRefreshSummary {
  const MaterialRefreshSummary({required this.storedCount});

  final int storedCount;
}

class ContentStore {
  ContentStore(this.database, this.userId, {this.source})
    : _db = database.database,
      _snapshots = SourceSnapshotStore(database, userId),
      _courses = CourseStore(database, userId);

  static const _uuid = Uuid();

  final LocalDatabase database;
  final String userId;
  final SourceContext? source;
  final Database _db;
  final SourceSnapshotStore _snapshots;
  final CourseStore _courses;

  Future<List<NoticeSummary>> listNotices() async {
    final entries = await _loadNoticeEntries();
    final sorted = sortOaNotices(entries.map((entry) => entry.source));
    final bySource = <String, NoticeSummary>{
      for (final entry in entries) entry.source.id: entry.core,
    };
    return <NoticeSummary>[for (final notice in sorted) bySource[notice.id]!];
  }

  Future<List<NoticeSummary>> searchNotices({
    String query = '',
    String organization = '',
  }) async {
    final entries = await _loadNoticeEntries();
    final filtered = filterOaNotices(
      entries.map((entry) => entry.source),
      query: query,
      organization: organization,
    );
    final sorted = sortOaNotices(filtered);
    final bySource = <String, NoticeSummary>{
      for (final entry in entries) entry.source.id: entry.core,
    };
    return <NoticeSummary>[for (final notice in sorted) bySource[notice.id]!];
  }

  Future<List<String>> noticeOrganizations() async {
    final entries = await _loadNoticeEntries();
    return oaNoticeOrganizations(entries.map((entry) => entry.source));
  }

  Future<NoticeCacheStatus> noticeCacheStatus() async {
    final snapshot = await _snapshots.read(
      SourceKind.jluOa,
      _noticeResource,
      scopeKey: defaultOaNoticeChannel,
    );
    final scope = await _db.query(
      'notice_scopes',
      where: 'user_id = ? AND source_scope = ?',
      whereArgs: <Object?>[userId, defaultOaNoticeChannel],
      limit: 1,
    );
    return NoticeCacheStatus(
      lastSuccessAtUtc: snapshot.lastSuccessAtUtc,
      lastAttemptAtUtc: snapshot.lastAttemptAtUtc,
      lastErrorCode: snapshot.lastErrorCode,
      lastErrorMessage: snapshot.lastErrorMessage,
      totalPages: scope.isEmpty ? null : scope.first['total_pages'] as int?,
      fetchedPages: scope.isEmpty ? null : scope.first['fetched_pages'] as int?,
      lastCompleteAtUtc: scope.isEmpty
          ? null
          : _asUtc(scope.first['last_complete_at_utc']),
    );
  }

  Future<NoticeDetail?> loadNoticeDetail(String noticeId) async {
    final rows = await _db.query(
      'notices',
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[noticeId, userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final text = row['text'] as String?;
    if (text == null) return null;
    final attachments = await _db.query(
      'notice_attachments',
      where: 'user_id = ? AND notice_id = ?',
      whereArgs: <Object?>[userId, noticeId],
      orderBy: 'position',
    );
    final summary = _noticeSummaryFromRow(row);
    return NoticeDetail(
      id: summary.id,
      title: summary.title,
      department: summary.department,
      publishedAtUtc: summary.publishedAtUtc,
      publishedDate: summary.publishedDate,
      publishedText: summary.publishedText,
      sourceRef: summary.sourceRef,
      text: text,
      sourceUrl: (row['source_url'] as String?) == null
          ? null
          : Uri.tryParse(row['source_url'] as String),
      attachments: <NoticeAttachment>[
        for (final attachment in attachments)
          NoticeAttachment(
            id: attachment['id'] as String,
            name: attachment['name'] as String,
            bytes: attachment['bytes'] as int?,
            downloadable: (attachment['downloadable'] as int) == 1,
          ),
      ],
    );
  }

  Future<SourceResult<NoticeRefreshSummary>> refreshNotices(
    LocalWorkspace workspace,
  ) async {
    final executor = SourceExecutor(
      snapshots: workspace.sources,
      now: workspace.now,
    );
    final result = await executor.run<_NoticeFetch>(
      source: SourceKind.jluOa,
      resource: _noticeResource,
      scopeKey: defaultOaNoticeChannel,
      fetch: () => _fetchNotices(workspace),
      persist: (value, observedAt) => _persistNotices(value, observedAt),
    );
    if (result is SourceFailed<_NoticeFetch>) {
      return SourceFailed<NoticeRefreshSummary>(
        failure: result.failure,
        snapshot: result.snapshot,
      );
    }
    final success = result as SourceSuccess<_NoticeFetch>;
    final value = success.value;
    return SourceSuccess<NoticeRefreshSummary>(
      value: NoticeRefreshSummary(
        fetchedPages: value.fetchedPages,
        totalPages: value.totalPages,
        complete: value.complete,
        storedCount: value.items.length,
      ),
      observedAt: success.observedAt,
      snapshot: success.snapshot,
    );
  }

  Future<SourceResult<NoticeDetail>> refreshNoticeDetail(
    LocalWorkspace workspace,
    String noticeId,
  ) async {
    final rows = await _db.query(
      'notices',
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[noticeId, userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const ContentAccessException('通知不在当前用户的已同步缓存中');
    }
    final channel = rows.first['source_scope'] as String;
    final sourceId = rows.first['source_id'] as String;
    final executor = SourceExecutor(
      snapshots: workspace.sources,
      now: workspace.now,
    );
    final result = await executor.run<OaNoticeDetail>(
      source: SourceKind.jluOa,
      resource: _noticeDetailResource,
      scopeKey: '$channel:$sourceId',
      fetch: () async {
        final response = await _sendOa(
          workspace,
          oaNoticeDetailUrl(sourceId, channel),
        );
        return _parseDetail(response.body, sourceId, channel, workspace);
      },
      persist: (detail, observedAt) =>
          _persistNoticeDetail(noticeId, detail, observedAt),
    );
    if (result is SourceFailed<OaNoticeDetail>) {
      return SourceFailed<NoticeDetail>(
        failure: result.failure,
        snapshot: result.snapshot,
      );
    }
    final success = result as SourceSuccess<OaNoticeDetail>;
    final detail = await loadNoticeDetail(noticeId);
    if (detail == null) {
      throw const ContentAccessException('通知正文未能写入本地缓存');
    }
    return SourceSuccess<NoticeDetail>(
      value: detail,
      observedAt: success.observedAt,
      snapshot: success.snapshot,
    );
  }

  Future<SourceAccess> accessNoticeAttachment(
    LocalWorkspace workspace,
    String noticeId,
    String attachmentId,
  ) async {
    final notices = await _db.query(
      'notices',
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[noticeId, userId],
      limit: 1,
    );
    if (notices.isEmpty) {
      throw const ContentAccessException('通知不在当前用户的已同步缓存中');
    }
    final attachments = await _db.query(
      'notice_attachments',
      where: 'user_id = ? AND notice_id = ? AND id = ?',
      whereArgs: <Object?>[userId, noticeId, attachmentId],
      limit: 1,
    );
    if (attachments.isEmpty) {
      throw const ContentAccessException('附件不属于该通知');
    }
    final attachment = attachments.first;
    if ((attachment['downloadable'] as int) != 1) {
      throw const ContentAccessException('来源未提供该附件的下载入口');
    }
    final elementId = attachment['element_id'] as String?;
    final sourcePath = attachment['source_path'] as String?;
    final Uri uri;
    if (elementId != null && elementId.isNotEmpty) {
      uri = Uri.parse(
        oaNoticeDetailUrl(
          notices.first['source_id'] as String,
          notices.first['source_scope'] as String,
        ),
      );
    } else if (sourcePath != null && sourcePath.isNotEmpty) {
      uri = oaNoticeSourceUri(sourcePath);
    } else {
      throw const ContentAccessException('附件缺少来源入口');
    }
    return SourceAccess(
      mode: SourceAccessMode.sourcePage,
      uri: uri,
      filename: attachment['name'] as String,
      requiresSourceSession: true,
    );
  }

  Future<List<CourseOffering>> materialCourses() {
    return _courses.list(source: SourceKind.chaoxing);
  }

  Future<List<Material>> loadMaterials(
    String courseOfferingId, {
    String? parentId,
  }) async {
    final rows = await _db.query(
      'materials',
      where: 'user_id = ? AND course_offering_id = ? AND parent_key = ?',
      whereArgs: <Object?>[userId, courseOfferingId, parentId ?? ''],
      orderBy: 'position, name',
    );
    return rows.map(_materialFromRow).toList();
  }

  Future<SourceSnapshot> materialSnapshot(
    String courseOfferingId, {
    String? parentId,
  }) {
    return _snapshots.read(
      SourceKind.chaoxing,
      _materialResource,
      scopeKey: _materialScopeKey(courseOfferingId, parentId),
    );
  }

  Future<SourceResult<MaterialRefreshSummary>> refreshMaterialChildren(
    LocalWorkspace workspace,
    CourseOffering course, {
    Material? parent,
  }) async {
    await _validateMaterialCourse(course);
    await _validateMaterialParent(course, parent);
    final executor = SourceExecutor(
      snapshots: workspace.sources,
      now: workspace.now,
    );
    final result = await executor.run<_MaterialFetch>(
      source: SourceKind.chaoxing,
      resource: _materialResource,
      scopeKey: _materialScopeKey(course.id, parent?.id),
      fetch: () => _fetchMaterialPages(workspace, course, parent),
      persist: (fetch, observedAt) =>
          _persistMaterials(course, parent, fetch, observedAt),
    );
    if (result is SourceFailed<_MaterialFetch>) {
      return SourceFailed<MaterialRefreshSummary>(
        failure: result.failure,
        snapshot: result.snapshot,
      );
    }
    final success = result as SourceSuccess<_MaterialFetch>;
    return SourceSuccess<MaterialRefreshSummary>(
      value: MaterialRefreshSummary(storedCount: success.value.entries.length),
      observedAt: success.observedAt,
      snapshot: success.snapshot,
    );
  }

  Future<SourceAccess> accessMaterial(
    LocalWorkspace workspace,
    String materialId,
  ) async {
    final rows = await _db.query(
      'materials',
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[materialId, userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const ContentAccessException('资料不属于当前用户');
    }
    final material = _materialFromRow(rows.first);
    if (material.kind == MaterialKind.folder) {
      throw const ContentAccessException('文件夹不能直接打开');
    }
    if (!material.downloadable) {
      throw const ContentAccessException('来源未提供该文件的下载入口');
    }
    final course = await _courses.byId(material.courseOfferingId);
    if (course == null || course.sourceRef.source != SourceKind.chaoxing) {
      throw const ContentAccessException('资料所属课程不在当前用户的学习通课程中');
    }
    final access = await workspace.chaoxing.accessMaterial(
      courseOfferingId: course.id,
      sourceId: material.sourceRef.sourceId,
    );
    _ensureChaoxingUri(access.uri);
    return SourceAccess(
      mode: access.mode,
      uri: access.uri,
      filename: access.filename ?? material.name,
      requiresSourceSession: access.requiresSourceSession,
      expiresAtUtc: access.expiresAtUtc,
    );
  }

  Future<List<_NoticeEntry>> _loadNoticeEntries() async {
    final rows = await _db.query(
      'notices',
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'observed_at_utc DESC',
      limit: _noticePageSizeHint,
    );
    return <_NoticeEntry>[
      for (final row in rows)
        (core: _noticeSummaryFromRow(row), source: _sourceNoticeFromRow(row)),
    ];
  }

  NoticeSummary _noticeSummaryFromRow(Map<String, Object?> row) {
    return NoticeSummary(
      id: row['id'] as String,
      title: row['title'] as String,
      department: row['department'] as String?,
      publishedAtUtc: _asUtc(row['published_at_utc']),
      publishedDate: (row['published_date'] as String?) == null
          ? null
          : LocalDate.parse(row['published_date'] as String),
      publishedText: row['published_text'] as String?,
      sourceRef: SourceRef(
        source: SourceKind.jluOa,
        sourceScope: row['source_scope'] as String,
        sourceId: row['source_id'] as String,
      ),
    );
  }

  OaNoticeSummary _sourceNoticeFromRow(Map<String, Object?> row) {
    final channel = row['source_scope'] as String;
    final sourceId = row['source_id'] as String;
    return OaNoticeSummary(
      id: sourceId,
      channel: channel,
      title: row['title'] as String,
      department: row['department'] as String?,
      pinned: (row['pinned'] as int) == 1,
      published: OaPublishedTime.fromStored(
        atUtc: _asUtc(row['published_at_utc']),
        date: row['published_date'] as String?,
        text: row['published_text'] as String?,
      ),
      sourceUrl: oaNoticeDetailUrl(sourceId, channel),
    );
  }

  Material _materialFromRow(Map<String, Object?> row) {
    return Material(
      id: row['id'] as String,
      courseOfferingId: row['course_offering_id'] as String,
      parentId: row['parent_id'] as String?,
      name: row['name'] as String,
      kind: row['kind'] == 'folder' ? MaterialKind.folder : MaterialKind.file,
      bytes: row['bytes'] as int?,
      downloadable: (row['downloadable'] as int) == 1,
      sourceRef: SourceRef(
        source: SourceKind.chaoxing,
        sourceScope: row['source_scope'] as String,
        sourceId: row['source_id'] as String,
      ),
    );
  }

  Future<_NoticeFetch> _fetchNotices(LocalWorkspace workspace) async {
    final nowUtc = workspace.now().toUtc();
    final first = await _fetchNoticePage(workspace, 1, nowUtc);
    final totalPages = first.totalPages;
    final lastPage = totalPages == null
        ? 1
        : math.min(totalPages, _maxNoticeRefreshPages);
    final items = <OaNoticeSummary>[...first.items];
    for (var page = 2; page <= lastPage; page++) {
      final next = await _fetchNoticePage(workspace, page, nowUtc);
      items.addAll(next.items);
    }
    return _NoticeFetch(
      items: items,
      fetchedPages: lastPage,
      totalPages: totalPages,
      complete: totalPages != null && lastPage >= totalPages,
    );
  }

  Future<OaNoticeListPage> _fetchNoticePage(
    LocalWorkspace workspace,
    int page,
    DateTime nowUtc,
  ) async {
    final uri =
        Uri.parse(
          'https://oa.jlu.edu.cn/defaultroot/PortalInformation!jldxList.action',
        ).replace(
          queryParameters: <String, String>{
            'channelId': defaultOaNoticeChannel,
            'startPage': '$page',
          },
        );
    final response = await _sendOa(workspace, uri.toString());
    final parsed = _parseList(response.body, nowUtc, page);
    if (parsed.items.any((item) => item.channel != defaultOaNoticeChannel)) {
      throw const SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceProtocol,
          message: '电子校务通知频道与请求范围不一致',
          source: SourceKind.jluOa,
        ),
      );
    }
    return parsed;
  }

  OaNoticeListPage _parseList(String html, DateTime nowUtc, int page) {
    try {
      return const OaNoticeParser().parseList(html, nowUtc: nowUtc, page: page);
    } on OaNoticeLayoutException catch (error) {
      throw _protocolFailure(html, error.message);
    }
  }

  OaNoticeDetail _parseDetail(
    String html,
    String noticeId,
    String channel,
    LocalWorkspace workspace,
  ) {
    try {
      return const OaNoticeParser().parseDetail(
        html,
        id: noticeId,
        nowUtc: workspace.now().toUtc(),
        channel: channel,
      );
    } on OaNoticeLayoutException catch (error) {
      throw _protocolFailure(html, error.message);
    }
  }

  SourceException _protocolFailure(String html, String message) {
    if (_looksLikeSchoolLogin(html)) {
      return const SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceAuthRequired,
          message: '电子校务需要重新登录',
          source: SourceKind.jluOa,
        ),
      );
    }
    return SourceException(
      SourceFailure(
        code: SourceErrorCodes.sourceProtocol,
        message: message,
        source: SourceKind.jluOa,
      ),
    );
  }

  Future<SourceResponse> _sendOa(LocalWorkspace workspace, String url) async {
    final response = await workspace.http.send(
      SourceRequest(uri: Uri.parse(url)),
    );
    final finalUri = response.finalUri;
    final leftSource = finalUri != null && finalUri.host != 'oa.jlu.edu.cn';
    if (leftSource ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      throw const SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceAuthRequired,
          message: '电子校务需要重新登录',
          source: SourceKind.jluOa,
        ),
      );
    }
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw const SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceAuthRequired,
          message: '电子校务需要重新登录',
          source: SourceKind.jluOa,
        ),
      );
    }
    if (!response.isSuccess) {
      throw SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceProtocol,
          message: '电子校务返回 HTTP ${response.statusCode}',
          retryable: response.statusCode >= 500,
          source: SourceKind.jluOa,
        ),
      );
    }
    return response;
  }

  Future<void> _persistNotices(_NoticeFetch fetch, DateTime observedAt) async {
    final timestamp = observedAt.toUtc().millisecondsSinceEpoch;
    final unique = <String, OaNoticeSummary>{
      for (final item in fetch.items) item.id: item,
    };
    await _db.transaction((transaction) async {
      for (final item in unique.values) {
        final existing = await transaction.query(
          'notices',
          columns: <String>['id'],
          where: 'user_id = ? AND source_scope = ? AND source_id = ?',
          whereArgs: <Object?>[userId, item.channel, item.id],
          limit: 1,
        );
        final values = <String, Object?>{
          'title': item.title,
          'department': item.department,
          'published_at_utc': item.publishedAtUtc?.millisecondsSinceEpoch,
          'published_date': item.publishedDate,
          'published_text': item.publishedText,
          'pinned': item.pinned ? 1 : 0,
          'observed_at_utc': timestamp,
        };
        if (existing.isEmpty) {
          await transaction.insert('notices', <String, Object?>{
            'id': _uuid.v4(),
            'user_id': userId,
            'source_scope': item.channel,
            'source_id': item.id,
            ...values,
          });
        } else {
          await transaction.update(
            'notices',
            values,
            where: 'id = ? AND user_id = ?',
            whereArgs: <Object?>[existing.first['id'], userId],
          );
        }
      }
      if (fetch.complete) {
        await _deleteUnseenNotices(transaction, unique.keys.toSet());
      }
      await transaction.rawInsert(
        '''
INSERT INTO notice_scopes(
  user_id, source_scope, total_pages, fetched_pages,
  last_complete_at_utc, updated_at_utc
) VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT(user_id, source_scope) DO UPDATE SET
  total_pages = excluded.total_pages,
  fetched_pages = excluded.fetched_pages,
  last_complete_at_utc = COALESCE(
    excluded.last_complete_at_utc,
    notice_scopes.last_complete_at_utc
  ),
  updated_at_utc = excluded.updated_at_utc
''',
        <Object?>[
          userId,
          defaultOaNoticeChannel,
          fetch.totalPages,
          fetch.fetchedPages,
          fetch.complete ? timestamp : null,
          timestamp,
        ],
      );
    });
  }

  Future<void> _deleteUnseenNotices(
    DatabaseExecutor executor,
    Set<String> seen,
  ) async {
    final rows = await executor.query(
      'notices',
      columns: <String>['source_id'],
      where: 'user_id = ? AND source_scope = ?',
      whereArgs: <Object?>[userId, defaultOaNoticeChannel],
    );
    final missing = <String>[
      for (final row in rows)
        if (!seen.contains(row['source_id'] as String))
          row['source_id'] as String,
    ];
    for (final chunk in _chunks(missing, 400)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      await executor.delete(
        'notices',
        where:
            'user_id = ? AND source_scope = ? AND source_id IN ($placeholders)',
        whereArgs: <Object?>[userId, defaultOaNoticeChannel, ...chunk],
      );
    }
  }

  Future<void> _persistNoticeDetail(
    String noticeId,
    OaNoticeDetail detail,
    DateTime observedAt,
  ) async {
    final timestamp = observedAt.toUtc().millisecondsSinceEpoch;
    await _db.transaction((transaction) async {
      final updated = await transaction.update(
        'notices',
        <String, Object?>{
          'title': detail.title,
          'text': detail.text,
          'source_url': detail.sourceUrl,
          'detail_synced_at_utc': timestamp,
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: <Object?>[noticeId, userId],
      );
      if (updated == 0) {
        throw const ContentAccessException('通知已不在当前用户的缓存中');
      }
      await transaction.delete(
        'notice_attachments',
        where: 'user_id = ? AND notice_id = ?',
        whereArgs: <Object?>[userId, noticeId],
      );
      for (var index = 0; index < detail.attachments.length; index++) {
        final attachment = detail.attachments[index];
        await transaction.insert('notice_attachments', <String, Object?>{
          'user_id': userId,
          'notice_id': noticeId,
          'id': attachment.id,
          'name': attachment.name,
          'bytes': null,
          'downloadable': attachment.downloadable ? 1 : 0,
          'element_id': attachment.elementId,
          'source_path': attachment.sourcePath,
          'position': index,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> _validateMaterialCourse(CourseOffering course) async {
    final stored = await _courses.byId(course.id);
    if (stored == null ||
        stored.userId != userId ||
        stored.sourceRef.source != SourceKind.chaoxing) {
      throw const ContentAccessException('课程不在当前用户的学习通课程中');
    }
  }

  Future<void> _validateMaterialParent(
    CourseOffering course,
    Material? parent,
  ) async {
    if (parent == null) return;
    if (parent.courseOfferingId != course.id) {
      throw const ContentAccessException('资料目录不属于当前课程');
    }
    if (parent.kind != MaterialKind.folder) {
      throw const ContentAccessException('只有文件夹可以展开');
    }
    final rows = await _db.query(
      'materials',
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[parent.id, userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const ContentAccessException('资料目录不在当前用户的缓存中');
    }
  }

  Future<_MaterialFetch> _fetchMaterialPages(
    LocalWorkspace workspace,
    CourseOffering course,
    Material? parent,
  ) async {
    final parentSourceId = parent?.sourceRef.sourceId;
    final first = await workspace.chaoxing.listMaterialChildren(
      courseOfferingId: course.id,
      parentSourceId: parentSourceId,
      page: 1,
    );
    final totalPages = first.totalPages;
    final lastPage = totalPages == null
        ? 1
        : math.min(totalPages, _maxMaterialRefreshPages);
    final entries = <MaterialEntry>[...first.entries];
    for (var page = 2; page <= lastPage; page++) {
      final next = await workspace.chaoxing.listMaterialChildren(
        courseOfferingId: course.id,
        parentSourceId: parentSourceId,
        page: page,
      );
      entries.addAll(next.entries);
    }
    return _MaterialFetch(
      entries: entries,
      fetchedPages: lastPage,
      totalPages: totalPages,
      complete: totalPages != null && lastPage >= totalPages,
    );
  }

  Future<void> _persistMaterials(
    CourseOffering course,
    Material? parent,
    _MaterialFetch fetch,
    DateTime observedAt,
  ) async {
    final timestamp = observedAt.toUtc().millisecondsSinceEpoch;
    final parentKey = parent?.id ?? '';
    final unique = <String, MaterialEntry>{
      for (final entry in fetch.entries) entry.id: entry,
    };
    await _db.transaction((transaction) async {
      var position = 0;
      for (final entry in unique.values) {
        final existing = await transaction.query(
          'materials',
          columns: <String>['id'],
          where:
              'user_id = ? AND course_offering_id = ? AND parent_key = ? '
              'AND source_id = ?',
          whereArgs: <Object?>[userId, course.id, parentKey, entry.id],
          limit: 1,
        );
        final values = <String, Object?>{
          'name': entry.name,
          'kind': entry.kind == MaterialKind.folder ? 'folder' : 'file',
          'bytes': entry.kind == MaterialKind.folder ? null : entry.bytes,
          'downloadable': entry.downloadable ? 1 : 0,
          'position': position++,
          'observed_at_utc': timestamp,
        };
        if (existing.isEmpty) {
          await transaction.insert('materials', <String, Object?>{
            'id': _uuid.v4(),
            'user_id': userId,
            'course_offering_id': course.id,
            'parent_id': parent?.id,
            'parent_key': parentKey,
            'source_scope': course.sourceRef.sourceScope,
            'source_id': entry.id,
            ...values,
          });
        } else {
          await transaction.update(
            'materials',
            values,
            where: 'id = ? AND user_id = ?',
            whereArgs: <Object?>[existing.first['id'], userId],
          );
        }
      }
      if (fetch.complete) {
        await _deleteUnseenMaterials(transaction, course, parentKey, unique);
      }
      await transaction.rawInsert(
        '''
INSERT INTO material_scopes(
  user_id, course_offering_id, parent_key, last_success_at_utc, updated_at_utc
) VALUES (?, ?, ?, ?, ?)
ON CONFLICT(user_id, course_offering_id, parent_key) DO UPDATE SET
  last_success_at_utc = excluded.last_success_at_utc,
  updated_at_utc = excluded.updated_at_utc
''',
        <Object?>[userId, course.id, parentKey, timestamp, timestamp],
      );
    });
  }

  Future<void> _deleteUnseenMaterials(
    DatabaseExecutor executor,
    CourseOffering course,
    String parentKey,
    Map<String, MaterialEntry> seen,
  ) async {
    final rows = await executor.query(
      'materials',
      columns: <String>['id', 'source_id'],
      where: 'user_id = ? AND course_offering_id = ? AND parent_key = ?',
      whereArgs: <Object?>[userId, course.id, parentKey],
    );
    final missing = <String>[
      for (final row in rows)
        if (!seen.containsKey(row['source_id'] as String)) row['id'] as String,
    ];
    for (final chunk in _chunks(missing, 400)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      await executor.delete(
        'materials',
        where: 'user_id = ? AND id IN ($placeholders)',
        whereArgs: <Object?>[userId, ...chunk],
      );
    }
  }

  static String _materialScopeKey(String courseOfferingId, String? parentId) {
    return '$courseOfferingId:${parentId ?? ''}';
  }
}

void _ensureChaoxingUri(Uri uri) {
  final host = uri.host;
  final trustedHost =
      host == 'chaoxing.com' ||
      host.endsWith('.chaoxing.com') ||
      host == 'cldisk.com' ||
      host.endsWith('.cldisk.com');
  if (uri.scheme != 'https' || !trustedHost || uri.userInfo.isNotEmpty) {
    throw const ContentAccessException('来源返回了不受支持的文件地址');
  }
}

bool _looksLikeSchoolLogin(String html) {
  final lower = html.toLowerCase();
  return lower.contains('统一身份认证') ||
      lower.contains('cas.jlu.edu.cn') ||
      lower.contains('id="password"') ||
      lower.contains("id='password'");
}

DateTime? _asUtc(Object? value) {
  if (value is! int) return null;
  return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
}

Iterable<List<T>> _chunks<T>(List<T> values, int size) sync* {
  for (var start = 0; start < values.length; start += size) {
    yield values.sublist(start, math.min(start + size, values.length));
  }
}

typedef _NoticeEntry = ({NoticeSummary core, OaNoticeSummary source});

class _NoticeFetch {
  const _NoticeFetch({
    required this.items,
    required this.fetchedPages,
    required this.totalPages,
    required this.complete,
  });

  final List<OaNoticeSummary> items;
  final int fetchedPages;
  final int? totalPages;
  final bool complete;
}

class _MaterialFetch {
  const _MaterialFetch({
    required this.entries,
    required this.fetchedPages,
    required this.totalPages,
    required this.complete,
  });

  final List<MaterialEntry> entries;
  final int fetchedPages;
  final int? totalPages;
  final bool complete;
}
