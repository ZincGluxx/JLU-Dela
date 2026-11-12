import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/local_date.dart';
import '../../core/models/notice.dart';
import '../../core/models/source.dart';
import '../../core/source/source.dart';
import '../../core/storage/local_workspace.dart';
import 'content_access_dialog.dart';
import 'content_store.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key, required this.workspace, required this.store});

  final LocalWorkspace workspace;
  final ContentStore store;

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  final TextEditingController _queryController = TextEditingController();
  List<NoticeSummary> _notices = const <NoticeSummary>[];
  List<String> _organizations = const <String>[];
  NoticeCacheStatus? _cacheStatus;
  String _organization = '';
  bool _loading = true;
  bool _refreshing = false;
  bool _detailBusy = false;
  String? _error;
  String? _sourceMessage;
  NoticeDetail? _detail;
  int _filterRequest = 0;

  bool get _hasCampusSession =>
      widget.workspace.sessions.hasSession(SourceKind.jluOa);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(NoticesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace != widget.workspace ||
        oldWidget.store != widget.store) {
      _detail = null;
      _organization = '';
      _queryController.clear();
      _error = null;
      _sourceMessage = null;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_filterRequest;
    setState(() {
      _loading = true;
    });
    try {
      final notices = await widget.store.searchNotices(
        query: _queryController.text,
        organization: _organization,
      );
      final organizations = await widget.store.noticeOrganizations();
      final status = await widget.store.noticeCacheStatus();
      if (!mounted || request != _filterRequest) {
        return;
      }
      setState(() {
        _notices = notices;
        _organizations = organizations;
        _cacheStatus = status;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _filterRequest) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _errorText(error);
      });
    }
  }

  Future<void> _applyFilters() async {
    final request = ++_filterRequest;
    try {
      final notices = await widget.store.searchNotices(
        query: _queryController.text,
        organization: _organization,
      );
      if (!mounted || request != _filterRequest) {
        return;
      }
      setState(() {
        _notices = notices;
      });
    } catch (error) {
      if (!mounted || request != _filterRequest) {
        return;
      }
      setState(() {
        _error = _errorText(error);
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final result = await widget.store.refreshNotices(widget.workspace);
      if (!mounted) {
        return;
      }
      if (result is SourceFailed<NoticeRefreshSummary>) {
        setState(() {
          _error = _failureText(result.failure);
        });
      }
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorText(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _connectSource() async {
    setState(() {
      _sourceMessage = null;
      _error = null;
    });
    try {
      final result = await widget.workspace.campusLogin.connect(
        context,
        SourceKind.jluOa,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sourceMessage = result.connected
            ? '电子校务已连接'
            : (result.message ?? '电子校务未连接');
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorText(error);
        });
      }
    }
  }

  Future<void> _openNotice(NoticeSummary notice) async {
    setState(() {
      _detail = null;
      _detailBusy = true;
      _error = null;
    });
    final cached = await widget.store.loadNoticeDetail(notice.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _detail = cached;
    });
    try {
      final result = await widget.store.refreshNoticeDetail(
        widget.workspace,
        notice.id,
      );
      if (!mounted) {
        return;
      }
      if (result is SourceSuccess<NoticeDetail>) {
        setState(() {
          _detail = result.value;
        });
      } else if (result is SourceFailed<NoticeDetail>) {
        setState(() {
          _error = _failureText(result.failure);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorText(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _detailBusy = false;
        });
      }
    }
  }

  Future<void> _openAttachment(NoticeAttachment attachment) async {
    final detail = _detail;
    if (detail == null) {
      return;
    }
    try {
      final access = await widget.store.accessNoticeAttachment(
        widget.workspace,
        detail.id,
        attachment.id,
      );
      if (!mounted) {
        return;
      }
      await ContentAccessDialog.show(
        context,
        access: access,
        sourceLabel: '电子校务',
        connected: _hasCampusSession,
        onLogin: _connectSource,
        onOpen: (dialogContext) => widget.workspace.browser.openPage(
          dialogContext,
          source: SourceKind.jluOa,
          uri: access.uri,
        ),
      );
    } on ContentAccessException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.desktop;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                compact ? AppSpacing.md : AppSpacing.xl,
                AppSpacing.lg,
                compact ? AppSpacing.md : AppSpacing.xl,
                AppSpacing.xl,
              ),
              children: [
                _buildHeader(context),
                const SizedBox(height: AppSpacing.md),
                _buildStatusCard(context),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildError(context),
                ],
                const SizedBox(height: AppSpacing.md),
                if (_detail != null)
                  _buildDetail(context)
                else ...[
                  _buildFilters(context, compact),
                  const SizedBox(height: AppSpacing.md),
                  _buildList(context),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('校园通知', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '电子校务 · 校内通知 · 只搜索本机已同步缓存',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const Key('notices-refresh'),
          onPressed: _refreshing ? null : () => unawaited(_refresh()),
          icon: _refreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(_refreshing ? '正在同步' : '刷新通知'),
        ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final status = _cacheStatus;
    final connected = _hasCampusSession;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _cacheLine(status),
              key: const Key('notices-cache-status'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
            if (!connected) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '电子校务来源未连接，刷新可能需要先在来源会话完成登录。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    key: const Key('notices-connect'),
                    onPressed: () => unawaited(_connectSource()),
                    child: const Text('登录电子校务'),
                  ),
                ],
              ),
            ],
            if (_sourceMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _sourceMessage!,
                key: const Key('notices-source-message'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Container(
      key: const Key('notices-error'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
        border: Border.all(color: const Color(0xFFF0C48A)),
      ),
      child: Text(_error!, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Widget _buildFilters(BuildContext context, bool compact) {
    final query = TextField(
      key: const Key('notices-search'),
      controller: _queryController,
      maxLength: 200,
      onChanged: (_) => unawaited(_applyFilters()),
      decoration: const InputDecoration(
        hintText: '搜索已同步通知标题',
        counterText: '',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
    final organization = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('notices-organization'),
          value: _organization,
          isExpanded: true,
          items: <DropdownMenuItem<String>>[
            const DropdownMenuItem<String>(value: '', child: Text('全部组织')),
            for (final organization in _organizations)
              DropdownMenuItem<String>(
                value: organization,
                child: Text(organization, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            setState(() {
              _organization = value ?? '';
            });
            unawaited(_applyFilters());
          },
        ),
      ),
    );
    if (compact) {
      return Column(
        children: [
          query,
          const SizedBox(height: AppSpacing.sm),
          organization,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: query),
        const SizedBox(width: AppSpacing.md),
        SizedBox(width: 240, child: organization),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: CircularProgressIndicator(key: Key('notices-loading')),
        ),
      );
    }
    if (_notices.isEmpty) {
      return _emptyCard(
        context,
        _cacheStatus?.hasCachedData == true
            ? '没有找到匹配的通知。搜索只覆盖本机已同步缓存。'
            : '尚未同步通知。点击「刷新通知」读取电子校务列表，已读取的内容会保存在本机。',
      );
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '本机已同步 ${_notices.length} 条通知',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final notice in _notices) ...[
          _NoticeTile(
            notice: notice,
            onTap: () => unawaited(_openNotice(notice)),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildDetail(BuildContext context) {
    final detail = _detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton.icon(
              key: const Key('notices-back'),
              onPressed: () {
                setState(() {
                  _detail = null;
                  _error = null;
                });
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('返回列表'),
            ),
            if (_detailBusy) ...[
              const SizedBox(width: AppSpacing.sm),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (detail == null)
          _emptyCard(context, _detailBusy ? '正在读取通知正文…' : '正文尚未同步，刷新后可在本机阅读。')
        else ...[
          Text(
            detail.title,
            key: const Key('notices-detail-title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _detailMeta(detail),
            key: const Key('notices-detail-meta'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          Material(
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SelectableText(
                detail.text.isEmpty ? '正文为空。' : detail.text,
                key: const Key('notices-detail-text'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
          ),
          if (detail.attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('附件', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            for (final attachment in detail.attachments) ...[
              OutlinedButton.icon(
                key: Key('notice-attachment-${attachment.id}'),
                onPressed: attachment.downloadable
                    ? () => unawaited(_openAttachment(attachment))
                    : null,
                icon: const Icon(Icons.attach_file, size: 18),
                label: Text(
                  attachment.downloadable
                      ? attachment.name
                      : '${attachment.name}（来源未提供下载入口）',
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            '附件与原文需要在电子校务来源会话中打开，工作台不会把来源地址当作可直接下载的链接。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
          ),
        ],
      ],
    );
  }

  Widget _emptyCard(BuildContext context, String message) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(message, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice, required this.onTap});

  final NoticeSummary notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        key: Key('notice-${notice.sourceRef.sourceId}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      notice.title,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  if ((notice.department ?? '').isNotEmpty)
                    Text(
                      notice.department!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                    ),
                  Text(
                    _publishedLabel(
                      atUtc: notice.publishedAtUtc,
                      date: notice.publishedDate,
                      text: notice.publishedText,
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _publishedLabel({DateTime? atUtc, LocalDate? date, String? text}) {
  if (atUtc != null) {
    return _formatBeijing(atUtc);
  }
  if (date != null) {
    return date.toIso8601String();
  }
  return text ?? '发布时间未知';
}

String _detailMeta(NoticeDetail detail) {
  final parts = <String>[
    if ((detail.department ?? '').isNotEmpty) detail.department!,
    _publishedLabel(
      atUtc: detail.publishedAtUtc,
      date: detail.publishedDate,
      text: detail.publishedText,
    ),
  ];
  return parts.join(' · ');
}

String _cacheLine(NoticeCacheStatus? status) {
  if (status == null) {
    return '尚未同步电子校务通知';
  }
  final parts = <String>[];
  if (status.fetchedPages != null || status.totalPages != null) {
    parts.add(
      '已同步 ${status.fetchedPages ?? 0} / ${status.totalPages ?? '?'} 页',
    );
  }
  if (status.lastSuccessAtUtc != null) {
    parts.add('上次成功 ${_formatBeijing(status.lastSuccessAtUtc!)}');
  }
  if (status.lastErrorCode != null) {
    parts.add('上次失败：${status.lastErrorMessage ?? status.lastErrorCode}');
  }
  if (parts.isEmpty) {
    parts.add('尚未同步电子校务通知');
  }
  return parts.join(' · ');
}

String _formatBeijing(DateTime value) {
  final local = value.toUtc().add(const Duration(hours: 8));
  String pad(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${pad(local.month)}-${pad(local.day)} '
      '${pad(local.hour)}:${pad(local.minute)}';
}

String _failureText(SourceFailure failure) {
  if (failure.code == SourceErrorCodes.sourceAuthRequired) {
    return '电子校务需要重新登录：${failure.message}';
  }
  return failure.message;
}

String _errorText(Object error) {
  if (error is ContentAccessException) {
    return error.message;
  }
  if (error is SourceException) {
    return _failureText(error.failure);
  }
  return '$error';
}
