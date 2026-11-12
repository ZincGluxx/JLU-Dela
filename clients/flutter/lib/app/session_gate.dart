import 'package:flutter/material.dart';

import '../core/auth/session_models.dart';
import 'theme.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({super.key, required this.phase, required this.onRetry});

  final SessionPhase phase;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final content = switch (phase) {
      SessionPhase.restoring => const Column(
        key: Key('session-gate-restoring'),
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppSpacing.lg),
          Text('正在恢复会话…'),
        ],
      ),
      SessionPhase.signedOut ||
      SessionPhase.authenticated => const SizedBox.shrink(),
      SessionPhase.unavailable => Column(
        key: const Key('session-gate-unavailable'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: AppTheme.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('暂时无法恢复会话', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            '请检查网络或服务状态后重试。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.tonalIcon(
            key: const Key('session-gate-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试恢复'),
          ),
        ],
      ),
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: content,
        ),
      ),
    );
  }
}
