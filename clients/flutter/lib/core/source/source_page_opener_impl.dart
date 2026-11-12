import 'package:flutter/material.dart';

import '../models/source.dart';
import 'campus_source_policy.dart';
import 'in_app_web_view_source_web_view.dart';
import 'source.dart';
import 'source_portal.dart';
import 'source_session.dart';
import 'source_web_view.dart';

class InAppWebViewSourcePageOpener implements SourcePageOpener {
  const InAppWebViewSourcePageOpener({
    required this.sessions,
    this.webView = const InAppWebViewSourceWebView(),
  });

  final SourceSessionRegistry sessions;
  final SourceWebView webView;

  @override
  Future<void> openPage(
    BuildContext context, {
    required SourceKind source,
    required Uri uri,
  }) async {
    if (!isAllowedSourceUri(uri)) {
      throw SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceProtocol,
          message: '只能打开校园来源白名单内的 https 页面',
          source: source,
        ),
      );
    }
    final pageSource = sourceForAllowedUri(uri);
    if (pageSource == null ||
        sourceAuthGroup(pageSource) != sourceAuthGroup(source)) {
      throw SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceProtocol,
          message: '该页面不属于所选校园来源',
          source: source,
        ),
      );
    }
    final cookies = sessions.cookiesForUri(source, uri);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SourcePageDialog(
        source: source,
        uri: uri,
        cookies: cookies,
        webView: webView,
      ),
    );
  }
}

class _SourcePageDialog extends StatefulWidget {
  const _SourcePageDialog({
    required this.source,
    required this.uri,
    required this.cookies,
    required this.webView,
  });

  final SourceKind source;
  final Uri uri;
  final List<SourceCookie> cookies;
  final SourceWebView webView;

  @override
  State<_SourcePageDialog> createState() => _SourcePageDialogState();
}

class _SourcePageDialogState extends State<_SourcePageDialog> {
  String? _message;
  double? _progress;
  bool _opening = false;

  Future<void> _open(SourceWebViewController controller) async {
    if (_opening) {
      return;
    }
    _opening = true;
    try {
      if (widget.cookies.isNotEmpty) {
        await controller.setCookies(widget.cookies);
      }
      await controller.load(widget.uri);
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() => _message = '来源页面无法打开，请稍后重试');
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = _message;
    return Dialog.fullscreen(
      key: const Key('source-page-dialog'),
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.public, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${widget.source.label}原网页',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const Key('source-page-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: '关闭',
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
                          key: const Key('source-page-message'),
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
                onCreated: _open,
                onPageChanged: (uri) {
                  setState(() {
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
          ],
        ),
      ),
    );
  }
}
