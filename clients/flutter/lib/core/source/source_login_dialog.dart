import 'package:flutter/material.dart';

import '../models/source.dart';
import 'campus_source_policy.dart';
import 'source_session.dart';
import 'source_web_view.dart';

class SourceLoginCapture {
  const SourceLoginCapture({required this.cookies, this.finalUri});

  final List<SourceCookie> cookies;
  final Uri? finalUri;
}

Future<SourceLoginCapture?> showSourceLoginDialog(
  BuildContext context, {
  required SourceKind source,
  required SourceWebView webView,
}) {
  final endpoints = CampusSourceEndpoints.forSource(source);
  return showDialog<SourceLoginCapture>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _SourceLoginDialog(
      source: source,
      endpoints: endpoints,
      webView: webView,
    ),
  );
}

class _SourceLoginDialog extends StatefulWidget {
  const _SourceLoginDialog({
    required this.source,
    required this.endpoints,
    required this.webView,
  });

  final SourceKind source;
  final CampusSourceEndpoints endpoints;
  final SourceWebView webView;

  @override
  State<_SourceLoginDialog> createState() => _SourceLoginDialogState();
}

class _SourceLoginDialogState extends State<_SourceLoginDialog> {
  SourceWebViewController? _controller;
  Uri? _currentUri;
  double? _progress;
  String? _message;
  bool _reading = false;

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null) {
      setState(() => _message = '登录页尚未就绪，请稍候');
      return;
    }
    setState(() {
      _reading = true;
      _message = null;
    });
    try {
      final cookies = await controller.readCookies(widget.endpoints.cookieUris);
      if (!mounted) {
        return;
      }
      if (cookies.isEmpty) {
        setState(() {
          _reading = false;
          _message = '未读取到学校 Cookie，请确认已完成登录后重试';
        });
        return;
      }
      Navigator.of(
        context,
      ).pop(SourceLoginCapture(cookies: cookies, finalUri: _currentUri));
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _reading = false;
        _message = '读取来源 Cookie 失败，请重试';
      });
    }
  }

  Future<void> _cancel() async {
    final controller = _controller;
    if (controller != null) {
      try {
        await controller.clearCookies();
      } on Exception {
        // 关闭对话框时仍以退出登录页为主。
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = _message;
    return Dialog.fullscreen(
      key: const Key('source-login-dialog'),
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.school_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '连接${widget.source.label}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const Key('source-login-close'),
                    onPressed: _reading ? null : _cancel,
                    icon: const Icon(Icons.close),
                    tooltip: '取消',
                  ),
                ],
              ),
            ),
            if (_progress != null && _progress! < 1)
              LinearProgressIndicator(value: _progress),
            if (message != null)
              Material(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message,
                          key: const Key('source-login-message'),
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: widget.webView.build(
                isAllowed: isAllowedSourceUri,
                initialUri: widget.endpoints.loginEntryUri,
                onCreated: (controller) {
                  setState(() => _controller = controller);
                },
                onPageChanged: (uri) {
                  setState(() {
                    _currentUri = uri;
                    _progress = null;
                  });
                },
                onBlockedNavigation: (text) {
                  setState(() => _message = text);
                },
                onLoadError: (text) {
                  setState(() => _message = text);
                },
                onProgress: (progress) {
                  setState(() => _progress = progress);
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '登录由学校页面处理，密码不会进入应用；完成后点“我已登录”。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    key: const Key('source-login-cancel'),
                    onPressed: _reading ? null : _cancel,
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('source-login-confirm'),
                    onPressed: _reading ? null : _capture,
                    child: Text(_reading ? '正在读取…' : '我已登录'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
