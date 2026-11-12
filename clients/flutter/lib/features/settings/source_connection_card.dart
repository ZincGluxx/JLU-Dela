import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/source.dart';
import '../../core/source/source_context.dart';
import '../../core/source/source_session.dart';

class SourceConnectionController {
  const SourceConnectionController({required this.source, this.enabled = true});

  final SourceContext source;
  final bool enabled;
}

class SourceConnectionCard extends StatefulWidget {
  const SourceConnectionCard({super.key, required this.controller});

  final SourceConnectionController? controller;

  @override
  State<SourceConnectionCard> createState() => _SourceConnectionCardState();
}

class _SourceConnectionCardState extends State<SourceConnectionCard> {
  SourceKind? _connecting;
  String? _message;

  Future<void> _connect(SourceKind source) async {
    final controller = widget.controller;
    if (controller == null) {
      return;
    }
    setState(() {
      _connecting = source;
      _message = null;
    });
    final result = await controller.source.campusLogin.connect(context, source);
    if (!mounted) {
      return;
    }
    setState(() {
      _connecting = null;
      _message = result.connected
          ? '已连接${source.label}'
          : result.message ?? '来源连接未完成，请重试';
    });
  }

  void _disconnect(SourceKind source) {
    final controller = widget.controller;
    if (controller == null) {
      return;
    }
    controller.source.sessions.clearGroup(sourceAuthGroup(source));
    setState(() => _message = '已断开${source.label}的校园来源会话');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final enabled = controller != null && controller.enabled;
    final message = _message;
    return Material(
      key: const Key('source-connection-card'),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '校园来源连接',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '在设备上登录教务、电子校务与学习通。Cookie 只保存在内存，'
              '退出或切换工作台后需要重新登录。',
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
            if (!enabled) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '登录工作台后可连接校园来源；未登录时不会建立或保留来源会话。',
                key: const Key('source-connection-disabled'),
                style: theme.textTheme.bodySmall,
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.xs),
              _sourceRow(theme, SourceKind.jluIedu),
              _sourceRow(theme, SourceKind.chaoxing),
              _sourceRow(theme, SourceKind.jluOa),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '教务与电子校务共用吉大校园会话，断开其中一个会同时断开两者；学习通独立认证。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.muted,
                ),
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                key: const Key('source-connection-message'),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sourceRow(ThemeData theme, SourceKind source) {
    final controller = widget.controller;
    final connected =
        controller?.source.sessions.stateFor(source) ==
        SourceConnectionState.connected;
    final connecting = _connecting == source;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(source.label)),
          Text(
            connected ? '已连接' : '未连接',
            key: Key('source-status-${source.databaseValue}'),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: connected ? theme.colorScheme.primary : AppTheme.muted,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (connected)
            OutlinedButton(
              key: Key('source-disconnect-${source.databaseValue}'),
              onPressed: connecting ? null : () => _disconnect(source),
              child: const Text('断开'),
            )
          else
            FilledButton.tonal(
              key: Key('source-connect-${source.databaseValue}'),
              onPressed: _connecting != null || controller == null
                  ? null
                  : () => _connect(source),
              child: Text(connecting ? '连接中…' : '连接'),
            ),
        ],
      ),
    );
  }
}
