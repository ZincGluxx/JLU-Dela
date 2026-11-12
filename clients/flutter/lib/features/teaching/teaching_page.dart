import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/local_date.dart';
import '../../core/models/school_time.dart';
import '../../core/models/source.dart';
import '../../core/source/source.dart';
import '../../core/source/source_session.dart';
import '../../core/storage/local_workspace.dart';
import 'teaching_store.dart';

const _weekDayLabels = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const _timelineStartMinute = 8 * 60;
const _timelineEndMinute = 22 * 60;
const _minuteHeight = 1.1;

class TeachingPage extends StatefulWidget {
  const TeachingPage({super.key, required this.workspace, required this.store});

  final LocalWorkspace workspace;
  final TeachingStore store;

  @override
  State<TeachingPage> createState() => _TeachingPageState();
}

class _TeachingPageState extends State<TeachingPage> {
  List<TeachingSemester> _semesters = const [];
  TeachingSemester? _semester;
  List<TeachingLessonDetail> _lessons = const [];
  List<String> _warnings = const [];
  SourceSnapshot? _snapshot;
  int _week = 1;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool? _errorHasCache;
  bool? _errorAuthRequired;
  String? _loginMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool keepWeek = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final semesters = await widget.store.listSemesters();
      var selected = _semester;
      if (selected != null) {
        selected = _findSemester(semesters, selected.code);
      }
      selected ??= _defaultSemester(semesters);
      if (!mounted) return;
      setState(() {
        _semesters = semesters;
        _semester = selected;
        if (!keepWeek) _week = _currentWeek(selected);
      });
      if (selected != null) await _loadWeek(selected, keepWeek: keepWeek);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '读取本地课表失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadWeek(
    TeachingSemester semester, {
    bool keepWeek = false,
  }) async {
    final weekCount = semester.totalWeeks;
    if (!keepWeek) {
      _week = _currentWeek(semester);
    } else if (weekCount != null && _week > weekCount) {
      _week = weekCount;
    }
    final firstMonday = semester.firstMonday;
    final warnings = await widget.store.warningsForSemester(semester.id);
    final snapshot = await widget.store.snapshotForSemester(semester.code);
    final lessons = firstMonday == null
        ? const <TeachingLessonDetail>[]
        : await widget.store.lessonDetailsBetween(
            semester.id,
            firstMonday.addDays((_week - 1) * 7),
            firstMonday.addDays(_week * 7),
          );
    if (!mounted) return;
    setState(() {
      _warnings = warnings;
      _snapshot = snapshot;
      _lessons = lessons;
    });
  }

  TeachingSemester? _defaultSemester(List<TeachingSemester> semesters) {
    if (semesters.isEmpty) return null;
    for (final semester in semesters) {
      if (semester.isCurrent) return semester;
    }
    return semesters.first;
  }

  TeachingSemester? _findSemester(
    List<TeachingSemester> semesters,
    String code,
  ) {
    for (final semester in semesters) {
      if (semester.code == code) return semester;
    }
    return null;
  }

  int _currentWeek(TeachingSemester? semester) {
    final firstMonday = semester?.firstMonday;
    if (firstMonday == null) return 1;
    final today = schoolDateOf(widget.workspace.now());
    final difference = today.differenceInDays(firstMonday);
    final week = difference < 0 ? 1 : difference ~/ 7 + 1;
    final count = semester?.totalWeeks;
    if (count != null && week > count) return count;
    return week;
  }

  int get _weekCount {
    final count = _semester?.totalWeeks;
    if (count == null || count < 1) return 1;
    return count;
  }

  Future<void> _switchSemester(TeachingSemester semester) async {
    setState(() {
      _semester = semester;
      _week = _currentWeek(semester);
      _error = null;
    });
    await _loadWeek(semester);
  }

  Future<void> _selectWeek(int week) async {
    final semester = _semester;
    if (semester == null) return;
    setState(() => _week = week);
    await _loadWeek(semester, keepWeek: true);
  }

  Future<void> _sync() async {
    setState(() {
      _busy = true;
      _error = null;
      _errorHasCache = null;
      _errorAuthRequired = null;
      _loginMessage = null;
    });
    try {
      var target = _semester;
      if (target == null) {
        final current = await widget.store.syncCurrentSemester();
        switch (current) {
          case SourceSuccess<String>():
            await _load();
            target = _semester;
          case SourceFailed<String>(:final failure, :final hasCachedData):
            if (!mounted) return;
            setState(() {
              _error = failure.message;
              _errorHasCache = hasCachedData;
              _errorAuthRequired =
                  failure.code == SourceErrorCodes.sourceAuthRequired;
            });
            return;
        }
      }
      if (target == null) {
        if (!mounted) return;
        setState(() => _error = '没有可同步的学期');
        return;
      }
      final result = await widget.store.refreshSemester(
        semesterCode: target.code,
      );
      switch (result) {
        case SourceSuccess():
          await _load(keepWeek: true);
        case SourceFailed(:final failure, :final hasCachedData):
          if (!mounted) return;
          setState(() {
            _error = failure.message;
            _errorHasCache = hasCachedData;
            _errorAuthRequired =
                failure.code == SourceErrorCodes.sourceAuthRequired;
          });
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '同步失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectSource() async {
    setState(() {
      _busy = true;
      _loginMessage = null;
      _error = null;
    });
    try {
      final result = await widget.workspace.campusLogin.connect(
        context,
        teachingSource,
      );
      if (!mounted) return;
      setState(() {
        _loginMessage = result.connected
            ? '教务来源已连接，可以同步课表'
            : (result.message ?? '教务来源登录未完成');
      });
      if (result.connected) await _load(keepWeek: true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '打开来源登录失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _sourceConnected =>
      widget.workspace.sessions.stateFor(teachingSource) ==
      SourceConnectionState.connected;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        if (_error != null) _buildError(),
        if (_loginMessage != null) _buildNotice(_loginMessage!),
        if (_warnings.isNotEmpty) _buildWarnings(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    final semester = _semester;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_outlined, color: AppTheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  semester?.name ?? '课表',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('teaching-sync'),
                tooltip: '同步教务课表',
                onPressed: _busy ? null : _sync,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
              ),
              TextButton.icon(
                key: const Key('teaching-login'),
                onPressed: _busy ? null : _connectSource,
                icon: Icon(
                  _sourceConnected
                      ? Icons.verified_user_outlined
                      : Icons.login_outlined,
                  size: 18,
                ),
                label: Text(_sourceConnected ? '重新登录来源' : '登录教务来源'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_semesters.length > 1)
                DropdownButton<TeachingSemester>(
                  key: const Key('teaching-semester'),
                  value: semester,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final item in _semesters)
                      DropdownMenuItem(value: item, child: Text(item.name)),
                  ],
                  onChanged: _busy || semester == null
                      ? null
                      : (value) {
                          if (value != null) _switchSemester(value);
                        },
                ),
              if (semester?.firstMonday != null) ...[
                _weekStepper(),
                Text(
                  '第 $_week / $_weekCount 周',
                  key: const Key('teaching-week-label'),
                  style: const TextStyle(color: AppTheme.muted),
                ),
                TextButton(
                  key: const Key('teaching-week-today'),
                  onPressed: _busy
                      ? null
                      : () {
                          final week = _currentWeek(semester);
                          if (week != _week) _selectWeek(week);
                        },
                  child: const Text('本周'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildSourceStatus(),
        ],
      ),
    );
  }

  Widget _weekStepper() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('teaching-week-previous'),
          tooltip: '上一周',
          onPressed: _busy || _week <= 1 ? null : () => _selectWeek(_week - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          key: const Key('teaching-week-next'),
          tooltip: '下一周',
          onPressed: _busy || _week >= _weekCount
              ? null
              : () => _selectWeek(_week + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildSourceStatus() {
    final snapshot = _snapshot;
    final parts = <String>[
      _sourceConnected ? '来源已连接' : '来源未连接（教务登录仅保存在内存）',
      if (snapshot?.lastSuccessAtUtc != null)
        '上次成功 ${_formatDateTime(snapshot!.lastSuccessAtUtc!)}'
      else
        '尚未成功同步',
      if (snapshot?.lastErrorCode != null)
        '上次失败 ${snapshot!.lastErrorCode}：${snapshot.lastErrorMessage ?? ''}',
    ];
    return Text(
      parts.join(' · '),
      key: const Key('teaching-source-status'),
      style: const TextStyle(color: AppTheme.muted, fontSize: 12),
    );
  }

  Widget _buildError() {
    final text = <String>[
      _error!,
      if (_errorHasCache == true) '本地仍显示上次成功同步的课表。',
      if (_errorAuthRequired == true) '请在设备上重新登录教务来源后再同步。',
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
        border: Border.all(color: const Color(0xFFF0C48A)),
      ),
      child: Text(
        text.join('\n'),
        key: const Key('teaching-error'),
        style: const TextStyle(color: Color(0xFF8A5A00)),
      ),
    );
  }

  Widget _buildNotice(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        message,
        key: const Key('teaching-login-message'),
        style: const TextStyle(color: AppTheme.muted),
      ),
    );
  }

  Widget _buildWarnings() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '同步警告',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          for (final warning in _warnings)
            Text(
              warning,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final semester = _semester;
    if (_semesters.isEmpty || semester == null) {
      return _buildEmpty();
    }
    if (semester.firstMonday == null) {
      return _buildEmpty(
        title: '尚未获取校历',
        description: '同步教务课表后才会得到开学日期与节次；没有校历不会推算课程日期。',
      );
    }
    if (_lessons.isEmpty) {
      return Center(
        child: Text(
          '第 $_week 周暂无课程',
          key: const Key('teaching-empty-week'),
          style: const TextStyle(color: AppTheme.muted),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return _buildWeekGrid(semester);
        }
        return _buildDayList(semester);
      },
    );
  }

  Widget _buildEmpty({
    String title = '还没有本地课表',
    String description = '先登录教务来源，再同步当前学期；课表只保存在本机。',
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_note_outlined,
              size: 40,
              color: AppTheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('teaching-sync-empty'),
              onPressed: _busy ? null : _sync,
              child: const Text('同步当前学期'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekGrid(TeachingSemester semester) {
    final weekStart = semester.firstMonday!.addDays((_week - 1) * 7);
    final today = schoolDateOf(widget.workspace.now());
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              for (var day = 0; day < 7; day++)
                Expanded(
                  child: _dayHeader(
                    _weekDayLabels[day],
                    weekStart.addDays(day),
                    today,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: (_timelineEndMinute - _timelineStartMinute) * _minuteHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 48, child: _hourAxis()),
                for (var day = 1; day <= 7; day++)
                  Expanded(child: _dayColumn(day, weekStart)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayHeader(String label, LocalDate date, LocalDate today) {
    final isToday = date == today;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: isToday ? AppTheme.primary : null,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${date.month}月${date.day}日',
              style: TextStyle(
                fontSize: 12,
                color: isToday ? Colors.white : null,
                fontWeight: isToday ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hourAxis() {
    final hours = (_timelineEndMinute - _timelineStartMinute) ~/ 60;
    return Stack(
      children: [
        for (var index = 0; index <= hours; index++)
          Positioned(
            top: index * 60 * _minuteHeight - 7,
            right: 4,
            child: Text(
              '${8 + index}:00',
              style: const TextStyle(color: AppTheme.muted, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _dayColumn(int weekday, LocalDate weekStart) {
    final dayLessons = _lessons
        .where((detail) => detail.weekday == weekday)
        .toList();
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppTheme.border),
                top: BorderSide(color: AppTheme.border),
              ),
            ),
          ),
        ),
        for (final detail in dayLessons) _positionedLesson(detail),
      ],
    );
  }

  Widget _positionedLesson(TeachingLessonDetail detail) {
    final start = _minuteOfDay(detail.lesson.startsAtUtc);
    final end = _minuteOfDay(detail.lesson.endsAtUtc);
    final top = (start - _timelineStartMinute) * _minuteHeight;
    final height = ((end - start) * _minuteHeight).clamp(28.0, 400.0);
    final showMeta = height >= 48;
    final color = _lessonColor(detail.lesson.title);
    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: InkWell(
          key: Key('teaching-lesson-grid-${detail.lesson.id}'),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          onTap: () => _showLessonDetail(detail),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.lesson.title,
                  maxLines: showMeta ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showMeta)
                  Text(
                    [
                      if (detail.teacher != null) detail.teacher,
                      if (detail.lesson.location != null)
                        detail.lesson.location,
                    ].whereType<String>().join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayList(TeachingSemester semester) {
    final weekStart = semester.firstMonday!.addDays((_week - 1) * 7);
    final today = schoolDateOf(widget.workspace.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      children: [
        for (var weekday = 1; weekday <= 7; weekday++)
          ..._daySection(weekday, weekStart, today),
      ],
    );
  }

  List<Widget> _daySection(int weekday, LocalDate weekStart, LocalDate today) {
    final dayLessons =
        _lessons.where((detail) => detail.weekday == weekday).toList()..sort(
          (a, b) => a.lesson.startsAtUtc.compareTo(b.lesson.startsAtUtc),
        );
    if (dayLessons.isEmpty) return const [];
    final date = weekStart.addDays(weekday - 1);
    final isToday = date == today;
    return [
      Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.xs,
        ),
        child: Text(
          '${_weekDayLabels[weekday - 1]} ${date.month}月${date.day}日'
          '${isToday ? ' · 今天' : ''}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isToday ? AppTheme.primary : null,
          ),
        ),
      ),
      for (final detail in dayLessons)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Material(
            color: _lessonColor(detail.lesson.title),
            borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
            child: InkWell(
              key: Key('teaching-lesson-list-${detail.lesson.id}'),
              borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
              onTap: () => _showLessonDetail(detail),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatSchoolClock(detail.lesson.startsAtUtc),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            detail.lesson.periodStart != null &&
                                    detail.lesson.periodEnd != null
                                ? '${detail.lesson.periodStart}–'
                                      '${detail.lesson.periodEnd}节'
                                : '',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.lesson.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (detail.lesson.location != null)
                                detail.lesson.location,
                              if (detail.teacher != null) detail.teacher,
                            ].whereType<String>().join(' · '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }

  void _showLessonDetail(TeachingLessonDetail detail) {
    final lesson = detail.lesson;
    final date = schoolDateOf(lesson.startsAtUtc);
    final rows = <(String, String)>[
      (
        '时间',
        '${date.month}月${date.day}日 '
            '${formatSchoolClock(lesson.startsAtUtc)}–'
            '${formatSchoolClock(lesson.endsAtUtc)}',
      ),
      if (lesson.periodStart != null && lesson.periodEnd != null)
        ('节次', '${lesson.periodStart}–${lesson.periodEnd}节'),
      if (detail.weekNumber != null) ('教学周', '第 ${detail.weekNumber} 周'),
      if (lesson.location != null) ('地点', lesson.location!),
      if (detail.teacher != null) ('教师', detail.teacher!),
      if (detail.note != null) ('调整', detail.note!),
    ];
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lesson.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text('${row.$1}：${row.$2}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  int _minuteOfDay(DateTime instant) {
    final school = instant.toUtc().add(schoolUtcOffset);
    return school.hour * 60 + school.minute;
  }

  String _formatDateTime(DateTime instant) {
    final school = instant.toUtc().add(schoolUtcOffset);
    final hour = school.hour.toString().padLeft(2, '0');
    final minute = school.minute.toString().padLeft(2, '0');
    return '${school.year}-${school.month.toString().padLeft(2, '0')}-'
        '${school.day.toString().padLeft(2, '0')} $hour:$minute';
  }
}

Color _lessonColor(String title) {
  const palette = <Color>[
    Color(0xFFEAF2FD),
    Color(0xFFFDF0E6),
    Color(0xFFF3EDFB),
    Color(0xFFE8F5EE),
    Color(0xFFFBEFF1),
    Color(0xFFEEF0F4),
  ];
  var hash = 0;
  for (final unit in title.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}
