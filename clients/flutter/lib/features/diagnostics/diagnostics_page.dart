import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/diagnostics_service.dart';
import 'diagnostics_models.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key, required this.service});

  final DiagnosticsService service;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  late Future<DiagnosticsReport> _report;

  @override
  void initState() {
    super.initState();
    _report = widget.service.check();
  }

  void _retry() {
    setState(() {
      _report = widget.service.check();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DiagnosticsReport>(
      future: _report,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingView();
        }
        if (snapshot.hasError) {
          return _FailureView(
            error: snapshot.error!,
            apiBaseUri: widget.service.apiBaseUri,
            onRetry: _retry,
          );
        }
        if (snapshot.hasData) {
          return _ReportView(report: snapshot.data!, onRetry: _retry);
        }
        return const _LoadingView();
      },
    );
  }
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= AppBreakpoints.cardGrid
            ? AppSpacing.xxl
            : AppSpacing.lg;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            AppSpacing.xl,
            horizontal,
            AppSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.apiBaseUri});

  final Uri apiBaseUri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '启动诊断',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const _Pill(label: '开发验收', icon: Icons.science_outlined),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '检查真实服务连接、构建版本与数据库迁移状态。本页不读取业务数据。',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF5E6A76),
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDE3EA)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: SelectableText(
                  apiBaseUri.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      child: SizedBox(
        height: 360,
        child: Center(
          child: Column(
            key: const Key('diagnostics-loading'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '正在连接服务并读取健康状态…',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'GET /health/live · /health/ready · /api/v1/meta',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5E6A76)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.error,
    required this.apiBaseUri,
    required this.onRetry,
  });

  final Object error;
  final Uri apiBaseUri;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error is ApiFailure ? error as ApiFailure : null;
    final theme = Theme.of(context);

    return _PageScroll(
      child: Column(
        key: const Key('diagnostics-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(apiBaseUri: apiBaseUri),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3C2BD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: Color(0xFFB42318),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '服务连接失败',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB42318),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  failure?.displayMessage ?? '诊断请求未完成，请检查服务状态后重试。',
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
                if (failure != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ErrorDetailRow(label: '错误码', value: failure.code ?? '—'),
                  _ErrorDetailRow(
                    label: 'HTTP 状态',
                    value: failure.statusCode?.toString() ?? '—',
                  ),
                  _ErrorDetailRow(
                    label: 'request_id',
                    value: failure.requestId ?? '—',
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(error.toString(), style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '确认 API 已启动，或通过 '
            '--dart-define=API_BASE_URL=http://host:port 覆盖默认地址。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF5E6A76),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.tonalIcon(
            key: const Key('diagnostics-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重新检测'),
          ),
        ],
      ),
    );
  }
}

class _ErrorDetailRow extends StatelessWidget {
  const _ErrorDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5E6A76)),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report, required this.onRetry});

  final DiagnosticsReport report;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final databaseDetail = report.database.ready
        ? 'schema ${report.database.schemaVersion ?? '-'}'
        : report.database.message ?? '数据库未就绪';

    return _PageScroll(
      child: Column(
        key: const Key('diagnostics-report'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(apiBaseUri: report.apiBaseUri),
          const SizedBox(height: AppSpacing.lg),
          _StatusBanner(database: report.database),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  '运行信息',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.tonalIcon(
                key: const Key('diagnostics-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新检测'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoGrid(
            items: [
              _InfoItem(
                label: '客户端版本',
                value: report.clientVersion,
                icon: Icons.phone_android_outlined,
              ),
              _InfoItem(
                label: '服务端版本',
                value: report.meta.data.version,
                detail: 'build ${report.meta.data.buildId}',
                icon: Icons.dns_outlined,
              ),
              _InfoItem(
                label: 'API 版本',
                value: report.meta.data.apiVersion,
                detail: report.meta.data.service,
                icon: Icons.api_outlined,
              ),
              _InfoItem(
                label: '服务连接',
                value: '已连接',
                detail: 'GET /health/live',
                icon: Icons.check_circle_outline,
              ),
              _InfoItem(
                label: '数据库就绪',
                value: report.database.ready ? '正常' : '未就绪',
                detail: databaseDetail,
                icon: Icons.storage_outlined,
                emphasized: !report.database.ready,
              ),
              _InfoItem(
                label: 'request_id',
                value: report.meta.meta.requestId,
                icon: Icons.fingerprint,
                monospace: true,
              ),
              _InfoItem(
                label: '检测时间',
                value: _formatTime(report.checkedAt),
                icon: Icons.schedule,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '本页只读取 /health/live、/health/ready 与 /api/v1/meta。'
              '数据库未就绪或服务不可用时，页面会保留失败原因与 request_id，方便对照服务日志。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5E6A76),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.database});

  final DatabaseReadiness database;

  @override
  Widget build(BuildContext context) {
    final ready = database.ready;
    final background = ready
        ? const Color(0xFFE9F7EF)
        : const Color(0xFFFFF4E5);
    final border = ready ? const Color(0xFFB7E4C7) : const Color(0xFFF4D7A8);
    final foreground = ready
        ? const Color(0xFF176C3A)
        : const Color(0xFF8A5A00);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ready ? Icons.verified_outlined : Icons.warning_amber_rounded,
            color: foreground,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready ? '服务与数据库均正常' : '服务在线，数据库未就绪',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ready
                      ? '真实健康检查已通过，可以进行后续联调。'
                      : database.message ?? '请检查 PostgreSQL 与迁移状态。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= AppBreakpoints.cardGrid;
        final width = twoColumns
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _InfoCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _InfoItem {
  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.monospace = false,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;
  final bool monospace;
  final bool emphasized;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.item});

  final _InfoItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueColor = item.emphasized
        ? const Color(0xFF8A5A00)
        : theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.surfaceDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5E6A76),
                  ),
                ),
              ),
              Icon(item.icon, size: 18, color: theme.colorScheme.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
              fontFamily: item.monospace ? 'monospace' : null,
            ),
          ),
          if (item.detail != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.detail!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5E6A76),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
