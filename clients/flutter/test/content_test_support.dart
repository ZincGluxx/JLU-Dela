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
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/local_draft_store.dart';
import 'package:jlu_dela/core/storage/queries.dart';
import 'package:jlu_dela/core/storage/local_workspace.dart';
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

class FakeChaoxingAccess implements ChaoxingAccess {
  final Map<String, List<MaterialEntry>> listings =
      <String, List<MaterialEntry>>{};
  final Map<String, SourceAccess> accesses = <String, SourceAccess>{};
  final List<String> listed = <String>[];
  final List<String> accessed = <String>[];

  @override
  Future<List<MaterialEntry>> listMaterialChildren(String materialId) async {
    listed.add(materialId);
    final value = listings[materialId];
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
  Future<SourceAccess> accessMaterial(String materialId) async {
    accessed.add(materialId);
    final value = accesses[materialId];
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
  Future<SourceAccess> openAssignment(String assignmentId) async {
    throw UnimplementedError();
  }
}

class FakeCampusLogin implements CampusLogin {
  FakeCampusLogin({this.connected = true, this.message});

  bool connected;
  String? message;
  final List<SourceKind> attempted = <SourceKind>[];

  @override
  Future<CampusLoginResult> connect(SourceKind source) async {
    attempted.add(source);
    return CampusLoginResult(connected: connected, message: message);
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
      now: now ?? () => DateTime.utc(2026, 11, 8, 4),
    );
  }

  final LocalDatabase database;
  final FakeSourceHttpClient http;
  final FakeChaoxingAccess chaoxing;
  final SourceSessionRegistry sessions;
  final FakeCampusLogin campusLogin;
  final DateTime Function() now;

  Future<void> close() => database.close();

  ContentStore storeFor(String userId) => ContentStore(database, userId);

  LocalWorkspace workspaceFor(String userId) {
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

String materialRow({
  required String id,
  String type = 'pdf',
  required String name,
  String size = '',
  bool downloadable = false,
  String extra = '',
}) {
  return '<ul class="dataBody_td" id="$id" type="$type" dataname="$name" '
      '${downloadable ? 'isdown="1"' : ''} $extra>'
      '${size.isEmpty ? '' : '<li class="dataBody_size_stu">$size</li>'}</ul>';
}

String folderRow({required String id, required String name}) {
  return '<ul class="dataBody_td" id="$id" type="afolder" '
      'dataname="$name"></ul>';
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
