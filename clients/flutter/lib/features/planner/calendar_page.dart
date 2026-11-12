import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/assignment.dart';
import '../../core/models/lesson.dart';
import '../../core/models/local_date.dart';
import '../../core/models/school_time.dart';
import '../../core/models/source.dart';
import '../../core/models/todo.dart';
import '../../core/source/source_session.dart';
import '../../core/storage/local_workspace.dart';
import '../../core/storage/todo_store.dart';
import 'calendar_details.dart';
import 'calendar_entries.dart';
import 'calendar_grid.dart';
import 'calendar_sources.dart';
import 'calendar_time.dart';
import 'calendar_views.dart';

enum _CalendarView { week, month, list }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.workspace});

  final LocalWorkspace workspace;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  _CalendarView _view = _CalendarView.week;
  late LocalDate _anchor;
  final Set<CalendarEntryKind> _kinds = CalendarEntryKind.values.toSet();
  bool _showCompleted = false;
  _CalendarData? _data;
  List<SourceSnapshot> _snapshots = const [];
  Object? _error;
  bool _loading = true;
  int _loadToken = 0;

  LocalWorkspace get _workspace => widget.workspace;

  LocalDate get _today => schoolDateOf(_workspace.now());

  @override
  void initState() {
    super.initState();
    _anchor = _today;
    _load();
  }

  CalendarDateRange get _range {
    return switch (_view) {
      _CalendarView.week => weekRangeOf(_anchor),
      _CalendarView.month => monthGridRangeOf(_anchor),
      _CalendarView.list => monthRangeOf(_anchor),
    };
  }

  bool get _hasAnyData {
    final data = _data;
    return data != null &&
        (data.todos.isNotEmpty ||
            data.lessons.isNotEmpty ||
            data.assignments.isNotEmpty);
  }

  List<CalendarSourceStatus> get _sourceStatuses {
    return [
      CalendarSourceStatus.from(
        source: SourceKind.jluIedu,
        connected:
            _workspace.sessions.stateFor(SourceKind.jluIedu) ==
            SourceConnectionState.connected,
        snapshots: _snapshots,
      ),
      CalendarSourceStatus.from(
        source: SourceKind.chaoxing,
        connected:
            _workspace.sessions.stateFor(SourceKind.chaoxing) ==
            SourceConnectionState.connected,
        snapshots: _snapshots,
      ),
    ];
  }

  Future<void> _load({bool silent = false}) async {
    final token = ++_loadToken;
    if (!silent) {
      if (_loading) {
        _error = null;
      } else {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
    }
    final range = _range;
    try {
      final todos = await _workspace.todos.list();
      final lessons = await _workspace.lessons.lessonsBetween(
        range.from,
        range.to,
      );
      final assignments = await _workspace.assignments.list(
        includeUndated: true,
        from: range.from,
        to: range.to,
      );
      final snapshots = await _workspace.sources.list();
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _data = _CalendarData(
          todos: todos,
          lessons: lessons,
          assignments: assignments,
        );
        _snapshots = snapshots;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || token != _loadToken) {
        return;
      }
      if (silent && _data != null) {
        setState(() => _loading = false);
        _showMessage('重新读取本地数据失败，请稍后重试');
        return;
      }
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _setView(_CalendarView view) {
    if (view == _view) {
      return;
    }
    setState(() => _view = view);
    _load();
  }

  void _shift(int amount) {
    setState(() {
      _anchor = switch (_view) {
        _CalendarView.week => _anchor.addDays(7 * amount),
        _CalendarView.month ||
        _CalendarView.list => shiftMonthStart(_anchor, amount),
      };
    });
    _load();
  }

  void _goToday() {
    setState(() => _anchor = _today);
    _load();
  }

  void _toggleKind(CalendarEntryKind kind, bool selected) {
    setState(() {
      if (selected) {
        _kinds.add(kind);
      } else {
        _kinds.remove(kind);
      }
    });
  }

  Future<void> _connect(SourceKind source) async {
    try {
      final result = await _workspace.campusLogin.connect(context, source);
      if (!mounted) {
        return;
      }
      setState(() {});
      _showMessage(
        result.connected
            ? '${source.label}已连接'
            : result.message ?? '${source.label}未连接',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('连接${source.label}失败，请稍后重试');
    }
  }

  Future<void> _showEntry(CalendarEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => CalendarEntryDetail(
        entry: entry,
        onToggleTodo: entry.todo == null ? null : _toggleTodo,
      ),
    );
  }

  Future<Todo?> _toggleTodo(Todo todo) async {
    try {
      final updated = await _workspace.todos.setCompleted(
        todo.id,
        revision: todo.revision,
        completed: !todo.completed,
      );
      await _load(silent: true);
      return updated;
    } on TodoRevisionConflict catch (conflict) {
      await _load(silent: true);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const Key('calendar-todo-conflict'),
            title: const Text('待办已更新'),
            content: const Text('这条待办已在其他页面修改，已重新读取最新状态。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
      return conflict.current;
    } catch (error) {
      _showMessage('更新待办失败，请稍后重试');
      return null;
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          if (!_loading && _error == null && _data != null) ...[
            const SizedBox(height: AppSpacing.xs),
            CalendarSourceStatusBar(
              statuses: _sourceStatuses,
              onLogin: _connect,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final label = switch (_view) {
      _CalendarView.week => calendarWeekLabel(weekRangeOf(_anchor).from),
      _CalendarView.month || _CalendarView.list => calendarMonthLabel(_anchor),
    };
    final periodLabel = _view == _CalendarView.week ? '周' : '月';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('calendar-previous'),
              tooltip: '上一$periodLabel',
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                label,
                key: const Key('calendar-range-label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const Key('calendar-next'),
              tooltip: '下一$periodLabel',
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              key: const Key('calendar-today'),
              onPressed: _goToday,
              child: const Text('今天'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final kind in CalendarEntryKind.values)
              FilterChip(
                key: Key('calendar-filter-${kind.name}'),
                label: Text(kind.label),
                selected: _kinds.contains(kind),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (selected) => _toggleKind(kind, selected),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  key: const Key('calendar-show-completed'),
                  value: _showCompleted,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) {
                    setState(() => _showCompleted = value);
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                const Text('显示已完成'),
              ],
            ),
            SegmentedButton<_CalendarView>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: _CalendarView.week,
                  label: Text('周', key: Key('calendar-view-week')),
                ),
                ButtonSegment(
                  value: _CalendarView.month,
                  label: Text('月', key: Key('calendar-view-month')),
                ),
                ButtonSegment(
                  value: _CalendarView.list,
                  label: Text('列表', key: Key('calendar-view-list')),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (selection) => _setView(selection.first),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const CalendarLoading();
    }
    final error = _error;
    if (error != null) {
      return CalendarFailure(message: '读取本地日历失败，请稍后重试。', onRetry: _load);
    }
    final data = _data;
    if (data == null) {
      return const CalendarLoading();
    }
    final entries = filterCalendarEntries(
      buildCalendarEntries(
        lessons: data.lessons,
        assignments: data.assignments,
        todos: data.todos,
      ),
      kinds: _kinds,
      showCompleted: _showCompleted,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.desktop;
        return switch (_view) {
          _CalendarView.week => _buildWeek(entries, wide: wide),
          _CalendarView.month => _buildMonth(entries),
          _CalendarView.list => _buildList(entries),
        };
      },
    );
  }

  Widget _buildWeek(List<CalendarEntry> entries, {required bool wide}) {
    final week = CalendarWeek.build(entries, weekRangeOf(_anchor).days);
    if (week.isEmpty) {
      return CalendarEmptyState(hasAnyData: _hasAnyData);
    }
    return _scrollable(
      wide
          ? CalendarWeekGrid(week: week, today: _today, onTap: _showEntry)
          : CalendarDayList(week: week, today: _today, onTap: _showEntry),
      week.undated,
    );
  }

  Widget _buildMonth(List<CalendarEntry> entries) {
    final range = monthGridRangeOf(_anchor);
    final visible = [
      for (final entry in entries)
        if (entry.date == null || range.contains(entry.date!)) entry,
    ];
    final grouped = groupCalendarEntriesByDate(visible);
    final undated = undatedCalendarEntries(visible);
    if (grouped.isEmpty && undated.isEmpty) {
      return CalendarEmptyState(hasAnyData: _hasAnyData);
    }
    return _scrollable(
      CalendarMonthGrid(
        month: firstOfMonth(_anchor),
        days: range.days,
        entriesByDate: grouped,
        today: _today,
        onTap: _showEntry,
      ),
      undated,
    );
  }

  Widget _buildList(List<CalendarEntry> entries) {
    final range = monthRangeOf(_anchor);
    final visible = [
      for (final entry in entries)
        if (entry.date == null || range.contains(entry.date!)) entry,
    ];
    final grouped = groupCalendarEntriesByDate(visible);
    final undated = undatedCalendarEntries(visible);
    if (grouped.isEmpty && undated.isEmpty) {
      return CalendarEmptyState(hasAnyData: _hasAnyData);
    }
    return _scrollable(
      CalendarListView(
        entriesByDate: grouped,
        today: _today,
        onTap: _showEntry,
      ),
      undated,
    );
  }

  Widget _scrollable(Widget content, List<CalendarEntry> undated) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            if (undated.isNotEmpty)
              CalendarUndatedSection(entries: undated, onTap: _showEntry),
          ],
        ),
      ),
    );
  }
}

class _CalendarData {
  const _CalendarData({
    required this.todos,
    required this.lessons,
    required this.assignments,
  });

  final List<Todo> todos;
  final List<Lesson> lessons;
  final List<Assignment> assignments;
}
