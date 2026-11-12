import 'dart:convert';

import '../../core/models/source.dart';
import '../../core/source/source.dart';
import '../../core/source/source_session.dart';
import 'jlu_timetable_parser.dart';

const String jluIeduOrigin = 'https://iedu.jlu.edu.cn';
const String jluTimetableUrl =
    '$jluIeduOrigin/jwapp/sys/wdkb/*default/index.do';
const String _emapRoot = '/jwapp/sys/wdkb/modules/';

/// 一次完整教务刷新得到的学期课表与附加警告。
class JluTimetableFetch {
  JluTimetableFetch({
    required this.semesterCode,
    required this.timetable,
    required List<String> warnings,
  }) : warnings = List.unmodifiable(warnings);

  final String semesterCode;
  final JluTimetable timetable;
  final List<String> warnings;
}

/// 吉大教学一体化平台（EMAP）个人课表来源。
///
/// 只使用用户自己的会话 Cookie；Cookie 由 [SourceHttpClient] 附加，
/// 这里不读取、不保存任何凭据。
class JluTimetableSource {
  const JluTimetableSource({required this.http});

  final SourceHttpClient http;

  Future<String> currentSemester() async {
    final rows = await _post('jshkcb/dqxnxq.do', 'dqxnxq');
    try {
      return parseCurrentJluSemester(rows);
    } on JluParseException catch (error) {
      throw _protocolFailure(error.message);
    }
  }

  Future<JluTimetableFetch> fetch({String? semesterCode}) async {
    final selected = semesterCode ?? await currentSemester();
    if (!isJluSemesterCode(selected)) {
      throw _protocolFailure('教务学期格式无法识别：$selected');
    }
    final warnings = <String>[];
    final responses = await Future.wait(<Future<List<Object?>>>[
      _post('xskcb/cxxszhxqkb.do', 'cxxszhxqkb', values: {'XNXQDM': selected}),
      _post('jshkcb/jc.do', 'jc'),
      _post(
        'xskcb/cxxljc.do',
        'cxxljc',
        values: {'XN': selected.substring(0, 9), 'XQ': selected.split('-')[2]},
      ),
      _optionalPost(
        'xskcb/xsdkkc.do',
        'xsdkkc',
        values: {'XNXQDM': selected, '*order': '-SQSJ'},
        warning: '调停课信息未获取，请对照教务原课表核查临时调整',
        warnings: warnings,
      ),
      _optionalPost(
        'xskcb/xswpkc.do',
        'xswpkc',
        values: {'XNXQDM': selected},
        warning: '未排定时间的课程信息未获取',
        warnings: warnings,
      ),
    ]);
    final JluTimetable timetable;
    try {
      timetable = normalizeJluTimetable(
        courses: responses[0],
        periods: responses[1],
        calendar: responses[2],
        changes: responses[3],
        unscheduled: responses[4],
      );
    } on JluParseException catch (error) {
      throw _protocolFailure(error.message);
    }
    return JluTimetableFetch(
      semesterCode: selected,
      timetable: timetable,
      warnings: <String>[...timetable.warnings, ...warnings],
    );
  }

  Future<List<Object?>> _optionalPost(
    String path,
    String key, {
    required Map<String, String> values,
    required String warning,
    required List<String> warnings,
  }) async {
    try {
      return await _post(path, key, values: values);
    } on SourceException catch (error) {
      if (error.failure.code == SourceErrorCodes.sourceAuthRequired) {
        rethrow;
      }
      warnings.add(warning);
      return const <Object?>[];
    }
  }

  Future<List<Object?>> _post(
    String path,
    String key, {
    Map<String, String> values = const <String, String>{},
  }) async {
    final response = await http.send(
      SourceRequest(
        uri: Uri.parse('$jluIeduOrigin$_emapRoot$path'),
        method: 'POST',
        headers: const <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json',
          'Origin': jluIeduOrigin,
          'Referer': jluTimetableUrl,
        },
        body: _formEncode(values),
      ),
    );
    if (response.statusCode == 401) throw _authFailure();
    if (!response.isSuccess) {
      throw SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceUnavailable,
          message: '吉大教务暂时不可用（HTTP ${response.statusCode}）',
          retryable:
              response.statusCode >= 500 ||
              response.statusCode == 408 ||
              response.statusCode == 429,
          source: SourceKind.jluIedu,
        ),
      );
    }
    if (_loginFormPattern.hasMatch(response.body)) throw _authFailure();
    final Object? payload;
    try {
      payload = jsonDecode(response.body);
    } on FormatException {
      throw _protocolFailure('吉大教务没有返回课表数据，请检查校园网或学校 VPN 后重试');
    }
    try {
      return parseEmapRows(payload, key);
    } on JluParseException catch (error) {
      throw _protocolFailure(error.message);
    }
  }
}

final RegExp _loginFormPattern = RegExp(
  r'''<form\b[^>]*\bid\s*=\s*["']loginForm["']''',
  caseSensitive: false,
);

String _formEncode(Map<String, String> values) {
  return values.entries
      .map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}='
            '${Uri.encodeQueryComponent(entry.value)}',
      )
      .join('&');
}

SourceException _authFailure() => const SourceException(
  SourceFailure(
    code: SourceErrorCodes.sourceAuthRequired,
    message: '教务登录已失效，请重新登录',
    source: SourceKind.jluIedu,
  ),
);

SourceException _protocolFailure(String message) => SourceException(
  SourceFailure(
    code: SourceErrorCodes.sourceProtocol,
    message: message,
    source: SourceKind.jluIedu,
  ),
);
