/// 学习通来源的 HTTP 读取：课程列表、作业列表/详情与课程资料目录。
///
/// 页面结构与认证判定移植自 `app/src/main/chaoxing/api.ts`、
/// `app/src/shared/chaoxing-collectors.ts`（GPL-3.0-or-later）。只读、只接受
/// `chaoxing.com` 主机；认证失效映射为 `SOURCE_AUTH_REQUIRED`。
library;

import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/features/assignments/chaoxing_html.dart';
import 'package:jlu_dela/features/assignments/chaoxing_materials.dart';
import 'package:jlu_dela/features/assignments/chaoxing_models.dart';
import 'package:jlu_dela/features/assignments/chaoxing_parse.dart';

class ChaoxingSource {
  ChaoxingSource(this.http);

  final SourceHttpClient http;

  static final Uri _baseUri = Uri.parse('https://i.chaoxing.com/base');
  static final RegExp _loginMarkers = RegExp(
    r'''passport2\.chaoxing\.com/(?:login|passport)|id\s*=\s*["']phone["']|type\s*=\s*["']password["']''',
    caseSensitive: false,
  );

  Future<List<ChaoxingCourse>> fetchCourses() async {
    final base = await _get(_baseUri);
    if (HtmlParser.parse(base.body).querySelector('.course.learnCourse') !=
        null) {
      return _parse(() => parseCoursesPage(base.body, pageUrl: base.uri));
    }
    final frame = parseCourseEntryFrame(base.body, pageUrl: base.uri);
    if (frame == null) throw _protocol(pageStructureChanged);
    final entry = await _get(frame);
    return _parse(() => parseCoursesPage(entry.body, pageUrl: entry.uri));
  }

  Future<List<ChaoxingWorkListItem>> fetchWorkItems(
    ChaoxingCourse course,
  ) async {
    final courseUri = course.sourceUri;
    if (courseUri == null) throw _protocol('缺少学习通课程入口，请先刷新课程');
    final landing = await _get(courseUri);
    var page = landing;
    var frame = parseWorksFrame(landing.body, pageUrl: landing.uri);
    if (frame == null) {
      page = await _get(_withPageHeader(courseUri, '8'));
      frame = parseWorksFrame(page.body, pageUrl: page.uri);
    }
    if (frame == null) {
      if (page.body.contains('bottomList')) {
        return _parse(() => parseWorksPage(page.body, pageUrl: page.uri));
      }
      if (landing.body.contains('bottomList')) {
        return _parse(() => parseWorksPage(landing.body, pageUrl: landing.uri));
      }
      throw _protocol('学习通作业页无法识别');
    }
    final listPage = await _get(frame);
    return _parse(() => parseWorksPage(listPage.body, pageUrl: listPage.uri));
  }

  Future<List<ChaoxingWork>> fetchWorks(ChaoxingCourse course) async {
    final items = await fetchWorkItems(course);
    final started = DateTime.now();
    final works = <ChaoxingWork>[];
    for (final item in items) {
      var work = item.work;
      final detailUri = item.sourceUri;
      if (item.needsDetail && detailUri != null) {
        try {
          final detail = await _get(
            detailUri,
            timeout: const Duration(seconds: 12),
          );
          final timing = parseWorkDetailTiming(
            detail.body,
            listTiming: work.timing,
            elapsed: DateTime.now().difference(started),
          );
          work = _withDetail(work, timing);
        } on Object catch (error) {
          if (error is SourceException &&
              error.failure.code == SourceErrorCodes.sourceAuthRequired) {
            rethrow;
          }
          work = _withDetailError(work);
        }
      }
      works.add(work);
    }
    return works;
  }

  Future<Uri> fetchAssignmentUri(ChaoxingCourse course, String workId) async {
    final items = await fetchWorkItems(course);
    for (final item in items) {
      final uri = item.sourceUri;
      if (item.work.id == workId && uri != null) {
        if (!_isAllowedHost(uri)) throw _protocol('作业入口不在学习通允许范围内');
        return uri;
      }
    }
    throw _protocol('作业不在已读取的学习通课程列表中');
  }

  Future<List<ChaoxingMaterial>> fetchMaterialChildren(
    ChaoxingCourse course,
    List<String> folderPath,
  ) async {
    var entries = await _fetchMaterialRoot(course);
    for (final folderId in folderPath) {
      ChaoxingMaterial? folder;
      for (final entry in entries) {
        if (entry.id == folderId && entry.kind == ChaoxingMaterialKind.folder) {
          folder = entry;
          break;
        }
      }
      final uri = folder?.folderUri;
      if (uri == null) throw _protocol('资料目录不在已读取的学习通课程中');
      entries = await _fetchMaterialPage(uri);
    }
    return entries;
  }

  Future<Uri> materialDownloadUri(
    ChaoxingCourse course,
    List<String> folderPath,
    String fileId,
  ) async {
    final entries = await fetchMaterialChildren(course, folderPath);
    for (final entry in entries) {
      if (entry.id == fileId && entry.kind == ChaoxingMaterialKind.file) {
        final uri = entry.downloadUri;
        if (uri == null) throw _protocol('学校未提供该文件的下载入口');
        return uri;
      }
    }
    throw _protocol('文件不在已读取的资料目录中');
  }

  Future<List<ChaoxingMaterial>> _fetchMaterialRoot(
    ChaoxingCourse course,
  ) async {
    final courseUri = course.sourceUri;
    if (courseUri == null) throw _protocol('缺少学习通课程入口，请先刷新课程');
    final landing = await _get(courseUri);
    var page = landing;
    var frame = parseMaterialsFrame(landing.body, pageUrl: landing.uri);
    if (frame == null) {
      page = await _get(_withPageHeader(courseUri, '3'));
      frame = parseMaterialsFrame(page.body, pageUrl: page.uri);
    }
    if (frame == null) {
      if (page.body.contains('dataBody')) {
        return _parse(
          () => parseMaterialListPage(page.body, pageUrl: page.uri),
        );
      }
      if (landing.body.contains('dataBody')) {
        return _parse(
          () => parseMaterialListPage(landing.body, pageUrl: landing.uri),
        );
      }
      throw _protocol('学习通资料页无法识别');
    }
    return _fetchMaterialPage(frame);
  }

  Future<List<ChaoxingMaterial>> _fetchMaterialPage(Uri uri) async {
    final page = await _get(uri);
    return _parse(() => parseMaterialListPage(page.body, pageUrl: page.uri));
  }

  Future<_Page> _get(Uri uri, {Duration? timeout}) async {
    if (!_isAllowedHost(uri)) throw _protocol('学习通来源地址不在允许范围内');
    final SourceResponse response;
    try {
      response = await http.send(
        SourceRequest(
          uri: uri,
          timeout: timeout ?? const Duration(seconds: 30),
        ),
      );
    } on SourceException {
      rethrow;
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw _authRequired();
    }
    if (!response.isSuccess) {
      final retryable =
          response.statusCode >= 500 ||
          response.statusCode == 408 ||
          response.statusCode == 429;
      throw _failure(
        retryable
            ? SourceErrorCodes.sourceUnavailable
            : SourceErrorCodes.sourceProtocol,
        '学习通请求失败（${response.statusCode}）',
        retryable: retryable,
      );
    }
    final finalUri = response.finalUri;
    if (finalUri != null && finalUri.host == 'passport2.chaoxing.com') {
      throw _authRequired();
    }
    if (_loginMarkers.hasMatch(response.body)) throw _authRequired();
    return _Page(finalUri ?? uri, response.body);
  }

  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on ChaoxingPageFormatException catch (error) {
      throw _protocol(error.message);
    }
  }

  SourceException _protocol(String message) {
    return _failure(SourceErrorCodes.sourceProtocol, message);
  }

  SourceException _authRequired() {
    return _failure(SourceErrorCodes.sourceAuthRequired, '学习通登录已失效，请重新登录学习通');
  }

  SourceException _failure(
    String code,
    String message, {
    bool retryable = false,
  }) {
    return SourceException(
      SourceFailure(
        code: code,
        message: message,
        retryable: retryable,
        source: SourceKind.chaoxing,
      ),
    );
  }

  Uri _withPageHeader(Uri uri, String value) {
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'pageHeader': value},
    );
  }
}

bool _isAllowedHost(Uri uri) {
  if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) return false;
  final host = uri.host.toLowerCase();
  return host == 'chaoxing.com' || host.endsWith('.chaoxing.com');
}

ChaoxingWork _withDetail(ChaoxingWork work, String? timing) {
  return ChaoxingWork(
    id: work.id,
    title: work.title,
    status: work.status,
    timing: work.timing,
    detailTiming: timing,
    detailError: timing == null ? '详情页未提供可识别的截止时间' : null,
    readAt: work.readAt,
    mutedAt: work.mutedAt,
    observedAt: work.observedAt,
  );
}

ChaoxingWork _withDetailError(ChaoxingWork work) {
  return ChaoxingWork(
    id: work.id,
    title: work.title,
    status: work.status,
    timing: work.timing,
    readAt: work.readAt,
    mutedAt: work.mutedAt,
    observedAt: work.observedAt,
    detailError: '作业详情暂时无法读取，请稍后刷新',
  );
}

class _Page {
  const _Page(this.uri, this.body);

  final Uri uri;
  final String body;
}
