import 'package:flutter/widgets.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/core/source/source_web_view.dart';

class FakeSourceWebViewController implements SourceWebViewController {
  FakeSourceWebViewController({List<SourceCookie> cookies = const []})
    : cookies = List.of(cookies);

  List<SourceCookie> cookies;
  bool failRead = false;
  final List<String> calls = [];
  List<SourceCookie> setCookieCalls = const [];
  int clearCalls = 0;
  Uri? loadedUri;

  @override
  Future<void> load(Uri uri) async {
    calls.add('load');
    loadedUri = uri;
  }

  @override
  Future<List<SourceCookie>> readCookies(Iterable<Uri> uris) async {
    calls.add('readCookies');
    if (failRead) {
      throw Exception('read failed');
    }
    return cookies;
  }

  @override
  Future<void> setCookies(Iterable<SourceCookie> cookies) async {
    calls.add('setCookies');
    setCookieCalls = cookies.toList();
  }

  @override
  Future<void> clearCookies() async {
    calls.add('clearCookies');
    clearCalls++;
  }
}

class FakeSourceWebView implements SourceWebView {
  FakeSourceWebView({FakeSourceWebViewController? controller})
    : controller = controller ?? FakeSourceWebViewController();

  final FakeSourceWebViewController controller;
  Uri? initialUri;
  bool? created;
  ValueChanged<Uri>? pageChanged;
  ValueChanged<String>? blockedNavigation;
  ValueChanged<String>? loadError;
  ValueChanged<double>? progress;
  bool _scheduled = false;

  @override
  Widget build({
    required bool Function(Uri uri) isAllowed,
    required ValueChanged<SourceWebViewController> onCreated,
    Uri? initialUri,
    ValueChanged<Uri>? onPageChanged,
    ValueChanged<String>? onBlockedNavigation,
    ValueChanged<String>? onLoadError,
    ValueChanged<double>? onProgress,
  }) {
    this.initialUri = initialUri;
    pageChanged = onPageChanged;
    blockedNavigation = onBlockedNavigation;
    loadError = onLoadError;
    progress = onProgress;
    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        created = true;
        onCreated(controller);
      });
    }
    return const SizedBox.expand(key: Key('fake-source-webview'));
  }

  void emitPage(Uri uri) => pageChanged?.call(uri);

  void emitBlocked(String message) => blockedNavigation?.call(message);

  void emitLoadError(String message) => loadError?.call(message);
}

class RecordingCampusLogin implements CampusLogin {
  RecordingCampusLogin({
    this.result = const CampusLoginResult(connected: true),
    this.sessions,
  });

  CampusLoginResult result;
  final SourceSessionRegistry? sessions;
  final List<SourceKind> attempted = [];

  @override
  Future<CampusLoginResult> connect(
    BuildContext context,
    SourceKind source,
  ) async {
    attempted.add(source);
    final registry = sessions;
    if (result.connected && registry != null) {
      registry.save(sourceAuthGroup(source), [
        SourceCookie(
          name: 'JSESSIONID',
          value: 'test-session',
          domain: source == SourceKind.chaoxing
              ? '.chaoxing.com'
              : '.jlu.edu.cn',
          secure: true,
        ),
      ]);
    }
    return result;
  }
}

class StubSourceHttpClient implements SourceHttpClient {
  StubSourceHttpClient({this.onSend});

  Future<SourceResponse> Function(SourceRequest request)? onSend;
  final List<SourceRequest> requests = [];

  @override
  Future<SourceResponse> send(SourceRequest request) async {
    requests.add(request);
    final handler = onSend;
    if (handler == null) {
      return SourceResponse(
        statusCode: 200,
        body: '<html><body>ok</body></html>',
        finalUri: request.uri,
      );
    }
    return handler(request);
  }
}
