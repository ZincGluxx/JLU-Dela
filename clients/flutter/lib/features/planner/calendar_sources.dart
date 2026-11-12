import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/source.dart';
import 'calendar_time.dart';

class CalendarSourceStatus {
  const CalendarSourceStatus({
    required this.source,
    required this.connected,
    this.lastSuccessAtUtc,
    this.lastFailureAtUtc,
  });

  final SourceKind source;
  final bool connected;
  final DateTime? lastSuccessAtUtc;
  final DateTime? lastFailureAtUtc;

  factory CalendarSourceStatus.from({
    required SourceKind source,
    required bool connected,
    required Iterable<SourceSnapshot> snapshots,
  }) {
    DateTime? lastSuccessAtUtc;
    DateTime? lastFailureAtUtc;
    for (final snapshot in snapshots) {
      if (snapshot.source != source) {
        continue;
      }
      final success = snapshot.lastSuccessAtUtc;
      if (success != null &&
          (lastSuccessAtUtc == null || success.isAfter(lastSuccessAtUtc))) {
        lastSuccessAtUtc = success;
      }
      final attempt = snapshot.lastAttemptAtUtc;
      if (snapshot.lastErrorCode != null &&
          attempt != null &&
          (lastFailureAtUtc == null || attempt.isAfter(lastFailureAtUtc))) {
        lastFailureAtUtc = attempt;
      }
    }
    return CalendarSourceStatus(
      source: source,
      connected: connected,
      lastSuccessAtUtc: lastSuccessAtUtc,
      lastFailureAtUtc: lastFailureAtUtc,
    );
  }

  bool get needsLogin => !connected;

  bool get _failureIsLatest {
    final failure = lastFailureAtUtc;
    if (failure == null) {
      return false;
    }
    final success = lastSuccessAtUtc;
    return success == null || failure.isAfter(success);
  }

  String get loginLabel {
    return source == SourceKind.chaoxing ? '登录学习通' : '登录校园';
  }

  String get summary {
    if (!connected) {
      return '${source.label}：未登录来源';
    }
    if (lastSuccessAtUtc == null && lastFailureAtUtc == null) {
      return '${source.label}：已登录 · 尚未同步';
    }
    if (_failureIsLatest) {
      final success = lastSuccessAtUtc;
      final cache = success == null
          ? '未同步成功过'
          : '旧缓存仍在 · 上次成功 ${calendarTimestampLabel(success)}';
      return '${source.label}：上次失败（$cache）';
    }
    return '${source.label}：上次成功 '
        '${calendarTimestampLabel(lastSuccessAtUtc!)}';
  }
}

class CalendarSourceStatusBar extends StatelessWidget {
  const CalendarSourceStatusBar({
    super.key,
    required this.statuses,
    required this.onLogin,
  });

  final List<CalendarSourceStatus> statuses;
  final ValueChanged<SourceKind> onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final status in statuses) _SourceStatusRow(status, onLogin),
        Text(
          '日历只读取本地数据；刷新请到「课表」或「作业」页。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
        ),
      ],
    );
  }
}

class _SourceStatusRow extends StatelessWidget {
  const _SourceStatusRow(this.status, this.onLogin);

  final CalendarSourceStatus status;
  final ValueChanged<SourceKind> onLogin;

  @override
  Widget build(BuildContext context) {
    final icon = status.connected
        ? Icons.check_circle_outline
        : Icons.cloud_off_outlined;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: status.connected ? AppTheme.primary : AppTheme.muted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              status.summary,
              key: Key('calendar-source-${status.source.name}'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
          ),
          if (status.needsLogin)
            TextButton(
              key: Key('calendar-login-${status.source.name}'),
              onPressed: () => onLogin(status.source),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                minimumSize: const Size(44, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(status.loginLabel),
            ),
        ],
      ),
    );
  }
}
