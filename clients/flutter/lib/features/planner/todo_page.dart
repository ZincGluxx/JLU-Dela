import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/school_time.dart';
import '../../core/models/todo.dart';
import '../../core/storage/local_workspace.dart';
import '../../core/storage/todo_store.dart';
import 'todo_draft.dart';
import 'todo_editor.dart';
import 'todo_format.dart';
import 'todo_list_tile.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key, required this.workspace});

  final LocalWorkspace workspace;

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  List<Todo>? _todos;
  Object? _loadError;
  bool _loading = true;
  bool _hasNewDraft = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_refreshNewDraft());
  }

  @override
  void didUpdateWidget(covariant TodoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.workspace, widget.workspace)) {
      _todos = null;
      _loadError = null;
      _loading = true;
      _hasNewDraft = false;
      unawaited(_load());
      unawaited(_refreshNewDraft());
    }
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_loadGeneration;
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final todos = await widget.workspace.todos.list();
      todos.sort(_compareTodos);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _todos = todos;
        _loading = false;
        _loadError = null;
      });
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _refreshNewDraft() async {
    Map<String, dynamic>? draft;
    try {
      draft = await widget.workspace.drafts.read(
        todoDraftScope,
        todoNewDraftKey,
      );
    } on Object {
      draft = null;
    }
    if (!mounted) {
      return;
    }
    setState(() => _hasNewDraft = draft != null);
  }

  Future<void> _discardNewDraft() async {
    try {
      await widget.workspace.drafts.clear(todoDraftScope, todoNewDraftKey);
    } on Object {
      // 清理失败时仍隐藏横幅，草稿会在下次编辑中覆盖。
    }
    if (!mounted) {
      return;
    }
    setState(() => _hasNewDraft = false);
  }

  Future<void> _openEditor({Todo? todo}) async {
    Map<String, dynamic>? draft;
    try {
      draft = await widget.workspace.drafts.read(
        todoDraftScope,
        todoDraftKeyFor(todo),
      );
    } on Object {
      draft = null;
    }
    if (!mounted) {
      return;
    }
    final outcome = await showDialog<TodoEditorOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          TodoEditor(workspace: widget.workspace, todo: todo, draft: draft),
    );
    if (!mounted) {
      return;
    }
    await _refreshNewDraft();
    if (!mounted) {
      return;
    }
    await _load(silent: true);
    if (!mounted || outcome == null) {
      return;
    }
    _showMessage(outcome == TodoEditorOutcome.saved ? '已保存' : '已删除');
  }

  Future<void> _toggleCompleted(Todo todo) async {
    try {
      await widget.workspace.todos.setCompleted(
        todo.id,
        revision: todo.revision,
        completed: !todo.completed,
      );
      await _load(silent: true);
    } on TodoRevisionConflict {
      await _load(silent: true);
      if (mounted) {
        _showMessage('内容已在别处更新，已刷新列表');
      }
    } on Object catch (error) {
      if (mounted) {
        _showMessage('操作失败：${describeTodoError(error)}');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final narrow = width < AppBreakpoints.desktop;
        final horizontal = width > 880 + AppSpacing.xxl * 2
            ? (width - 880) / 2
            : (narrow ? AppSpacing.lg : AppSpacing.xl);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              _buildHeader(context, width),
              if (_hasNewDraft) ...[
                const SizedBox(height: AppSpacing.md),
                _NewDraftBanner(
                  onResume: () => unawaited(_openEditor()),
                  onDiscard: () => unawaited(_discardNewDraft()),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Expanded(child: _buildBody(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, double width) {
    final theme = Theme.of(context);
    final todos = _todos;
    final summary = todos == null || todos.isEmpty
        ? null
        : '${todos.where((todo) => !todo.completed).length} 项未完成 · '
              '${todos.where((todo) => todo.completed).length} 项已完成';
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '我的待办',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (summary != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            summary,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          ),
        ],
      ],
    );
    final createButton = FilledButton.icon(
      key: const Key('todo-create'),
      onPressed: () => unawaited(_openEditor()),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('新建待办'),
    );
    if (width < 560) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: AppSpacing.md),
          createButton,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        createButton,
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _todos == null) {
      return const _LoadingView();
    }
    final error = _loadError;
    if (error != null) {
      return _ErrorView(error: error, onRetry: () => unawaited(_load()));
    }
    final todos = _todos ?? const <Todo>[];
    if (todos.isEmpty) {
      return _EmptyView(onCreate: () => unawaited(_openEditor()));
    }
    final nowUtc = widget.workspace.now().toUtc();
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      itemCount: todos.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final todo = todos[index];
        return TodoListTile(
          todo: todo,
          nowUtc: nowUtc,
          onToggle: () => unawaited(_toggleCompleted(todo)),
          onEdit: () => unawaited(_openEditor(todo: todo)),
        );
      },
    );
  }
}

int _compareTodos(Todo a, Todo b) {
  if (a.completed != b.completed) {
    return a.completed ? 1 : -1;
  }
  final aDue = _dueSortKey(a);
  final bDue = _dueSortKey(b);
  if (aDue == null && bDue != null) {
    return 1;
  }
  if (aDue != null && bDue == null) {
    return -1;
  }
  if (aDue != null && bDue != null) {
    final dueOrder = aDue.compareTo(bDue);
    if (dueOrder != 0) {
      return dueOrder;
    }
  }
  final titleOrder = a.title.compareTo(b.title);
  if (titleOrder != 0) {
    return titleOrder;
  }
  return a.id.compareTo(b.id);
}

DateTime? _dueSortKey(Todo todo) => switch (todo.dueKind) {
  TodoDueKind.exact => todo.dueAtUtc!.toUtc(),
  TodoDueKind.dateOnly => schoolDayStartUtc(todo.dueDate!),
  TodoDueKind.none => null,
};

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        key: const Key('todo-loading'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '正在读取待办…',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          key: const Key('todo-empty'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist_outlined, size: 40, color: AppTheme.primary),
            const SizedBox(height: AppSpacing.lg),
            Text('还没有待办', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '把课程之外要做的事记在这里。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('todo-create-empty'),
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建第一条待办'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          key: const Key('todo-error'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storage_outlined,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('读取待办失败', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '本地数据库暂时不可用，请重试。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              describeTodoError(error),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('todo-retry'),
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewDraftBanner extends StatelessWidget {
  const _NewDraftBanner({required this.onResume, required this.onDiscard});

  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('todo-draft-banner'),
      color: AppTheme.blueSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(Icons.edit_note, size: 20, color: AppTheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('有一份未保存的新待办草稿', style: theme.textTheme.bodyMedium),
            ),
            TextButton(
              key: const Key('todo-draft-open'),
              onPressed: onResume,
              child: const Text('继续编辑'),
            ),
            IconButton(
              key: const Key('todo-draft-discard'),
              tooltip: '丢弃草稿',
              visualDensity: VisualDensity.compact,
              onPressed: onDiscard,
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
