import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/local_date.dart';
import '../../core/models/todo.dart';
import '../../core/storage/local_workspace.dart';
import '../../core/storage/todo_store.dart';
import 'todo_draft.dart';
import 'todo_due_stepper.dart';
import 'todo_format.dart';

enum TodoEditorOutcome { saved, deleted }

class TodoEditor extends StatefulWidget {
  const TodoEditor({super.key, required this.workspace, this.todo, this.draft});

  final LocalWorkspace workspace;
  final Todo? todo;
  final Map<String, dynamic>? draft;

  @override
  State<TodoEditor> createState() => _TodoEditorState();
}

class _TodoEditorState extends State<TodoEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late bool _showInCalendar;
  late TodoDueKind _dueKind;
  late LocalDate _dueDate;
  late int _hour;
  late int _minute;
  late CalendarColor _color;
  late Todo? _baseTodo;
  bool _restoredDraft = false;
  bool _busy = false;
  bool _overwritePending = false;
  String? _errorText;
  Todo? _conflictCurrent;
  Future<void> _draftWrite = Future<void>.value();

  String get _draftKey => todoDraftKeyFor(widget.todo);

  @override
  void initState() {
    super.initState();
    final wallNow = schoolWallTime(widget.workspace.now());
    _titleController = TextEditingController();
    _notesController = TextEditingController();
    _dueKind = TodoDueKind.none;
    _dueDate = LocalDate(wallNow.year, wallNow.month, wallNow.day);
    _hour = wallNow.hour;
    _minute = wallNow.minute;
    _color = CalendarColor.slate;
    _showInCalendar = false;
    _baseTodo = widget.todo;
    if (widget.todo != null) {
      _applyTodoToForm(widget.todo!);
    }
    final draft = widget.draft;
    if (draft != null && _applyDraft(draft)) {
      _restoredDraft = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 600;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_cancel());
        }
      },
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: narrow ? AppSpacing.md : AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.glassRadius),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(narrow ? AppSpacing.lg : AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.todo == null ? '新建待办' : '编辑待办',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('todo-editor-close'),
                      tooltip: '关闭',
                      onPressed: _busy ? null : () => unawaited(_cancel()),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (_restoredDraft) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _Notice(
                    key: const Key('todo-draft-restored'),
                    icon: Icons.history,
                    text: '已恢复上次未保存的草稿',
                    color: AppTheme.blueSoft,
                  ),
                ],
                if (_conflictCurrent != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ConflictBanner(
                    busy: _busy,
                    onLoadLatest: _loadLatestConflict,
                    onKeepDraft: _keepDraft,
                  ),
                ],
                if (_overwritePending) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Notice(
                    key: const Key('todo-overwrite-warning'),
                    icon: Icons.warning_amber_rounded,
                    text: '已保留你的草稿；再次保存会覆盖别处更新。',
                    color: theme.colorScheme.tertiaryContainer,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('todo-title-field'),
                  controller: _titleController,
                  autofocus: true,
                  maxLength: TodoStore.maxTitleLength,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    hintText: '例如：准备小组展示',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  onChanged: (_) => _handleFieldChanged(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '截止',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TodoDueFields(
                  kind: _dueKind,
                  date: _dueDate,
                  hour: _hour,
                  minute: _minute,
                  onKindChanged: (kind) {
                    setState(() => _dueKind = kind);
                    _queueDraftWrite();
                  },
                  onDateChanged: (date) {
                    setState(() => _dueDate = date);
                    _queueDraftWrite();
                  },
                  onTimeChanged: (hour, minute) {
                    setState(() {
                      _hour = hour;
                      _minute = minute;
                    });
                    _queueDraftWrite();
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '颜色',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final color in CalendarColor.values)
                      _ColorSwatch(
                        color: color,
                        selected: _color == color,
                        onSelected: () {
                          setState(() => _color = color);
                          _queueDraftWrite();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  key: const Key('todo-calendar-switch'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('显示在日历'),
                  subtitle: const Text('在日历里按截止时间显示'),
                  value: _showInCalendar,
                  onChanged: (value) {
                    setState(() => _showInCalendar = value);
                    _queueDraftWrite();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('todo-notes-field'),
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: TodoStore.maxNotesLength,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    hintText: '补充地点、材料或下一步',
                    border: OutlineInputBorder(),
                    counterText: '',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => _handleFieldChanged(),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Notice(
                    key: const Key('todo-editor-error'),
                    icon: Icons.error_outline,
                    text: _errorText!,
                    color: theme.colorScheme.errorContainer,
                    foreground: theme.colorScheme.onErrorContainer,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    if (widget.todo != null)
                      TextButton.icon(
                        key: const Key('todo-delete'),
                        onPressed: _busy ? null : () => unawaited(_delete()),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('删除'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      key: const Key('todo-cancel'),
                      onPressed: _busy ? null : () => unawaited(_cancel()),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      key: const Key('todo-save'),
                      onPressed: _busy ? null : () => unawaited(_save()),
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _applyTodoToForm(Todo todo) {
    _titleController.text = todo.title;
    _notesController.text = todo.notes;
    _dueKind = todo.dueKind;
    _color = todo.color ?? CalendarColor.slate;
    _showInCalendar = todo.showInCalendar;
    if (todo.dueKind == TodoDueKind.dateOnly) {
      _dueDate = todo.dueDate!;
    } else if (todo.dueKind == TodoDueKind.exact) {
      final wall = schoolWallTime(todo.dueAtUtc!);
      _dueDate = LocalDate(wall.year, wall.month, wall.day);
      _hour = wall.hour;
      _minute = wall.minute;
    }
  }

  bool _applyDraft(Map<String, dynamic> draft) {
    final title = draft['title'];
    final notes = draft['notes'];
    if (title is! String || notes is! String) {
      return false;
    }
    _titleController.text = title;
    _notesController.text = notes;
    for (final kind in TodoDueKind.values) {
      if (draft['dueKind'] == kind.name) {
        _dueKind = kind;
      }
    }
    final dateText = draft['dueDate'];
    if (dateText is String) {
      try {
        _dueDate = LocalDate.parse(dateText);
      } on Object {
        // 损坏的草稿不应阻止编辑，保留当前日期继续。
      }
    }
    final hour = draft['hour'];
    if (hour is int && hour >= 0 && hour <= 23) {
      _hour = hour;
    }
    final minute = draft['minute'];
    if (minute is int && minute >= 0 && minute <= 59) {
      _minute = minute;
    }
    for (final color in CalendarColor.values) {
      if (draft['color'] == color.name) {
        _color = color;
      }
    }
    final showInCalendar = draft['showInCalendar'];
    if (showInCalendar is bool) {
      _showInCalendar = showInCalendar;
    }
    return true;
  }

  void _handleFieldChanged() {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
    _queueDraftWrite();
  }

  void _queueDraftWrite() {
    final payload = _draftPayload();
    _draftWrite = _draftWrite.then<void>((_) async {
      try {
        await widget.workspace.drafts.write(todoDraftScope, _draftKey, payload);
      } on Object {
        // 草稿写入失败不打断编辑，内存中的表单仍在。
      }
    });
  }

  Map<String, dynamic> _draftPayload() {
    return {
      'title': _titleController.text,
      'notes': _notesController.text,
      'dueKind': _dueKind.name,
      'dueDate': _dueDate.toIso8601String(),
      'hour': _hour,
      'minute': _minute,
      'color': _color.name,
      'showInCalendar': _showInCalendar,
    };
  }

  TodoDue _due() {
    return switch (_dueKind) {
      TodoDueKind.none => const TodoDue.none(),
      TodoDueKind.dateOnly => TodoDue.dateOnly(_dueDate),
      TodoDueKind.exact => TodoDue.exact(
        utcFromSchoolWallTime(
          _dueDate.year,
          _dueDate.month,
          _dueDate.day,
          _hour,
          _minute,
        ),
      ),
    };
  }

  Todo _updatedFrom(Todo todo) {
    final due = _due();
    return Todo(
      id: todo.id,
      userId: todo.userId,
      title: _titleController.text,
      notes: _notesController.text,
      dueKind: due.kind,
      dueDate: due.date,
      dueAtUtc: due.atUtc,
      color: _color,
      showInCalendar: _showInCalendar,
      completed: todo.completed,
      completedAtUtc: todo.completedAtUtc,
      revision: todo.revision,
      createdAtUtc: todo.createdAtUtc,
      updatedAtUtc: todo.updatedAtUtc,
    );
  }

  String? _validationError() {
    if (_titleController.text.trim().isEmpty) {
      return '请输入标题';
    }
    if (_titleController.text.trim().runes.length > TodoStore.maxTitleLength) {
      return '标题不能超过 200 个字符';
    }
    if (_notesController.text.runes.length > TodoStore.maxNotesLength) {
      return '备注不能超过 20000 个字符';
    }
    return null;
  }

  Future<void> _save() async {
    if (_busy) {
      return;
    }
    final validationError = _validationError();
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final due = _due();
      final base = _baseTodo;
      if (base == null) {
        await widget.workspace.todos.create(
          title: _titleController.text,
          notes: _notesController.text,
          due: due,
          color: _color,
          showInCalendar: _showInCalendar,
        );
      } else {
        await widget.workspace.todos.update(_updatedFrom(base));
      }
      await _clearDraft();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(TodoEditorOutcome.saved);
    } on TodoRevisionConflict catch (conflict) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _conflictCurrent = conflict.current;
      });
      _queueDraftWrite();
    } on TodoValidationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _errorText = error.message;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _errorText = '未保存：${describeTodoError(error)}';
      });
    }
  }

  Future<void> _delete() async {
    final base = _baseTodo;
    if (base == null || _busy) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条待办？'),
        content: Text(
          _titleController.text.trim().isEmpty
              ? base.title
              : _titleController.text.trim(),
        ),
        actions: [
          TextButton(
            key: const Key('todo-delete-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('todo-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      await widget.workspace.todos.delete(base.id, revision: base.revision);
      await _clearDraft();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(TodoEditorOutcome.deleted);
    } on TodoRevisionConflict catch (conflict) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _conflictCurrent = conflict.current;
      });
      _queueDraftWrite();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _errorText = '删除失败：${describeTodoError(error)}';
      });
    }
  }

  Future<void> _cancel() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    await _clearDraft();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _clearDraft() async {
    try {
      await widget.workspace.drafts.clear(todoDraftScope, _draftKey);
    } on Object {
      // 清理草稿失败不改变保存结果，下一次编辑会覆盖它。
    }
  }

  void _loadLatestConflict() {
    final current = _conflictCurrent;
    if (current == null) {
      return;
    }
    setState(() {
      _baseTodo = current;
      _conflictCurrent = null;
      _overwritePending = false;
      _errorText = null;
      _applyTodoToForm(current);
    });
    _queueDraftWrite();
  }

  void _keepDraft() {
    final current = _conflictCurrent;
    if (current == null) {
      return;
    }
    setState(() {
      _baseTodo = current;
      _conflictCurrent = null;
      _overwritePending = true;
    });
    _queueDraftWrite();
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({
    required this.busy,
    required this.onLoadLatest,
    required this.onKeepDraft,
  });

  final bool busy;
  final VoidCallback onLoadLatest;
  final VoidCallback onKeepDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('todo-conflict'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sync_problem_outlined,
                size: 20,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '内容已在别处更新',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '你的修改还在。载入最新版本会替换当前输入，保留草稿则继续使用当前内容。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton.tonal(
                key: const Key('todo-conflict-load'),
                onPressed: busy ? null : onLoadLatest,
                child: const Text('载入最新版本'),
              ),
              TextButton(
                key: const Key('todo-conflict-keep'),
                onPressed: busy ? null : onKeepDraft,
                child: const Text('保留我的草稿'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final CalendarColor color;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: color.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: '颜色${color.label}',
        child: InkWell(
          key: Key('todo-color-${color.name}'),
          borderRadius: BorderRadius.circular(999),
          onTap: onSelected,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: selected
                ? Icon(Icons.check, size: 16, color: color.accent)
                : null,
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.foreground,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentColor = foreground ?? AppTheme.foreground;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: contentColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: contentColor),
            ),
          ),
        ],
      ),
    );
  }
}
