import 'dart:convert';

import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_session.dart';

Map<String, Object?> teachingCourse({
  String kbId = 'demo-course',
  String classId = 'demo-class',
  String courseCode = 'DEMO001',
  String name = '示例课程',
  String teacher = '示例教师/T0001',
  String classroom = '示例教室',
  String weekday = '3',
  String startPeriod = '1',
  String endPeriod = '2',
  String weekMask = '1',
  String credits = '3',
  String campus = 'A',
  String campusDisplay = '示例校区',
}) {
  return <String, Object?>{
    'KBID': kbId,
    'JXBID': classId,
    'KCH': courseCode,
    'KCM': name,
    'SKJS': teacher,
    'JASMC': classroom,
    'JXBMC': '示例班级',
    'XXXQ': campus,
    'XXXQDM': campus,
    'XXXQDM_DISPLAY': campusDisplay,
    'XXXQMC': campusDisplay,
    'XF': credits,
    'SKXQ': weekday,
    'KSJC': startPeriod,
    'JSJC': endPeriod,
    'SKZC': weekMask,
  };
}

List<Map<String, Object?>> teachingPeriods({String campus = 'A'}) {
  return <Map<String, Object?>>[
    <String, Object?>{
      'DM': '1',
      'KSSJ': '09:10',
      'JSSJ': '09:55',
      'SFSY': '1',
      'XXXQ': campus,
    },
    <String, Object?>{
      'DM': '2',
      'KSSJ': '10:05',
      'JSSJ': '10:50',
      'SFSY': '1',
      'XXXQ': campus,
    },
    <String, Object?>{
      'DM': '3',
      'KSSJ': '11:00',
      'JSSJ': '11:45',
      'SFSY': '1',
      'XXXQ': campus,
    },
  ];
}

List<Map<String, Object?>> teachingCalendar({
  String startsOn = '2026-09-14 00:00:00',
  String totalWeeks = '20',
}) {
  return <Map<String, Object?>>[
    <String, Object?>{'XQKSRQ': startsOn, 'ZZC': totalWeeks},
  ];
}

SourceResponse emapResponse(String key, List<Object?> rows) {
  return SourceResponse(
    statusCode: 200,
    body: jsonEncode(<String, Object?>{
      'code': '0',
      'datas': <String, Object?>{
        key: <String, Object?>{'rows': rows, 'totalSize': rows.length},
      },
    }),
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

SourceResponse loginPageResponse() {
  return const SourceResponse(
    statusCode: 200,
    body:
        '<html><body><form id="loginForm" method="post">'
        '<input name="username"></form></body></html>',
  );
}

SourceException sourceFailure(String code, String message) {
  return SourceException(
    SourceFailure(code: code, message: message, source: null),
  );
}

class FakeSourceHttp implements SourceHttpClient {
  FakeSourceHttp(this.routes);

  final Map<String, SourceResponse Function()> routes;
  final List<SourceRequest> requests = [];

  @override
  Future<SourceResponse> send(SourceRequest request) async {
    requests.add(request);
    final segment = request.uri.pathSegments.last;
    for (final entry in routes.entries) {
      if (segment == entry.key) {
        return entry.value();
      }
    }
    throw StateError('Unexpected request: ${request.uri}');
  }
}

FakeSourceHttp teachingHttp({
  bool loginPage = false,
  bool unauthorized = false,
  bool failCourses = false,
  bool failChanges = false,
  String semesterCode = '2026-2027-1',
  List<Map<String, Object?>>? courses,
  List<Map<String, Object?>>? periods,
  List<Map<String, Object?>>? calendar,
  List<Map<String, Object?>> changes = const <Map<String, Object?>>[],
  List<Map<String, Object?>> unscheduled = const <Map<String, Object?>>[],
}) {
  final courseRows = courses ?? <Map<String, Object?>>[teachingCourse()];
  final periodRows = periods ?? teachingPeriods();
  final calendarRows = calendar ?? teachingCalendar();
  final routes = <String, SourceResponse Function()>{
    'dqxnxq.do': () => loginPage
        ? loginPageResponse()
        : emapResponse('dqxnxq', <Object?>[
            <String, Object?>{'DM': semesterCode},
          ]),
    'cxxszhxqkb.do': () {
      if (loginPage) return loginPageResponse();
      if (unauthorized) {
        throw sourceFailure('SOURCE_AUTH_REQUIRED', '教务登录已失效');
      }
      if (failCourses) {
        throw sourceFailure('SOURCE_UNAVAILABLE', '教务暂时不可用');
      }
      return emapResponse('cxxszhxqkb', courseRows);
    },
    'jc.do': () =>
        loginPage ? loginPageResponse() : emapResponse('jc', periodRows),
    'cxxljc.do': () =>
        loginPage ? loginPageResponse() : emapResponse('cxxljc', calendarRows),
    'xsdkkc.do': () {
      if (loginPage) return loginPageResponse();
      if (failChanges) {
        throw sourceFailure('SOURCE_UNAVAILABLE', '调停课接口失败');
      }
      return emapResponse('xsdkkc', changes);
    },
    'xswpkc.do': () =>
        loginPage ? loginPageResponse() : emapResponse('xswpkc', unscheduled),
  };
  return FakeSourceHttp(routes);
}
