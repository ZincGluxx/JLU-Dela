import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/models/assignment.dart';
import '../../core/models/course.dart';
import '../../core/models/source.dart';
import '../../core/source/source.dart';
import '../../core/storage/local_workspace.dart';
import 'assignment_deadline.dart';
import 'assignment_grouping.dart';
import 'assignment_status.dart';
import 'chaoxing_store.dart';

enum _BoardFilter { pending, all, done, ignored }

class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({
    super.key,
    required this.workspace,
    required this.store,
  });

  final LocalWorkspace workspace;
  final ChaoxingStore store;

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  final TextEditingController _query = TextEditingController();
  final TextEditingController _remark = TextEditingController();
  List<CourseOffering> _courses = const [];
  List<Assignment> _assignments = const [];
  SourceSnapshot? _coursesSnapshot;
  ChaoxingRefreshReport? _report;
  _BoardFilter _filter = _BoardFilter.pending;
  String _courseId = '';
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _notice;
  Timer? _clock;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = widget.workspace.now();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = widget.workspace.now());
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _query.dispose();
    _remark.dispose();
    super.dispose();
  }

  bool get _connected =>
      widget.workspace.sessions.hasSession(SourceKind.chaoxing) ||
      widget.store.hasSourceSession;

  String _courseName(String? courseOfferingId) {
    for (final course in _courses) {
      if (course.id == courseOfferingId) {
        return (course.remark?.isNotEmpty ?? false)
            ? course.remark!
            : course.name;
      }
    }
    return '未命名课程';
  }

  String _statusLabel(Assignment assignment) {
    final known = sourceStatusByCode(assignment.sourceStatus);
    if (known != null && known != ChaoxingSourceStatus.unknown) {
      return known.label;
    }
    final text = assignment.sourceStatusText?.trim();
    return text == null || text.isEmpty ? '状态待确认' : text;
  }

  Future<void> _load() async {
    try {
      final courses = await widget.store.listCourses();
      final assignments = await widget.store.list();
      final snapshot = await widget.store.coursesSnapshot();
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _assignments = assignments;
        _coursesSnapshot = snapshot;
        _loading = false;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _refreshAll() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final report = await widget.store.refreshAll(http: widget.workspace.http);
      await _load();
      if (!mounted) return;
      setState(() {
        _report = report;
        if (report.requiresLogin) {
          _notice = '学习通登录已失效，请重新登录学习通后刷新。';
        } else if (report.isSuccess) {
          _notice = '已更新学习通课程与作业。';
        }
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '刷新学习通失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retryCourse(ChaoxingCourseFailure failure) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.store.refreshCourse(
        failure.courseOfferingId,
        http: widget.workspace.http,
      );
      await _load();
      if (!mounted) return;
      switch (result) {
        case SourceFailed(failure: final resultFailure):
          setState(() => _notice = '重试失败：${resultFailure.message}');
        case SourceSuccess():
          setState(() {
            _report = ChaoxingRefreshReport(
              courseFailures: [
                for (final item
                    in _report?.courseFailures ??
                        const <ChaoxingCourseFailure>[])
                  if (item.courseOfferingId != failure.courseOfferingId) item,
              ],
            );
            _notice = '已更新「${failure.courseName}」的作业。';
          });
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '重试失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await widget.workspace.campusLogin.connect(
        context,
        SourceKind.chaoxing,
      );
      if (!mounted) return;
      if (result.connected) {
        await _refreshAll();
      } else {
        setState(() => _notice = result.message ?? '学习通登录尚未完成，请稍后重试。');
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '连接学习通失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setRetained(CourseOffering course, bool retained) async {
    try {
      await widget.store.setCourseRetained(course.id, retained);
      await _load();
    } on Object catch (error) {
      if (mounted) _showMessage('保存课程选择失败：$error');
    }
  }

  Future<void> _editRemark(CourseOffering course) async {
    _remark.text = course.remark ?? '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('课程备注名'),
        content: TextField(
          key: const Key('course-remark-field'),
          controller: _remark,
          autofocus: true,
          maxLength: ChaoxingStore.maxRemarkLength,
          decoration: const InputDecoration(hintText: '留空恢复学习通课程名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_remark.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    try {
      await widget.store.setCourseRemark(course.id, value);
      await _load();
    } on Object catch (error) {
      if (mounted) _showMessage('保存备注失败：$error');
    }
  }

  Future<void> _mark(Assignment assignment, {bool? read, bool? muted}) async {
    try {
      await widget.store.setMarks(assignment.id, read: read, muted: muted);
      await _load();
    } on Object catch (error) {
      if (mounted) _showMessage('保存标记失败：$error');
    }
  }

  Future<void> _openAssignment(Assignment assignment) async {
    setState(() => _error = null);
    Uri? sourceUri;
    try {
      final access = await widget.store.openAssignment(
        assignmentId: assignment.id,
      );
      sourceUri = access.uri;
      if (!mounted) return;
      await widget.workspace.browser.openPage(
        context,
        source: SourceKind.chaoxing,
        uri: access.uri,
      );
    } on Object catch (error) {
      if (!mounted) return;
      final failure = error is SourceException ? error.failure : null;
      final message = failure?.message ?? '$error';
      if (sourceUri != null &&
          failure?.code == SourceErrorCodes.sourceUnavailable) {
        await _showSourceUri(sourceUri, message);
        return;
      }
      setState(() => _error = '无法打开原网页：$message');
    }
  }

  /// 来源浏览器尚未接入时，至少给出已校验的地址并允许复制。
  Future<void> _showSourceUri(Uri uri, String note) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('学习通原网页'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note),
            const SizedBox(height: AppSpacing.md),
            SelectableText(
              uri.toString(),
              key: const Key('assignment-source-url'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: uri.toString()));
              if (context.mounted) Navigator.of(context).pop();
              if (mounted) _showMessage('已复制学习通作业入口');
            },
            child: const Text('复制链接'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<Assignment> get _visible {
    final needle = _query.text.trim().toLowerCase();
    final items = <Assignment>[];
    for (final assignment in _assignments) {
      if (_courseId.isNotEmpty && assignment.courseOfferingId != _courseId) {
        continue;
      }
      if (needle.isNotEmpty) {
        final haystack =
            '${assignment.title} ${_courseName(assignment.courseOfferingId)}'
                .toLowerCase();
        if (!haystack.contains(needle)) continue;
      }
      items.add(assignment);
    }
    items.sort(compareAssignmentDue);
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final summary = workSummary(_visible, _now);
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SourceBar(
            connected: _connected,
            busy: _busy,
            snapshot: _coursesSnapshot,
            onConnect: _connect,
            onRefresh: _refreshAll,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _MessageBanner(message: _error!, isError: true),
          ],
          if (_notice != null) ...[
            const SizedBox(height: AppSpacing.md),
            _MessageBanner(message: _notice!, isError: false),
          ],
          if (_report != null && !_report!.isSuccess) ...[
            const SizedBox(height: AppSpacing.md),
            _FailureBanner(
              report: _report!,
              busy: _busy,
              onRetry: _retryCourse,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _Toolbar(
            summary: summary,
            filter: _filter,
            courses: _courses,
            courseId: _courseId,
            queryController: _query,
            busy: _busy,
            onFilterChanged: (value) => setState(() => _filter = value),
            onCourseChanged: (value) => setState(() => _courseId = value ?? ''),
            onQueryChanged: (_) => setState(() {}),
            onManageCourses: _showCourses,
            onRefresh: _connected && !_busy ? _refreshAll : null,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_courses.isEmpty)
            const _EmptyHint(
              key: Key('assignments-empty-courses'),
              text:
                  '还没有学习通课程缓存。请先连接学习通并刷新；'
                  '刷新失败时会保留上次成功读取的数据。',
            )
          else if (_assignments.isEmpty)
            const _EmptyHint(
              key: Key('assignments-empty-work'),
              text:
                  '还没有作业缓存。连接学习通后点击「刷新」，'
                  '作业看板会按截止时间分组显示。',
            )
          else
            ..._buildSections(context),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final visible = _visible;
    final widgets = <Widget>[];
    for (final section in workSections) {
      if (!_filterAccepts(section)) continue;
      final items = visible
          .where((assignment) => workSection(assignment, _now) == section)
          .toList(growable: false);
      if (items.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Row(
            children: [
              Text(
                '${workSectionLabels[section]} · ${items.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: section == WorkSection.overdue
                      ? Theme.of(context).colorScheme.error
                      : AppTheme.foreground,
                ),
              ),
            ],
          ),
        ),
      );
      widgets.add(
        Container(
          key: Key('assignment-section-${section.name}'),
          margin: const EdgeInsets.only(top: AppSpacing.sm),
          decoration: AppTheme.surfaceDecoration(context),
          child: Column(
            children: [
              for (final assignment in items) ...[
                _AssignmentTile(
                  assignment: assignment,
                  courseName: _courseName(assignment.courseOfferingId),
                  statusLabel: _statusLabel(assignment),
                  timeText: assignmentTimeText(assignment, _now),
                  overdue: workSection(assignment, _now) == WorkSection.overdue,
                  canOpen: _connected,
                  onOpen: () => _openAssignment(assignment),
                  onMarkRead: () =>
                      _mark(assignment, read: assignment.readAtUtc == null),
                  onMarkMuted: () =>
                      _mark(assignment, muted: assignment.mutedAtUtc == null),
                ),
                if (assignment != items.last)
                  const Divider(height: 1, indent: AppSpacing.md),
              ],
            ],
          ),
        ),
      );
    }
    if (widgets.isEmpty) {
      widgets.add(
        _EmptyHint(
          key: const Key('assignments-empty-filter'),
          text: switch (_filter) {
            _BoardFilter.pending => '当前没有待完成的作业。',
            _BoardFilter.done => '还没有读到已完成的作业。',
            _BoardFilter.ignored => '还没有忽略的作业。',
            _BoardFilter.all => '没有匹配的作业。',
          },
        ),
      );
    }
    return widgets;
  }

  bool _filterAccepts(WorkSection section) {
    return switch (_filter) {
      _BoardFilter.pending =>
        section == WorkSection.overdue ||
            section == WorkSection.soon ||
            section == WorkSection.later ||
            section == WorkSection.undated,
      _BoardFilter.done => section == WorkSection.done,
      _BoardFilter.ignored => section == WorkSection.ignored,
      _BoardFilter.all => true,
    };
  }

  Future<void> _showCourses() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('学习通课程'),
        content: SizedBox(
          width: 420,
          child: _courses.isEmpty
              ? const Text('还没有课程缓存，请先连接学习通并刷新。')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final course in _courses)
                      ListTile(
                        key: Key('course-row-${course.id}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          (course.remark?.isNotEmpty ?? false)
                              ? course.remark!
                              : course.name,
                        ),
                        subtitle: Text(course.name),
                        leading: Switch(
                          key: Key('course-retained-${course.id}'),
                          value: course.retained,
                          onChanged: (value) => _setRetained(course, value),
                        ),
                        trailing: IconButton(
                          key: Key('course-remark-${course.id}'),
                          tooltip: '编辑备注名',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editRemark(course),
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
        ],
      ),
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
            AppSpacing.md,
            horizontal,
            0,
          ),
          child: child,
        );
      },
    );
  }
}

class _SourceBar extends StatelessWidget {
  const _SourceBar({
    required this.connected,
    required this.busy,
    required this.snapshot,
    required this.onConnect,
    required this.onRefresh,
  });

  final bool connected;
  final bool busy;
  final SourceSnapshot? snapshot;
  final Future<void> Function() onConnect;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final lastSuccess = snapshot?.lastSuccessAtUtc;
    final lastError = snapshot?.lastErrorCode;
    final lines = <String>[
      connected ? '学习通已连接（本次运行）' : '学习通未连接：请手动登录学习通来源',
      if (lastSuccess != null)
        '上次成功：${lastSuccess.toLocal().toString().substring(0, 16)}',
      if (lastError != null) '上次失败：${snapshot!.lastErrorMessage ?? lastError}',
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.surfaceDecoration(context),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: connected ? AppTheme.primary : AppTheme.muted,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Text(
                    line,
                    key: line == lines.first
                        ? const Key('assignments-source-status')
                        : null,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
              ],
            ),
          ),
          if (!connected)
            FilledButton.icon(
              key: const Key('assignments-login'),
              onPressed: busy ? null : () => onConnect(),
              icon: const Icon(Icons.login_outlined),
              label: const Text('登录学习通'),
            ),
          OutlinedButton.icon(
            key: const Key('assignments-refresh'),
            onPressed: busy || !connected ? null : () => onRefresh(),
            icon: const Icon(Icons.refresh_outlined),
            label: Text(busy ? '正在刷新…' : '刷新作业'),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.summary,
    required this.filter,
    required this.courses,
    required this.courseId,
    required this.queryController,
    required this.busy,
    required this.onFilterChanged,
    required this.onCourseChanged,
    required this.onQueryChanged,
    required this.onManageCourses,
    required this.onRefresh,
  });

  final WorkSummary summary;
  final _BoardFilter filter;
  final List<CourseOffering> courses;
  final String courseId;
  final TextEditingController queryController;
  final bool busy;
  final ValueChanged<_BoardFilter> onFilterChanged;
  final ValueChanged<String?> onCourseChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onManageCourses;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final value in _BoardFilter.values)
              ChoiceChip(
                key: Key('assignments-filter-${value.name}'),
                label: Text(switch (value) {
                  _BoardFilter.pending => '待完成 ${summary.pending}',
                  _BoardFilter.done => '已完成 ${summary.done}',
                  _BoardFilter.ignored => '已忽略 ${summary.ignored}',
                  _BoardFilter.all => '全部',
                }),
                selected: filter == value,
                onSelected: (_) => onFilterChanged(value),
              ),
            TextButton.icon(
              key: const Key('assignments-manage-courses'),
              onPressed: onManageCourses,
              icon: const Icon(Icons.tune_outlined),
              label: Text('管理课程（${courses.length}）'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '筛选课程',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const Key('assignments-course-filter'),
                    value: courseId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('全部课程')),
                      for (final course in courses)
                        DropdownMenuItem(
                          value: course.id,
                          child: Text(
                            (course.remark?.isNotEmpty ?? false)
                                ? course.remark!
                                : course.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: onCourseChanged,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 260,
              child: TextField(
                key: const Key('assignments-search'),
                controller: queryController,
                onChanged: onQueryChanged,
                decoration: const InputDecoration(
                  labelText: '搜索作业或课程',
                  isDense: true,
                  prefixIcon: Icon(Icons.search_outlined),
                ),
              ),
            ),
            Text(
              summary.total == 0
                  ? '暂无作业'
                  : '共 ${summary.total} 份 · 待完成 ${summary.pending}'
                        '${summary.overdue > 0 ? ' · 已过截止 ${summary.overdue}' : ''}'
                        '${summary.undated > 0 ? ' · 时间待确认 ${summary.undated}' : ''}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ],
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({
    required this.report,
    required this.busy,
    required this.onRetry,
  });

  final ChaoxingRefreshReport report;
  final bool busy;
  final Future<void> Function(ChaoxingCourseFailure) onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.surfaceDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '以下来源本次没有读取成功，已保留上次的本地缓存：',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          if (report.coursesFailure != null)
            _FailureRow(
              name: '学习通课程列表',
              message: report.coursesFailure!.message,
            ),
          for (final failure in report.courseFailures)
            _FailureRow(
              name: failure.courseName,
              message: failure.failure.message,
              onRetry: busy ? null : () => onRetry(failure),
            ),
        ],
      ),
    );
  }
}

class _FailureRow extends StatelessWidget {
  const _FailureRow({required this.name, required this.message, this.onRetry});

  final String name;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$name：$message', style: const TextStyle(color: AppTheme.muted)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isError
            ? Theme.of(context).colorScheme.errorContainer
            : AppTheme.blueSoft,
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
      ),
      child: Text(message),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.assignment,
    required this.courseName,
    required this.statusLabel,
    required this.timeText,
    required this.overdue,
    required this.canOpen,
    required this.onOpen,
    required this.onMarkRead,
    required this.onMarkMuted,
  });

  final Assignment assignment;
  final String courseName;
  final String statusLabel;
  final String timeText;
  final bool overdue;
  final bool canOpen;
  final VoidCallback onOpen;
  final VoidCallback onMarkRead;
  final VoidCallback onMarkMuted;

  @override
  Widget build(BuildContext context) {
    final unread =
        assignment.readAtUtc == null && assignment.mutedAtUtc == null;
    return Padding(
      key: Key('assignment-${assignment.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (unread)
                Container(
                  key: Key('assignment-unread-${assignment.id}'),
                  margin: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Text(
                  assignment.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                statusLabel,
                style: const TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                courseName,
                style: const TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              Text(
                timeText,
                style: TextStyle(
                  color: overdue
                      ? Theme.of(context).colorScheme.error
                      : AppTheme.foreground,
                  fontSize: 13,
                ),
              ),
              if (assignment.readAtUtc != null) const _ChipLabel(label: '已读'),
              if (assignment.mutedAtUtc != null) const _ChipLabel(label: '已忽略'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton.icon(
                key: Key('assignment-open-${assignment.id}'),
                onPressed: canOpen ? onOpen : null,
                icon: const Icon(Icons.open_in_new_outlined, size: 16),
                label: const Text('打开原网页'),
              ),
              TextButton(
                key: Key('assignment-read-${assignment.id}'),
                onPressed: onMarkRead,
                child: Text(assignment.readAtUtc == null ? '标为已读' : '标为未读'),
              ),
              TextButton(
                key: Key('assignment-mute-${assignment.id}'),
                onPressed: onMarkMuted,
                child: Text(assignment.mutedAtUtc == null ? '忽略' : '取消忽略'),
              ),
            ],
          ),
          if (!canOpen)
            const Text(
              '连接学习通后可打开原网页入口；忽略的作业不计入待完成，也不参与截止提醒。',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppTheme.muted, fontSize: 11),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: AppTheme.surfaceDecoration(context),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.muted),
      ),
    );
  }
}
