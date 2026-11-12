import 'package:flutter/widgets.dart';

import '../core/models/source.dart';
import '../core/source/campus_login.dart';
import '../core/source/campus_source_policy.dart';
import '../core/source/cookie_source_http_client.dart';
import '../core/source/in_app_web_view_source_web_view.dart';
import '../core/source/source.dart';
import '../core/source/source_login_dialog.dart';
import '../core/source/source_session.dart';
import '../core/source/source_web_view.dart';

class DeviceCampusLogin implements CampusLogin {
  DeviceCampusLogin({
    required this.sessions,
    SourceHttpClient? http,
    SourceWebView? webView,
  }) : http = http ?? CookieSourceHttpClient(sessions: sessions),
       webView = webView ?? const InAppWebViewSourceWebView();

  final SourceSessionRegistry sessions;
  final SourceHttpClient http;
  final SourceWebView webView;

  @override
  Future<CampusLoginResult> connect(
    BuildContext context,
    SourceKind source,
  ) async {
    final endpoints = CampusSourceEndpoints.forSource(source);
    final capture = await showSourceLoginDialog(
      context,
      source: source,
      webView: webView,
    );
    if (capture == null) {
      return const CampusLoginResult(connected: false, message: '已取消来源登录');
    }
    final group = sourceAuthGroup(source);
    if (capture.cookies.isEmpty) {
      sessions.clearGroup(group);
      return CampusLoginResult(
        connected: false,
        message: '未读取到${source.label}的登录 Cookie，请完成登录后重试',
      );
    }
    sessions.save(group, capture.cookies);
    try {
      final response = await http.send(SourceRequest(uri: endpoints.probeUri));
      if (!endpoints.indicatesAuthenticated(response)) {
        throw SourceException(
          SourceFailure(
            code: SourceErrorCodes.sourceAuthRequired,
            message: '未能确认${source.label}登录状态，请完成学校登录后重试',
            source: source,
          ),
        );
      }
      return const CampusLoginResult(connected: true);
    } on SourceException catch (error) {
      sessions.clearGroup(group);
      return CampusLoginResult(
        connected: false,
        message: _probeFailureMessage(source, error.failure),
      );
    } on Exception {
      sessions.clearGroup(group);
      return CampusLoginResult(
        connected: false,
        message: '${source.label}登录检查未完成，请稍后重试',
      );
    }
  }

  String _probeFailureMessage(SourceKind source, SourceFailure failure) {
    if (failure.code == SourceErrorCodes.sourceAuthRequired) {
      return '未能确认${source.label}登录状态，请完成学校登录后重试';
    }
    return failure.message;
  }
}
