import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

import 'source_session.dart';
import 'source_web_view.dart';

const _sourceWebViewInitError = '来源网页组件无法初始化，请确认系统已安装 WebView2 后重试';

class InAppWebViewSourceWebView implements SourceWebView {
  const InAppWebViewSourceWebView();

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
    return _InAppWebViewHost(
      isAllowed: isAllowed,
      onCreated: onCreated,
      initialUri: initialUri,
      onPageChanged: onPageChanged,
      onBlockedNavigation: onBlockedNavigation,
      onLoadError: onLoadError,
      onProgress: onProgress,
    );
  }
}

class _InAppWebViewHost extends StatefulWidget {
  const _InAppWebViewHost({
    required this.isAllowed,
    required this.onCreated,
    this.initialUri,
    this.onPageChanged,
    this.onBlockedNavigation,
    this.onLoadError,
    this.onProgress,
  });

  final bool Function(Uri uri) isAllowed;
  final ValueChanged<SourceWebViewController> onCreated;
  final Uri? initialUri;
  final ValueChanged<Uri>? onPageChanged;
  final ValueChanged<String>? onBlockedNavigation;
  final ValueChanged<String>? onLoadError;
  final ValueChanged<double>? onProgress;

  @override
  State<_InAppWebViewHost> createState() => _InAppWebViewHostState();
}

class _InAppWebViewHostState extends State<_InAppWebViewHost> {
  _SourceWebViewProfile? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void dispose() {
    final profile = _profile;
    _profile = null;
    unawaited(profile?.dispose());
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final profile = await _createProfile();
      if (!mounted) {
        await profile.dispose();
        return;
      }
      setState(() => _profile = profile);
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() => _error = _sourceWebViewInitError);
      widget.onLoadError?.call(_sourceWebViewInitError);
    }
  }

  Future<_SourceWebViewProfile> _createProfile() async {
    if (!Platform.isWindows) {
      return _SourceWebViewProfile(cookieManager: CookieManager.instance());
    }
    final temp = await getTemporaryDirectory();
    final directory = Directory(
      '${temp.path}${Platform.pathSeparator}jlu_dela_source_webview'
      '${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}',
    );
    await directory.create(recursive: true);
    try {
      final environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: directory.path),
      );
      return _SourceWebViewProfile(
        environment: environment,
        cookieManager: CookieManager.instance(webViewEnvironment: environment),
        directory: directory,
      );
    } on Exception {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  void _reportPage(WebUri? url) {
    final uri = Uri.tryParse(url?.toString() ?? '');
    if (uri != null) {
      widget.onPageChanged?.call(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return InAppWebView(
      webViewEnvironment: profile.environment,
      initialUrlRequest: widget.initialUri == null
          ? null
          : URLRequest(url: WebUri(widget.initialUri.toString())),
      initialSettings: InAppWebViewSettings(
        // Windows 插件通过环境内普通 profile 的隐藏 WebView 读取 Cookie，
        // InPrivate 会话读不回来；Windows 改用临时 userDataFolder 并关闭时清理。
        incognito: !Platform.isWindows,
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
        supportMultipleWindows: false,
        javaScriptCanOpenWindowsAutomatically: false,
      ),
      onWebViewCreated: (controller) {
        widget.onCreated(
          _InAppWebViewSourceWebViewController(
            controller: controller,
            cookieManager: profile.cookieManager,
          ),
        );
      },
      shouldOverrideUrlLoading: (controller, action) async {
        if (!action.isForMainFrame) {
          return NavigationActionPolicy.ALLOW;
        }
        final uri = Uri.tryParse(action.request.url.toString());
        if (uri == null) {
          widget.onBlockedNavigation?.call('已拦截无法识别的页面地址');
          return NavigationActionPolicy.CANCEL;
        }
        if (widget.isAllowed(uri)) {
          return NavigationActionPolicy.ALLOW;
        }
        widget.onBlockedNavigation?.call(
          uri.host.isEmpty ? '已拦截非 https 页面' : '已拦截非学校来源的页面：${uri.host}',
        );
        return NavigationActionPolicy.CANCEL;
      },
      onLoadStart: (controller, url) => _reportPage(url),
      onLoadStop: (controller, url) => _reportPage(url),
      onUpdateVisitedHistory: (controller, url, isReload) => _reportPage(url),
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame == false) {
          return;
        }
        widget.onLoadError?.call('来源网页加载失败，请检查网络或校园网/VPN 后重试');
      },
      onReceivedHttpError: (controller, request, response) {
        if (request.isForMainFrame == false) {
          return;
        }
        final status = response.statusCode;
        widget.onLoadError?.call('来源网页返回 HTTP $status，请稍后重试');
      },
      onProgressChanged: (controller, progress) {
        widget.onProgress?.call(progress / 100);
      },
    );
  }
}

class _SourceWebViewProfile {
  _SourceWebViewProfile({
    this.environment,
    required this.cookieManager,
    this.directory,
  });

  final WebViewEnvironment? environment;
  final CookieManager cookieManager;
  final Directory? directory;

  Future<void> dispose() async {
    try {
      await cookieManager.deleteAllCookies();
    } on Exception {
      // Cookie 清理尽力而为，不阻断页面关闭。
    }
    try {
      await environment?.dispose();
    } on Exception {
      // WebView2 环境可能已随页面销毁。
    }
    final tempDirectory = directory;
    if (tempDirectory != null) {
      try {
        await tempDirectory.delete(recursive: true);
      } on FileSystemException {
        // WebView2 进程可能短暂占用临时 profile；残留由系统临时目录回收。
      }
    }
  }
}

class _InAppWebViewSourceWebViewController implements SourceWebViewController {
  _InAppWebViewSourceWebViewController({
    required this.controller,
    required this.cookieManager,
  });

  final InAppWebViewController controller;
  final CookieManager cookieManager;

  @override
  Future<void> load(Uri uri) {
    return controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(uri.toString())),
    );
  }

  @override
  Future<List<SourceCookie>> readCookies(Iterable<Uri> uris) async {
    final collected = <String, SourceCookie>{};
    for (final uri in uris) {
      final cookies = await cookieManager.getCookies(
        url: WebUri(uri.toString()),
      );
      for (final cookie in cookies) {
        final sourceCookie = sourceCookieFromWebViewCookie(cookie, uri);
        if (sourceCookie == null) {
          continue;
        }
        collected.putIfAbsent(
          '${sourceCookie.domain}|${sourceCookie.path}|${sourceCookie.name}',
          () => sourceCookie,
        );
      }
    }
    return List.unmodifiable(collected.values);
  }

  @override
  Future<void> setCookies(Iterable<SourceCookie> cookies) async {
    for (final cookie in cookies) {
      if (cookie.value.isEmpty) {
        continue;
      }
      final host = cookie.domain.startsWith('.')
          ? cookie.domain.substring(1)
          : cookie.domain;
      final path = cookie.path.isEmpty ? '/' : cookie.path;
      await cookieManager.setCookie(
        url: WebUri(Uri(scheme: 'https', host: host, path: path).toString()),
        name: cookie.name,
        value: cookie.value,
        path: path,
        domain: cookie.hostOnly ? null : '.$host',
        expiresDate: cookie.expiresAtUtc?.millisecondsSinceEpoch,
        isSecure: cookie.secure,
        isHttpOnly: cookie.httpOnly,
      );
    }
  }

  @override
  Future<void> clearCookies() async {
    await cookieManager.deleteAllCookies();
  }
}

SourceCookie? sourceCookieFromWebViewCookie(
  Cookie cookie,
  Uri queriedUri, {
  bool? isWindows,
}) {
  final name = cookie.name;
  if (name.isEmpty) {
    return null;
  }
  final queriedHost = queriedUri.host.toLowerCase();
  final rawDomain = cookie.domain?.trim();
  final domain = rawDomain == null || rawDomain.isEmpty
      ? queriedHost
      : rawDomain;
  final bareDomain = domain.startsWith('.') ? domain.substring(1) : domain;
  final hostOnly =
      rawDomain == null ||
      rawDomain.isEmpty ||
      (!rawDomain.startsWith('.') && bareDomain.toLowerCase() == queriedHost);
  final expiresDate = cookie.expiresDate;
  final sessionOnly = cookie.isSessionOnly ?? expiresDate == null;
  final cookiePath = cookie.path;
  return SourceCookie(
    name: name,
    value: cookie.value?.toString() ?? '',
    domain: domain,
    path: cookiePath == null || cookiePath.isEmpty ? '/' : cookiePath,
    secure: cookie.isSecure ?? queriedUri.scheme == 'https',
    httpOnly: cookie.isHttpOnly ?? false,
    hostOnly: hostOnly,
    expiresAtUtc: sessionOnly || expiresDate == null || expiresDate <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (isWindows ?? Platform.isWindows)
                ? expiresDate * 1000
                : expiresDate,
            isUtc: true,
          ),
  );
}
