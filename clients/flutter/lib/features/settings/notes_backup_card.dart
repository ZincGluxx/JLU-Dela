import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jlu_dela_api/api.dart' show BackupNote;

import '../../app/theme.dart';
import '../../core/backup/notes_backup_controller.dart';

class NotesBackupCard extends StatefulWidget {
  const NotesBackupCard({super.key, required this.controller});

  final NotesBackupController? controller;

  @override
  State<NotesBackupCard> createState() => _NotesBackupCardState();
}

class _NotesBackupCardState extends State<NotesBackupCard> {
  bool _openingScope = false;
  String? _localMessage;

  Future<void> _chooseNotes(NotesBackupController controller) async {
    setState(() {
      _openingScope = true;
      _localMessage = null;
    });
    try {
      await controller.refreshLocal();
      if (!mounted || !controller.online) return;
      setState(() => _openingScope = false);
      await showDialog<void>(
        context: context,
        builder: (context) => _NotesSelectionDialog(controller: controller),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _localMessage = '无法读取本机笔记，请稍后重试。本地内容未删除。');
      }
    } finally {
      if (mounted) setState(() => _openingScope = false);
    }
  }

  Future<bool> _confirm(
    NotesBackupController controller, {
    required bool deleting,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => ListenableBuilder(
            listenable: Listenable.merge([controller, controller.session]),
            builder: (context, child) => AlertDialog(
              scrollable: true,
              title: Text(deleting ? '删除云端笔记副本？' : '恢复云端笔记？'),
              content: Text(
                deleting
                    ? '将删除当前账号的云端笔记副本，并停止本机后续上传。本地笔记保留。'
                          '运维备份按保留策略管理，不会随此次操作立即清除。'
                    : '云端与本机不同的内容将保留为独立副本，不静默覆盖本地笔记。'
                          '恢复不会授权上传，并会关闭本机备份；检查后需重新选择上传范围。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  key: Key(
                    deleting
                        ? 'notes-backup-delete-confirm'
                        : 'notes-backup-restore-confirm',
                  ),
                  style: deleting
                      ? TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        )
                      : null,
                  onPressed: controller.online && !controller.busy
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: Text(deleting ? '删除云端副本' : '恢复并保留双方'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller?.session]),
      builder: (context, child) {
        final theme = Theme.of(context);
        final enabled = controller?.enabled ?? false;
        final busy = controller?.busy ?? false;
        final loaded = controller?.loaded ?? false;
        final online = controller?.online ?? false;
        final conflict = controller?.conflict != null;
        final canOperate = loaded && online && !busy && !_openingScope;
        final lastSuccess = controller?.lastSuccess?.toLocal();
        final message = _localMessage ?? controller?.message;
        return Material(
          key: const Key('notes-backup-card'),
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
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    Text(
                      '个人笔记备份',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (controller != null)
                      IconButton(
                        key: const Key('notes-backup-refresh-local'),
                        tooltip: '刷新本机状态，不上传笔记',
                        onPressed: loaded && !busy && !_openingScope
                            ? () async {
                                try {
                                  await controller.refreshLocal();
                                  if (mounted) {
                                    setState(() => _localMessage = null);
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    setState(
                                      () => _localMessage = '无法刷新本机笔记状态，请稍后重试。',
                                    );
                                  }
                                }
                              }
                            : null,
                        icon: const Icon(Icons.refresh),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  enabled ? '已开启 · 仅手动同步' : '未开启',
                  key: const Key('notes-backup-status'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text('只备份你明确勾选的笔记。新笔记默认不选，不会自动上传。'),
                if (controller == null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const Text('当前工作台未接入笔记备份。'),
                ] else ...[
                  const SizedBox(height: AppSpacing.sm),
                  if (!loaded)
                    const Text('正在读取本机备份设置…')
                  else ...[
                    Text(
                      '已选 ${controller.selectedIds.length} 条 · 待同步 ${controller.pendingCount} 项',
                      key: const Key('notes-backup-pending'),
                    ),
                    Text(
                      lastSuccess == null
                          ? '最近成功：暂无记录'
                          : '最近成功（本地时间）：${MaterialLocalizations.of(context).formatMediumDate(lastSuccess)} '
                                '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(lastSuccess), alwaysUse24HourFormat: true)}',
                      key: const Key('notes-backup-last-success'),
                    ),
                    if (controller.available.isEmpty)
                      const Text(
                        '本机暂无笔记。可先创建笔记，或从云端恢复。',
                        key: Key('notes-backup-empty'),
                      ),
                  ],
                  if (!online) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      '当前离线或会话不可用，不能更改范围、同步、恢复或删除云端副本；仍可关闭本机备份。',
                      key: Key('notes-backup-offline'),
                    ),
                  ],
                  if (conflict) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      '云端版本已变化，未覆盖任何内容。请先恢复并保留双方，再重新选择备份范围。',
                      key: Key('notes-backup-conflict'),
                    ),
                  ],
                  if (message != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(message, key: const Key('notes-backup-message')),
                  ],
                  if (busy || _openingScope) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const LinearProgressIndicator(
                      key: Key('notes-backup-progress'),
                      semanticsLabel: '正在处理笔记备份',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(_openingScope ? '正在选择备份范围…' : '正在处理笔记备份…'),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      Tooltip(
                        message: '勾选具体笔记并确认授权；此操作不会上传',
                        child: OutlinedButton(
                          key: const Key('notes-backup-select'),
                          onPressed: canOperate && !conflict
                              ? () => _chooseNotes(controller)
                              : null,
                          child: Text(enabled ? '更改备份范围' : '选择笔记并开启'),
                        ),
                      ),
                      Tooltip(
                        message: '现在上传所选笔记；未选笔记不会上传',
                        child: FilledButton(
                          key: const Key('notes-backup-sync'),
                          onPressed: canOperate && enabled && !conflict
                              ? controller.sync
                              : null,
                          child: const Text('同步所选笔记'),
                        ),
                      ),
                      Tooltip(
                        message: '仅关闭本机后续上传，不删除本地或云端笔记',
                        child: OutlinedButton(
                          key: const Key('notes-backup-disable'),
                          onPressed: enabled ? controller.disable : null,
                          child: const Text('关闭本机备份'),
                        ),
                      ),
                      Tooltip(
                        message: '从云端恢复，不同内容保留双方；不会授权上传',
                        child: OutlinedButton(
                          key: const Key('notes-backup-restore'),
                          onPressed: canOperate
                              ? () async {
                                  if (await _confirm(
                                        controller,
                                        deleting: false,
                                      ) &&
                                      mounted) {
                                    await controller.restore();
                                  }
                                }
                              : null,
                          child: const Text('恢复并保留双方'),
                        ),
                      ),
                      Tooltip(
                        message: '删除当前云端副本；本地保留，运维备份按保留策略管理',
                        child: TextButton(
                          key: const Key('notes-backup-delete'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                          onPressed: canOperate
                              ? () async {
                                  if (await _confirm(
                                        controller,
                                        deleting: true,
                                      ) &&
                                      mounted) {
                                    await controller.deleteCloud();
                                  }
                                }
                              : null,
                          child: const Text('删除云端副本'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotesSelectionDialog extends StatefulWidget {
  const _NotesSelectionDialog({required this.controller});

  final NotesBackupController controller;

  @override
  State<_NotesSelectionDialog> createState() => _NotesSelectionDialogState();
}

class _NotesSelectionDialogState extends State<_NotesSelectionDialog> {
  late final _notes = List<BackupNote>.of(widget.controller.available);
  late final _selected = widget.controller.selectedIds.intersection(
    _notes.map((note) => note.id).toSet(),
  );
  late final _sessionRevision = widget.controller.session.sessionRevision;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.session]),
      builder: (context, child) {
        if (controller.session.sessionRevision != _sessionRevision ||
            controller.session.currentUser?.id != controller.userId) {
          _notes.clear();
          _selected.clear();
          return AlertDialog(
            title: const Text('账号已变化'),
            content: const Text('已清除本次笔记选择，请返回当前账号的设置。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          );
        }
        final selectedNotes = _notes
            .where((note) => _selected.contains(note.id))
            .toList();
        final bytes = utf8.encode(jsonEncode(selectedNotes)).length;
        final limitExceeded = _selected.length > 100 || bytes > 512 * 1024;
        final canChange = controller.online && !controller.busy && !_saving;
        return Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.cardGrid,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: CustomScrollView(
                      key: const Key('notes-backup-selection-list'),
                      shrinkWrap: true,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '选择笔记备份范围',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              const Text(
                                '仅上传勾选笔记的标题、正文、创建与修改时间，以及关联的课程、课次标识、回放来源、回放标识与标题、播放位置。',
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              const Text(
                                '账号密码、Cookie、令牌等凭据不在备份中。未选笔记不会上传；新笔记默认不选。最多 100 条，所选笔记 JSON 合计不超过 512 KiB。',
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              const Text(
                                '确认仅保存授权，不会立即上传。需点击“同步所选笔记”才会上传；缩小范围后下次同步会移除未选的云端内容，本地保留。',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (_notes.isEmpty) const Text('本机暂无可选择的笔记。'),
                            ],
                          ),
                        ),
                        SliverList.builder(
                          itemCount: _notes.length,
                          itemBuilder: (context, index) {
                            final note = _notes[index];
                            final firstLine = note.body
                                .trim()
                                .split('\n')
                                .first
                                .trim();
                            final title = note.title.trim();
                            return CheckboxListTile(
                              key: ValueKey('notes-backup-note-${note.id}'),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: title.isNotEmpty
                                  ? Text(title)
                                  : Tooltip(
                                      message: firstLine.isNotEmpty
                                          ? firstLine
                                          : '未命名笔记',
                                      child: Text(
                                        firstLine.isNotEmpty
                                            ? firstLine
                                            : '未命名笔记',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                              subtitle: title.isNotEmpty && firstLine.isNotEmpty
                                  ? Tooltip(
                                      message: firstLine,
                                      child: Text(
                                        firstLine,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : null,
                              value: _selected.contains(note.id),
                              onChanged: canChange
                                  ? (selected) => setState(() {
                                      if (selected == true) {
                                        _selected.add(note.id);
                                      } else {
                                        _selected.remove(note.id);
                                      }
                                    })
                                  : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '已选 ${_selected.length} / 100 条 · ${(bytes / 1024).toStringAsFixed(1)} / 512 KiB',
                    key: const Key('notes-backup-selection-summary'),
                  ),
                  if (limitExceeded) const Text('超出备份上限，请减少所选笔记。'),
                  if (!controller.online) const Text('当前离线，不能授权上传。可取消并在联网后重试。'),
                  if (_error != null) Text(_error!),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        key: const Key('notes-backup-enable-confirm'),
                        onPressed:
                            canChange && _selected.isNotEmpty && !limitExceeded
                            ? () async {
                                setState(() {
                                  _saving = true;
                                  _error = null;
                                });
                                try {
                                  await controller.enable(Set.of(_selected));
                                  if (context.mounted) Navigator.pop(context);
                                } catch (_) {
                                  if (mounted) {
                                    setState(
                                      () => _error = '授权未能保存，请重试。尚未上传笔记。',
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _saving = false);
                                }
                              }
                            : null,
                        child: Text(_saving ? '正在保存…' : '开启所选笔记备份'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
