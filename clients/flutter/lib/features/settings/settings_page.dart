import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api/diagnostics_service.dart';
import '../../core/auth/session_controller.dart';
import '../../core/auth/session_models.dart';
import '../diagnostics/diagnostics_page.dart';
import 'source_connection_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.diagnosticsService,
    required this.session,
    required this.glassEnabled,
    required this.onGlassEnabledChanged,
    this.sourceConnections,
  });

  final DiagnosticsService diagnosticsService;
  final SessionController session;
  final bool glassEnabled;
  final ValueChanged<bool> onGlassEnabledChanged;
  final SourceConnectionController? sourceConnections;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SignOutResult? _signOutResult;
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() {
      _signingOut = true;
      _signOutResult = null;
    });
    final result = await widget.session.signOut();
    if (!mounted) {
      return;
    }
    setState(() {
      _signingOut = false;
      _signOutResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final header = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: ListenableBuilder(
                listenable: widget.session,
                builder: (context, child) {
                  return _SessionCard(
                    session: widget.session,
                    signingOut: _signingOut,
                    signOutResult: _signOutResult,
                    onSignOut: _signOut,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
                  side: const BorderSide(color: AppTheme.border),
                ),
                child: SwitchListTile(
                  key: const Key('glass-toggle'),
                  title: const Text('玻璃材质'),
                  subtitle: const Text('关闭后使用实色表面，布局保持不变'),
                  value: widget.glassEnabled,
                  onChanged: widget.onGlassEnabledChanged,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: SourceConnectionCard(controller: widget.sourceConnections),
            ),
          ],
        );
        return Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.6,
              ),
              child: SingleChildScrollView(child: header),
            ),
            Expanded(
              child: DiagnosticsPage(service: widget.diagnosticsService),
            ),
          ],
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.signingOut,
    required this.signOutResult,
    required this.onSignOut,
  });

  final SessionController session;
  final bool signingOut;
  final SignOutResult? signOutResult;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = session.phase;
    final user = session.currentUser;

    return Material(
      key: const Key('session-card'),
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
                Icon(Icons.badge_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '工作台会话',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _statusLabel(phase),
              key: const Key('session-status'),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (user != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '当前用户：${user.displayName}',
                key: const Key('session-user'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (phase == SessionPhase.signedOut) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '登录入口位于工作台页面。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.muted,
                ),
              ),
            ],
            if (phase == SessionPhase.unavailable) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '请检查网络或服务状态后重试恢复。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('session-retry'),
                onPressed: session.retryRestore,
                icon: const Icon(Icons.refresh),
                label: const Text('重试恢复'),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                key: const Key('session-clear-local'),
                onPressed: signingOut ? null : onSignOut,
                icon: const Icon(Icons.logout),
                label: Text(signingOut ? '正在清除…' : '清除本地会话'),
              ),
            ],
            if (phase == SessionPhase.authenticated) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('session-sign-out'),
                onPressed: signingOut ? null : onSignOut,
                icon: const Icon(Icons.logout),
                label: Text(signingOut ? '正在退出…' : '退出登录'),
              ),
            ],
            if (signOutResult != null && !signOutResult!.remoteRevoked) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                signOutResult!.message ?? '未能确认远端会话已撤销。',
                key: const Key('session-sign-out-notice'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _statusLabel(SessionPhase phase) {
  return switch (phase) {
    SessionPhase.restoring => '正在恢复会话',
    SessionPhase.authenticated => '已登录',
    SessionPhase.signedOut => '未登录',
    SessionPhase.unavailable => '会话状态暂不可用',
  };
}
