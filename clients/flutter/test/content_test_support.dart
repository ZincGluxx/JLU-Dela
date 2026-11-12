import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:jlu_dela/app/local_migrations.dart';
import 'package:jlu_dela/core/models/assignment.dart';
import 'package:jlu_dela/core/models/course.dart';
import 'package:jlu_dela/core/models/lesson.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/core/models/material.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/chaoxing_access.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_context.dart';
import 'package:jlu_dela/core/source/source_portal.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/local_draft_store.dart';
import 'package:jlu_dela/core/storage/local_workspace.dart';
import 'package:jlu_dela/core/storage/queries.dart';
import 'package:jlu_dela/core/storage/source_snapshot_store.dart';
import 'package:jlu_dela/core/storage/todo_store.dart';
import 'package:jlu_dela/features/content/content_store.dart';

class FakeSourceHttpClient implements SourceHttpClient {
  FakeSourceHttpClient({
    Future<SourceResponse> Function(SourceRequest)? handler,
  }) : handler = handler ?? _offline;

  Future<SourceResponse> Function(SourceRequest request) handler;
  final List<SourceRequest> requests = <SourceRequest>[];

  static Future<SourceResponse> _offline(SourceRequest request) {
    throw http.ClientException('offline');
  }

  @override
  Future<SourceResponse> send(SourceRequest request) {
    requests.add(request);
    return handler(request);
  }
}

typedef FakeMaterialRequest = ({
  String courseOfferingId,
  String? parentSourceId,
  int page,
});

class FakeChaoxingAccess implements ChaoxingAccess {
  final Map<String, List<MaterialEntry>> listings =
      <String, List<MaterialEntry>>{};
  final Map<String, int?> pageCounts = <String, int?>{};
  final List<FakeMaterialRequest> listed = <FakeMaterialRequest>[];
  final Map<String, SourceAccess> accesses = <String, SourceAccess>{};
  final List<String> accessed = <String>[];

  String _key(String courseOfferingId, String? parentSourceId, int page) {
    return '$courseOfferingId:${parentSourceId ?? ''}:$page';
  }

  void setListing(
    String courseOfferingId, {
    String? parentSourceId,
    required List<MaterialEntry> entries,
    int? totalPages,
    int page = 1,
  }) {
    final key = _key(courseOfferingId, parentSourceId, page);
    listings[key] = entries;
    pageCounts[key] = totalPages;
  }

  void removeListing(String courseOfferingId, {String? parentSourceId}) {
    final key = _key(courseOfferingId, parentSourceId, 1);
    listings.remove(key);
    pageCounts.remove(key);
  }

  @override
  Future<MaterialChildrenPage> listMaterialChildren({
    required String courseOfferingId,
    String? parentSourceId,
    int page = 1,
  }) async {
    listed.add((
      courseOfferingId: courseOfferingId,
      parentSourceId: parentSourceId,
      page: page,
    ));
    final key = _key(courseOfferingId, parentSourceId, page);
    final entries = listings[key];
    if (entries == null) {
      throw const SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceAuthRequired,
          message: '学习通需要重新登录',
          source: SourceKind.chaoxing,
        ),
      );
    }
    return MaterialChildrenPage(
      entries: entries,
      page: page,
      totalPages: pageCounts[key],
      observedAt: DateTime.utc(2026, 11, 8, 4),
    );
  }

  @override
  Future<SourceAccess> accessMaterial({
    required String courseOfferingId,
    required String sourceId,
  }) async {
    accessed.add(sourceId);
    final value = accesses[sourceId];
    if (value == null) {
      throw const SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceAuthRequired,
          message: '学习通需要重新登录',
          source: SourceKind.chaoxing,
        ),
      );
    }
    return value;
  }

  @override
  Future<SourceAccess> openAssignment({required String assignmentId}) async {
    throw UnimplementedError();
  }
}

class FakeCampusLogin implements CampusLogin {
  FakeCampusLogin({this.connected = true, this.message});

  bool connected;
  String? message;
  final List<SourceKind> attempted = <SourceKind>[];

  @override
  Future<CampusLoginResult> connect(
    BuildContext context,
    SourceKind source,
  ) async {
    attempted.add(source);
    return CampusLoginResult(connected: connected, message: message);
  }
}

class FakeSourcePageOpener implements SourcePageOpener {
  final List<({SourceKind source, Uri uri})> opened =
      <({SourceKind source, Uri uri})>[];
  Object? error;

  @override
  Future<void> openPage(
    BuildContext context, {
    required SourceKind source,
    required Uri uri,
  }) async {
    opened.add((source: source, uri: uri));
    final failure = error;
    if (failure != null) throw failure;
  }
}

class _EmptyLessonQuery implements LessonQuery {
  @override
  Future<List<Lesson>> lessonsBetween(LocalDate from, LocalDate to) async {
    return const <Lesson>[];
  }
}

class _EmptyAssignmentQuery implements AssignmentQuery {
  @override
  Future<List<Assignment>> list({
    String? courseId,
    bool includeUndated = true,
    LocalDate? from,
    LocalDate? to,
  }) async {
    return const <Assignment>[];
  }
}

class ContentHarness {
  ContentHarness({
    required this.database,
    required this.http,
    required this.chaoxing,
    required this.sessions,
    required this.campusLogin,
    required this.browser,
    required this.now,
  });

  static Future<ContentHarness> open({
    DateTime Function()? now,
    SourceSessionRegistry? sessions,
  }) async {
    final database = await LocalDatabase.openInMemory(
      migrations: appLocalMigrations,
    );
    return ContentHarness(
      database: database,
      http: FakeSourceHttpClient(),
      chaoxing: FakeChaoxingAccess(),
      sessions: sessions ?? SourceSessionRegistry(),
      campusLogin: FakeCampusLogin(),
      browser: FakeSourcePageOpener(),
      now: now ?? () => DateTime.utc(2026, 11, 8, 4),
    );
  }

  final LocalDatabase database;
  final FakeSourceHttpClient http;
  final FakeChaoxingAccess chaoxing;
  final SourceSessionRegistry sessions;
  final FakeCampusLogin campusLogin;
  final FakeSourcePageOpener browser;
  final DateTime Function() now;

  void connectSession(SourceKind source) {
    sessions.save(sourceAuthGroup(source), <SourceCookie>[
      SourceCookie(
        name: 'session',
        value: 'sample',
        domain: source == SourceKind.chaoxing ? 'chaoxing.com' : 'jlu.edu.cn',
        secure: true,
        httpOnly: true,
      ),
    ]);
  }

  Future<void> close() => database.close();

  ContentStore storeFor(String userId) {
    return ContentStore(database, userId, source: _sourceContext());
  }

  LocalWorkspace workspaceFor(String userId) {
    final source = _sourceContext();
    final snapshots = SourceSnapshotStore(database, userId);
    return LocalWorkspace(
      userId: userId,
      database: database,
      now: now,
      todos: TodoStore(database, userId, now: now),
      drafts: LocalDraftStore(database, userId),
      courses: CourseStore(database, userId, now: now),
      sources: snapshots,
      lessons: _EmptyLessonQuery(),
      assignments: _EmptyAssignmentQuery(),
      chaoxing: chaoxing,
      sessions: sessions,
      http: http,
      campusLogin: campusLogin,
      browser: browser,
      source: source,
    );
  }

  SourceContext _sourceContext() {
    return SourceContext(
      sessions: sessions,
      http: http,
      campusLogin: campusLogin,
      browser: browser,
    );
  }

  Future<CourseOffering> seedCourse(String userId) async {
    final courses = CourseStore(database, userId, now: now);
    return courses.upsert(
      const SourceCourse(
        source: SourceKind.chaoxing,
        sourceScope: 'sample-account',
        sourceId: 'course-1',
        name: '示例学习通课程',
      ),
    );
  }

  Future<int> countRows(String table, String userId) async {
    final rows = await database.database.rawQuery(
      'SELECT COUNT(*) AS total FROM $table WHERE user_id = ?',
      <Object?>[userId],
    );
    return rows.first['total'] as int;
  }
}

SourceResponse htmlResponse(String html) {
  return SourceResponse(
    statusCode: 200,
    body: html,
    headers: const <String, String>{'content-type': 'text/html; charset=utf-8'},
  );
}

String noticeRow({
  required String id,
  String channel = '179577',
  String title = '示例通知',
  String department = '示例单位',
  String published = '2026-11-06',
  bool pinned = false,
}) {
  final pinnedMarkup = pinned ? '<font>[置顶]</font>' : '';
  return '<div class="li"><a class="font14" '
      'href="PortalInformation!getInformation.action?id=$id&channelId=$channel">'
      '$pinnedMarkup$title</a><a class="column">$department</a>'
      '<span class="time">$published</span></div>';
}

String noticeListPage({
  String rows = '',
  int? totalPages,
  int? totalCount,
  String footer = '',
}) {
  final pagination = totalPages == null
      ? footer
      : '<div class="pages">第 1 / $totalPages 页'
            '${totalCount == null ? '' : ' 共 $totalCount 条记录'}</div>';
  return '<html><body><div id="itemContainer">$rows</div>'
      '$pagination</body></html>';
}

String emptyNoticeListPage({int? totalPages, int? totalCount}) {
  return '<html><body><form id="gjzForm2"><input id="searchnr">'
      '<select id="searchlx"></select><div id="itemContainer">\n\t</div>'
      '</form>'
      '${totalPages == null ? '' : '<div class="pages">第 1 / $totalPages 页'
                '${totalCount == null ? '' : ' 共 $totalCount 条记录'}</div>'}'
      '</body></html>';
}

String noticeDetailPage({
  String title = '示例通知正文',
  String metadata = '2026-11-08 09:30 示例单位',
  String body = '<p>第一段正文</p><p>第二段正文</p>',
  String attachments = '',
}) {
  return '<html><body><div class="content_t">$title</div>'
      '<div class="content_time">$metadata</div>'
      '<div class="content_font">$body</div>$attachments</body></html>';
}

List<MaterialEntry> sampleFileEntries() {
  return const <MaterialEntry>[
    MaterialEntry(id: 'folder-1', name: '示例文件夹', kind: MaterialKind.folder),
    MaterialEntry(
      id: 'file-1',
      name: '示例资料.pdf',
      kind: MaterialKind.file,
      bytes: 12288,
      downloadable: true,
    ),
    MaterialEntry(
      id: 'file-2',
      name: '未提供入口.pdf',
      kind: MaterialKind.file,
      downloadable: false,
    ),
    MaterialEntry(
      id: 'file-signed',
      name: '临时链接.pdf',
      kind: MaterialKind.file,
      downloadable: true,
    ),
    MaterialEntry(
      id: 'file-evil',
      name: '异常地址.pdf',
      kind: MaterialKind.file,
      downloadable: true,
    ),
  ];
}
