import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_context.dart';
import 'package:jlu_dela/core/source/source_portal.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/source_snapshot_store.dart';
import 'package:jlu_dela/features/assignments/chaoxing_store.dart';

import 'local_database_test_support.dart';

class FakeRoute {
  FakeRoute(this.matches, this.body, {this.statusCode = 200, this.finalUri});

  final bool Function(Uri uri) matches;
  final String body;
  final int statusCode;
  final Uri? finalUri;
}

class FakeSourceHttpClient implements SourceHttpClient {
  final List<FakeRoute> routes = [];
  final List<Uri> requests = [];

  void on(String url, String body, {int statusCode = 200, Uri? finalUri}) {
    final target = Uri.parse(url);
    routes.add(
      FakeRoute(
        (uri) => uri == target,
        body,
        statusCode: statusCode,
        finalUri: finalUri,
      ),
    );
  }

  void onWhere(
    bool Function(Uri uri) matches,
    String body, {
    int statusCode = 200,
    Uri? finalUri,
  }) {
    routes.add(
      FakeRoute(matches, body, statusCode: statusCode, finalUri: finalUri),
    );
  }

  @override
  Future<SourceResponse> send(SourceRequest request) async {
    requests.add(request.uri);
    for (final route in routes) {
      if (route.matches(request.uri)) {
        return SourceResponse(
          statusCode: route.statusCode,
          body: route.body,
          finalUri: route.finalUri,
        );
      }
    }
    throw StateError('没有为 ${request.uri} 配置来源响应');
  }
}

class FakeSourcePageOpener implements SourcePageOpener {
  FakeSourcePageOpener({this.available = true});

  bool available;
  final List<Uri> opened = [];

  @override
  Future<void> openPage(
    BuildContext context, {
    required SourceKind source,
    required Uri uri,
  }) async {
    if (!available) {
      throw const SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceUnavailable,
          message: '来源原网页尚未接入',
          source: SourceKind.chaoxing,
        ),
      );
    }
    opened.add(uri);
  }
}

SourceSessionRegistry sourceSessions({bool connected = true}) {
  final sessions = SourceSessionRegistry();
  if (connected) {
    sessions.save(SourceAuthGroup.chaoxing, [
      const SourceCookie(
        name: 'session',
        value: 'fixture',
        domain: 'chaoxing.com',
        secure: true,
      ),
    ]);
  }
  return sessions;
}

SourceContext makeSourceContext({
  required FakeSourceHttpClient http,
  SourceSessionRegistry? sessions,
  FakeSourcePageOpener? browser,
  CampusLogin? campusLogin,
  bool connected = true,
}) {
  return SourceContext(
    sessions: sessions ?? sourceSessions(connected: connected),
    http: http,
    campusLogin: campusLogin ?? FakeCampusLogin(),
    browser: browser ?? FakeSourcePageOpener(),
  );
}

class ChaoxingHarness {
  ChaoxingHarness._(
    this.database,
    this.http,
    this.sessions,
    this.browser,
    this.context,
    this.store,
  );

  final LocalDatabase database;
  final FakeSourceHttpClient http;
  final SourceSessionRegistry sessions;
  final FakeSourcePageOpener browser;
  final SourceContext context;
  final ChaoxingStore store;

  static Future<ChaoxingHarness> create({
    DateTime Function()? now,
    String userId = 'user-a',
    bool connected = true,
    FakeSourceHttpClient? http,
    CampusLogin? campusLogin,
    FakeSourcePageOpener? browser,
  }) async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final client = http ?? FakeSourceHttpClient();
    final sessions = sourceSessions(connected: connected);
    final opener = browser ?? FakeSourcePageOpener();
    final context = SourceContext(
      sessions: sessions,
      http: client,
      campusLogin: campusLogin ?? FakeCampusLogin(),
      browser: opener,
    );
    final store = buildStore(
      database: database,
      userId: userId,
      source: context,
      now: now,
    );
    return ChaoxingHarness._(
      database,
      client,
      sessions,
      opener,
      context,
      store,
    );
  }

  ChaoxingStore storeFor(String userId, {DateTime Function()? now}) {
    return buildStore(
      database: database,
      userId: userId,
      source: context,
      now: now,
    );
  }
}

ChaoxingStore buildStore({
  required LocalDatabase database,
  required String userId,
  required SourceContext source,
  DateTime Function()? now,
}) {
  return ChaoxingStore(
    database,
    userId,
    SourceSnapshotStore(database, userId),
    CourseStore(database, userId),
    source: source,
    now: now,
  );
}

const String baseUrl = 'https://i.chaoxing.com/base';
const String entryUrl = 'https://mooc2-ans.chaoxing.com/visit/interaction';
const String worksFrameUrl =
    'https://mooc1.chaoxing.com/mooc2/work/list?courseId=100&pageHeader=8';
const String materialsFrameUrl =
    'https://mooc2-ans.chaoxing.com/mooc2-ans/coursedata/stu-datalist?courseId=100';

String entryPage() {
  return '<html><body>'
      '<iframe id="frame_content" src="$entryUrl"></iframe>'
      '</body></html>';
}

String courseLandingPage({
  String worksFrame = worksFrameUrl,
  String materialsFrame = materialsFrameUrl,
}) {
  return '<html><body>'
      '<iframe id="frame_content-zy" src="$worksFrame"></iframe>'
      '<iframe id="frame_content-zl" src="$materialsFrame"></iframe>'
      '</body></html>';
}

String coursesPage({
  List<({String id, String name, String teacher})> courses = const [
    (id: '100', name: '示例课程甲', teacher: '示例教师'),
  ],
}) {
  final cards = StringBuffer();
  for (final course in courses) {
    cards.write('''
      <div class="course learnCourse">
        <h3><a href="https://mooc1.chaoxing.com/visit/stucoursemiddle?courseid=${course.id}&amp;clazzid=200&amp;enc=fixture">${course.name}</a></h3>
        <p class="course-name">${course.name}</p>
        <p class="course-info"><span class="color3">${course.teacher}</span></p>
      </div>
    ''');
  }
  return '<html><body><div class="course-list">$cards</div></body></html>';
}

String worksPage({
  List<
    ({String id, String title, String status, String timing, String? fullDate})
  >
  works = const [
    (
      id: 'work-1',
      title: '示例作业一',
      status: '未交',
      timing: '剩余1天',
      fullDate: '2026-11-04 20:00',
    ),
    (
      id: 'work-2',
      title: '示例作业二',
      status: 'To be marked',
      timing: '剩余2小时0分钟',
      fullDate: null,
    ),
  ],
}) {
  final rows = StringBuffer();
  for (final work in works) {
    final title = work.fullDate == null ? '' : ' title="${work.fullDate!}"';
    rows.write('''
      <li data="https://mooc1.chaoxing.com/mooc2/work/task?workId=${work.id}&amp;enc=fixture" role="link">
        <div class="right-content"><p class="overHidden2">${work.title}</p></div>
        <span class="status">${work.status}</span>
        <span class="time"$title>${work.timing}</span>
      </li>
    ''');
  }
  return '<html><body><div class="bottomList"><ul>$rows</ul></div></body></html>';
}

String detailPage(String line) {
  return '<html><body><p>$line</p></body></html>';
}

String loginPage() {
  return '<html><body><form action="https://passport2.chaoxing.com/login">'
      '<input id="phone" name="phone"><input type="password" name="pwd">'
      '</form></body></html>';
}

String materialListPage() {
  return '''
<html><body>
  <input id="enc" value="fixture" />
  <input id="cpi" value="fixture-cpi" />
  <input id="ut" value="" />
  <input id="microTopicId" value="" />
  <input id="downloadDomain" value="https://download.chaoxing.com" />
  <input id="classId" value="200" />
  <input id="courseId" value="100" />
  <span class="subtitleId" id="sub-1"></span>
  <div class="dataBody">
    <div class="dataBody_td" type="afolder" id="folder-1" dataname="课件目录">
      <span class="dataBody_name_stu">课件目录</span>
    </div>
    <div class="dataBody_td" id="file-1" dataname="讲义.pdf" isdown="1">
      <span class="dataBody_name_stu">讲义.pdf</span>
      <span class="dataBody_size_stu">1MB</span>
    </div>
  </div>
</body></html>
''';
}

String materialFolderPage() {
  return '''
<html><body>
  <input id="enc" value="fixture" />
  <input id="cpi" value="fixture-cpi" />
  <input id="ut" value="" />
  <input id="microTopicId" value="" />
  <input id="downloadDomain" value="https://download.chaoxing.com" />
  <input id="classId" value="200" />
  <input id="courseId" value="100" />
  <div class="dataBody">
    <div class="dataBody_td" id="file-2" dataname="目录内文件.pdf" isdown="1">
      <span class="dataBody_name_stu">目录内文件.pdf</span>
    </div>
  </div>
</body></html>
''';
}

/// 给标准来源配置一条单课程、两作业的响应链。
void configureSingleCourse(FakeSourceHttpClient http) {
  http.on(baseUrl, entryPage());
  http.on(entryUrl, coursesPage());
  http.on(
    'https://mooc1.chaoxing.com/visit/stucoursemiddle?courseid=100&clazzid=200&enc=fixture',
    courseLandingPage(),
  );
  http.on(worksFrameUrl, worksPage());
  http.on(
    'https://mooc1.chaoxing.com/mooc2/work/task?workId=work-2&enc=fixture',
    detailPage('截止时间：2026-11-04 08:00'),
  );
}
