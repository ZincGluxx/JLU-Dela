import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/local_date.dart';
import '../../core/models/todo.dart';

class TodoDueFields extends StatelessWidget {
  const TodoDueFields({
    super.key,
    required this.kind,
    required this.date,
    required this.hour,
    required this.minute,
    required this.onKindChanged,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  final TodoDueKind kind;
  final LocalDate date;
  final int hour;
  final int minute;
  final ValueChanged<TodoDueKind> onKindChanged;
  final ValueChanged<LocalDate> onDateChanged;
  final void Function(int hour, int minute) onTimeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _kindChip(
              key: const Key('todo-due-kind-none'),
              label: '无截止',
              value: TodoDueKind.none,
            ),
            _kindChip(
              key: const Key('todo-due-kind-date'),
              label: '仅日期',
              value: TodoDueKind.dateOnly,
            ),
            _kindChip(
              key: const Key('todo-due-kind-exact'),
              label: '日期与时间',
              value: TodoDueKind.exact,
            ),
          ],
        ),
        if (kind != TodoDueKind.none) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 2,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: [
              _StepperCell(
                keyPrefix: 'todo-due-year',
                label: '年份',
                display: '${date.year}年',
                onDecrease: () => onDateChanged(_stepYear(date, -1)),
                onIncrease: () => onDateChanged(_stepYear(date, 1)),
              ),
              _StepperCell(
                keyPrefix: 'todo-due-month',
                label: '月份',
                display: '${date.month}月',
                onDecrease: () => onDateChanged(_stepMonth(date, -1)),
                onIncrease: () => onDateChanged(_stepMonth(date, 1)),
              ),
              _StepperCell(
                keyPrefix: 'todo-due-day',
                label: '日期',
                display: '${date.day}日',
                onDecrease: () => onDateChanged(_stepDay(date, -1)),
                onIncrease: () => onDateChanged(_stepDay(date, 1)),
              ),
              if (kind == TodoDueKind.exact) ...[
                _StepperCell(
                  keyPrefix: 'todo-due-hour',
                  label: '小时',
                  display: '${hour.toString().padLeft(2, '0')}时',
                  onDecrease: () => onTimeChanged((hour + 23) % 24, minute),
                  onIncrease: () => onTimeChanged((hour + 1) % 24, minute),
                ),
                _StepperCell(
                  keyPrefix: 'todo-due-minute',
                  label: '分钟',
                  display: '${minute.toString().padLeft(2, '0')}分',
                  onDecrease: () => onTimeChanged(hour, (minute + 59) % 60),
                  onIncrease: () => onTimeChanged(hour, (minute + 1) % 60),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            kind == TodoDueKind.exact
                ? '按北京时间（UTC+8）输入，保存为 UTC 毫秒。'
                : '全天事项，只记校园当地日期，不推算具体时刻。',
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
          ),
        ],
      ],
    );
  }

  Widget _kindChip({
    required Key key,
    required String label,
    required TodoDueKind value,
  }) {
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: kind == value,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: AppTheme.blueSoft,
      onSelected: (_) => onKindChanged(value),
    );
  }
}

const int _minYear = 1970;
const int _maxYear = 2100;

int _daysInMonth(int year, int month) {
  return DateTime.utc(year, month + 1, 0).day;
}

LocalDate _clampDate(LocalDate date) {
  if (date.year < _minYear) {
    return const LocalDate(_minYear, 1, 1);
  }
  if (date.year > _maxYear) {
    return const LocalDate(_maxYear, 12, 31);
  }
  return date;
}

LocalDate _stepYear(LocalDate date, int delta) {
  final year = date.year + delta;
  if (year < _minYear || year > _maxYear) {
    return date;
  }
  final day = date.day > _daysInMonth(year, date.month)
      ? _daysInMonth(year, date.month)
      : date.day;
  return LocalDate(year, date.month, day);
}

LocalDate _stepMonth(LocalDate date, int delta) {
  var year = date.year;
  var month = date.month + delta;
  if (month < 1) {
    month = 12;
    year--;
  } else if (month > 12) {
    month = 1;
    year++;
  }
  if (year < _minYear || year > _maxYear) {
    return date;
  }
  final day = date.day > _daysInMonth(year, month)
      ? _daysInMonth(year, month)
      : date.day;
  return LocalDate(year, month, day);
}

LocalDate _stepDay(LocalDate date, int delta) =>
    _clampDate(date.addDays(delta));

class _StepperCell extends StatelessWidget {
  const _StepperCell({
    required this.keyPrefix,
    required this.label,
    required this.display,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String keyPrefix;
  final String label;
  final String display;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('$keyPrefix-minus'),
            tooltip: '$label减',
            onPressed: onDecrease,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 36),
            icon: const Icon(Icons.chevron_left, size: 16),
          ),
          SizedBox(
            width: 44,
            child: Text(
              display,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            key: Key('$keyPrefix-plus'),
            tooltip: '$label增',
            onPressed: onIncrease,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 36),
            icon: const Icon(Icons.chevron_right, size: 16),
          ),
        ],
      ),
    );
  }
}
