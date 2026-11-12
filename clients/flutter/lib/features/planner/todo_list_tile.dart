import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/todo.dart';
import 'todo_format.dart';

class TodoListTile extends StatelessWidget {
  const TodoListTile({
    super.key,
    required this.todo,
    required this.nowUtc,
    required this.onToggle,
    required this.onEdit,
  });

  final Todo todo;
  final DateTime nowUtc;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = todo.completed;
    final overdue = isTodoOverdue(todo, nowUtc);
    final dueColor = overdue ? theme.colorScheme.error : AppTheme.muted;
    final color = todo.color ?? CalendarColor.slate;
    final notes = todo.notes.trim();

    return Material(
      key: Key('todo-item-${todo.id}'),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Semantics(
                  label: completed ? '标记为未完成' : '标记为完成',
                  child: Checkbox(
                    key: Key('todo-checkbox-${todo.id}'),
                    value: completed,
                    visualDensity: VisualDensity.compact,
                    onChanged: (_) => onToggle(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            key: Key('todo-color-${todo.id}'),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: completed
                                  ? color.accent.withValues(alpha: 0.4)
                                  : color.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            todo.title,
                            key: Key('todo-title-${todo.id}'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: completed ? AppTheme.muted : null,
                              decoration: completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (todo.showInCalendar)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.xs),
                            child: Tooltip(
                              message: '显示在日历',
                              child: Icon(
                                Icons.calendar_month_outlined,
                                key: Key('todo-calendar-${todo.id}'),
                                size: 16,
                                color: AppTheme.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: dueColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            formatTodoDue(todo, nowUtc),
                            key: Key('todo-due-${todo.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: dueColor,
                              fontWeight: overdue ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        if (overdue) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '已逾期',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.muted.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: Key('todo-edit-${todo.id}'),
                tooltip: '编辑待办',
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
