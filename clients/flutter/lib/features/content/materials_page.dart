import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/course.dart';
import '../../core/models/material.dart' as domain;
import '../../core/models/source.dart';
import '../../core/source/source.dart';
import '../../core/storage/local_workspace.dart';
import 'content_access_dialog.dart';
import 'content_store.dart';

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({
    super.key,
    required this.workspace,
    required this.store,
  });

  final LocalWorkspace workspace;
  final ContentStore store;

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  List<CourseOffering> _courses = const <CourseOffering>[];
  String? _courseId;
  List<domain.Material> _path = const <domain.Material>[];
  List<domain.Material> _materials = const <domain.Material>[];
  SourceSnapshot? _snapshot;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String? _sourceMessage;
  int _request = 0;

  bool get _hasChaoxingSession =>
      widget.workspace.sessions.hasSession(SourceKind.chaoxing);

  CourseOffering? get _course {
    for (final course in _courses) {
      if (course.id == _courseId) return course;
    }
    return null;
  }

  domain.Material? get _folder => _path.isEmpty ? null : _path.last;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCourses());
  }

  @override
  void didUpdateWidget(MaterialsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace != widget.workspace ||
        oldWidget.store != widget.store) {
      _courses = const <CourseOffering>[];
      _courseId = null;
      _path = const <domain.Material>[];
      _materials = const <domain.Material>[];
      _snapshot = null;
      _error = null;
      _sourceMessage = null;
      unawaited(_loadCourses());
    }
  }

  Future<void> _loadCourses() async {
    final request = ++_request;
    setState(() {
      _loading = true;
    });
    try {
      final courses = await widget.store.materialCourses();
      if (!mounted || request != _request) {
        return;
      }
      var selected = _courseId;
      if (selected == null || !courses.any((course) => course.id == selected)) {
        selected = _preferredCourse(courses)?.id;
      }
      setState(() {
        _courses = courses;
        _courseId = selected;
        _path = const <domain.Material>[];
        _materials = const <domain.Material>[];
        _snapshot = null;
      });
      if (selected == null) {
        setState(() {
          _loading = false;
        });
        return;
      }
      await _loadChildren();
    } catch (error) {
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _errorText(error);
      });
    }
  }

  CourseOffering? _preferredCourse(List<CourseOffering> courses) {
    for (final course in courses) {
      if (course.retained) return course;
    }
    return courses.isEmpty ? null : courses.first;
  }

  Future<void> _loadChildren() async {
    final request = ++_request;
    final course = _course;
    if (course == null) {
      setState(() {
        _materials = const <domain.Material>[];
        _snapshot = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final materials = await widget.store.loadMaterials(
        course.id,
        parentId: _folder?.id,
      );
      final snapshot = await widget.store.materialSnapshot(
        course.id,
        parentId: _folder?.id,
      );
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        _materials = materials;
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _errorText(error);
      });
    }
  }

  Future<void> _refreshFolder() async {
    final course = _course;
    if (course == null) {
      return;
    }
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final result = await widget.store.refreshMaterialChildren(
        widget.workspace,
        course,
        parent: _folder,
      );
      if (!mounted) {
        return;
      }
      if (result is SourceFailed<MaterialRefreshSummary>) {
        setState(() {
          _error = _failureText(result.failure);
        });
      }
      await _loadChildren();
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
        SourceKind.chaoxing,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sourceMessage = result.connected
            ? '学习通已连接'
            : (result.message ?? '学习通未连接');
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorText(error);
        });
      }
    }
  }

  Future<void> _selectCourse(String? courseId) async {
    if (courseId == null || courseId == _courseId) {
      return;
    }
    setState(() {
      _courseId = courseId;
      _path = const <domain.Material>[];
      _materials = const <domain.Material>[];
      _snapshot = null;
    });
    await _loadChildren();
  }

  void _openFolder(domain.Material folder) {
    setState(() {
      _path = <domain.Material>[..._path, folder];
      _materials = const <domain.Material>[];
      _snapshot = null;
    });
    unawaited(_loadChildren());
  }

  void _goBack() {
    if (_path.isEmpty) {
      return;
    }
    setState(() {
      _path = _path.sublist(0, _path.length - 1);
      _materials = const <domain.Material>[];
      _snapshot = null;
    });
    unawaited(_loadChildren());
  }

  void _jumpTo(int index) {
    if (index >= _path.length - 1) {
      return;
    }
    setState(() {
      _path = _path.sublist(0, index + 1);
      _materials = const <domain.Material>[];
      _snapshot = null;
    });
    unawaited(_loadChildren());
  }

  Future<void> _accessMaterial(domain.Material material) async {
    setState(() {
      _error = null;
    });
    try {
      final access = await widget.store.accessMaterial(
        widget.workspace,
        material.id,
      );
      if (!mounted) {
        return;
      }
      await ContentAccessDialog.show(
        context,
        access: access,
        sourceLabel: '学习通',
      );
    } on ContentAccessException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
        });
      }
    } on SourceException catch (error) {
      if (mounted) {
        setState(() {
          _error = _failureText(error.failure);
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
                _buildCourseSelector(context),
                const SizedBox(height: AppSpacing.md),
                _buildBreadcrumb(context),
                const SizedBox(height: AppSpacing.sm),
                _buildList(context),
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
        Text('课程资料', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '学习通 · 课程资料目录 · 只显示本机已缓存内容',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              key: const Key('materials-refresh'),
              onPressed: _refreshing || _course == null
                  ? null
                  : () => unawaited(_refreshFolder()),
              icon: _refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_refreshing ? '正在读取' : '刷新当前目录'),
            ),
            if (_path.isNotEmpty)
              OutlinedButton.icon(
                key: const Key('materials-back'),
                onPressed: () => _goBack(),
                icon: const Icon(Icons.arrow_upward, size: 18),
                label: const Text('上一级'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final snapshot = _snapshot;
    final connected = _hasChaoxingSession;
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
              _snapshotLine(snapshot),
              key: const Key('materials-cache-status'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
            if (_courses.isEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              const Text('尚未同步学习通课程。课程由学习通作业页同步，同步后这里会显示资料目录。'),
            ],
            if (!connected) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Expanded(child: Text('学习通来源未连接，刷新与访问需要来源会话。')),
                  TextButton(
                    key: const Key('materials-connect'),
                    onPressed: () => unawaited(_connectSource()),
                    child: const Text('登录学习通'),
                  ),
                ],
              ),
            ],
            if (_sourceMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _sourceMessage!,
                key: const Key('materials-source-message'),
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
      key: const Key('materials-error'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
        border: Border.all(color: const Color(0xFFF0C48A)),
      ),
      child: Text(_error!, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Widget _buildCourseSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('materials-course'),
          value: _courses.any((course) => course.id == _courseId)
              ? _courseId
              : null,
          isExpanded: true,
          hint: const Text('选择学习通课程'),
          items: <DropdownMenuItem<String>>[
            for (final course in _courses)
              DropdownMenuItem<String>(
                value: course.id,
                child: Text(
                  course.remark?.isNotEmpty == true
                      ? '${course.remark}（${course.name}）'
                      : course.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _courses.isEmpty
              ? null
              : (value) => unawaited(_selectCourse(value)),
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(BuildContext context) {
    final course = _course;
    if (course == null) {
      return const SizedBox.shrink();
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: _path.isEmpty ? null : _goBack,
          child: Text(
            course.remark?.isNotEmpty == true ? course.remark! : course.name,
          ),
        ),
        for (var index = 0; index < _path.length; index++) ...[
          const Icon(Icons.chevron_right, size: 16, color: AppTheme.muted),
          TextButton(
            key: Key('materials-crumb-${_path[index].sourceRef.sourceId}'),
            onPressed: index == _path.length - 1 ? null : () => _jumpTo(index),
            child: Text(_path[index].name, overflow: TextOverflow.ellipsis),
          ),
        ],
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    if (_course == null) {
      return _emptyCard(context, '尚未同步学习通课程，暂时没有可浏览的资料目录。');
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: CircularProgressIndicator(key: Key('materials-loading')),
        ),
      );
    }
    if (_materials.isEmpty) {
      return _emptyCard(context, '当前目录没有已缓存内容。点击「刷新当前目录」从学习通读取；未登录时需先完成来源登录。');
    }
    return Column(
      children: [
        for (final material in _materials) ...[
          _MaterialTile(
            material: material,
            onOpen: material.kind == domain.MaterialKind.folder
                ? () => _openFolder(material)
                : null,
            onAccess: material.kind == domain.MaterialKind.file
                ? () => unawaited(_accessMaterial(material))
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          '文件访问由学习通来源会话完成；工作台不使用任意下载地址，也不把来源页面当作直接下载链接。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
        ),
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

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.material, this.onOpen, this.onAccess});

  final domain.Material material;
  final VoidCallback? onOpen;
  final VoidCallback? onAccess;

  @override
  Widget build(BuildContext context) {
    final isFolder = material.kind == domain.MaterialKind.folder;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        key: Key('material-${material.sourceRef.sourceId}'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                isFolder
                    ? Icons.folder_outlined
                    : Icons.insert_drive_file_outlined,
                color: isFolder ? AppTheme.primary : AppTheme.muted,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isFolder
                          ? '文件夹'
                          : '${_bytesLabel(material.bytes)} · '
                                '${material.downloadable ? '来源提供访问入口' : '来源未提供下载入口'}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              if (isFolder)
                const Icon(Icons.chevron_right, color: AppTheme.muted)
              else
                TextButton(
                  key: Key('material-access-${material.sourceRef.sourceId}'),
                  onPressed: material.downloadable ? onAccess : null,
                  child: const Text('打开'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _bytesLabel(int? bytes) {
  if (bytes == null) {
    return '大小未知';
  }
  if (bytes < 1024) {
    return '$bytes B';
  }
  const units = <String>['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
}

String _snapshotLine(SourceSnapshot? snapshot) {
  if (snapshot == null || snapshot.lastSuccessAtUtc == null) {
    return snapshot?.lastErrorCode == null
        ? '当前目录尚未从学习通读取'
        : '当前目录尚未同步成功：${snapshot?.lastErrorMessage ?? snapshot?.lastErrorCode}';
  }
  final parts = <String>['上次成功 ${_formatBeijing(snapshot.lastSuccessAtUtc!)}'];
  if (snapshot.lastErrorCode != null) {
    parts.add('上次失败：${snapshot.lastErrorMessage ?? snapshot.lastErrorCode}');
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
    return '学习通需要重新登录：${failure.message}';
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
