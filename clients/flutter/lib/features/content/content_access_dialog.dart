import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/source/chaoxing_access.dart';
import '../../core/source/source.dart';

class ContentAccessDialog extends StatefulWidget {
  const ContentAccessDialog({
    super.key,
    required this.access,
    required this.sourceLabel,
    required this.connected,
    this.onOpen,
    this.onLogin,
  });

  final SourceAccess access;
  final String sourceLabel;
  final bool connected;
  final Future<void> Function(BuildContext context)? onOpen;
  final Future<void> Function()? onLogin;

  static Future<void> show(
    BuildContext context, {
    required SourceAccess access,
    required String sourceLabel,
    required bool connected,
    Future<void> Function(BuildContext context)? onOpen,
    Future<void> Function()? onLogin,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ContentAccessDialog(
        access: access,
        sourceLabel: sourceLabel,
        connected: connected,
        onOpen: onOpen,
        onLogin: onLogin,
      ),
    );
  }

  @override
  State<ContentAccessDialog> createState() => _ContentAccessDialogState();
}

class _ContentAccessDialogState extends State<ContentAccessDialog> {
  bool _busy = false;
  String? _error;

  bool get _sourcePage => widget.access.mode == SourceAccessMode.sourcePage;

  Future<void> _open() async {
    final open = widget.onOpen;
    if (open == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await open(context);
    } on SourceException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.failure.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _login() async {
    final login = widget.onLogin;
    if (login == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await login();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.access;
    final filename = access.filename ?? '来源文件';
    final modeLabel = _sourcePage ? '来源页面' : '来源签发的临时链接';
    final expiresAt = access.expiresAtUtc;
    final needsLogin = _sourcePage && !widget.connected;
    final canOpen = _sourcePage && widget.connected && widget.onOpen != null;
    return AlertDialog(
      title: Text(filename, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.sourceLabel} · $modeLabel'),
            const SizedBox(height: AppSpacing.sm),
            if (_sourcePage)
              Text(
                '该地址需要在 ${widget.sourceLabel} 来源会话中打开；'
                '工作台不会把它当作可直接下载的链接。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (needsLogin) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '当前来源会话未连接，请先登录 ${widget.sourceLabel}。',
                key: const Key('content-access-needs-login'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (expiresAt != null)
              Text(
                '链接有效至 ${_formatBeijing(expiresAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                key: const Key('content-access-error'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.red.shade700),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              access.uri.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        if (needsLogin && widget.onLogin != null)
          FilledButton(
            key: const Key('content-access-login'),
            onPressed: _busy ? null : _login,
            child: Text('登录${widget.sourceLabel}'),
          ),
        if (canOpen)
          FilledButton.icon(
            key: const Key('content-access-open'),
            onPressed: _busy ? null : _open,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_new, size: 18),
            label: const Text('在来源会话中打开'),
          ),
        TextButton(
          key: const Key('content-access-copy'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: access.uri.toString()));
          },
          child: const Text('复制地址'),
        ),
        TextButton(
          key: const Key('content-access-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

String _formatBeijing(DateTime value) {
  final local = value.toUtc().add(const Duration(hours: 8));
  String pad(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${pad(local.month)}-${pad(local.day)} '
      '${pad(local.hour)}:${pad(local.minute)}';
}
