import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:jlu_dela_api/api.dart';
import 'package:uuid/uuid.dart';

import '../api/api_failure.dart';
import '../auth/session_controller.dart';
import '../auth/session_models.dart';
import '../storage/local_draft_store.dart';
import 'backup_gateway.dart';

class NotesBackupController extends ChangeNotifier {
  NotesBackupController({
    required this.userId,
    required this.session,
    required this.remote,
    required this.drafts,
    required this.listNotes,
    required this.exportNotes,
    required this.importNotes,
  }) : _lifecycle = session.sessionRevision {
    session.addListener(_sessionChanged);
  }

  final String userId;
  final SessionController session;
  final BackupRemote remote;
  final LocalDraftStore drafts;
  final Future<List<BackupNote>> Function() listNotes;
  final Future<List<BackupNote>> Function(Set<String>) exportNotes;
  final Future<List<String>> Function(
    List<BackupNote>, {
    required bool Function() isCurrent,
  })
  importNotes;
  final int _lifecycle;
  int _generation = 0;
  bool _disposed = false;
  Future<void> _saveQueue = Future.value();

  bool loaded = false;
  bool enabled = false;
  bool busy = false;
  Set<String> selectedIds = {};
  List<BackupNote> available = [];
  List<BackupNote> _baseline = [];
  int cloudRevision = 0;
  DateTime? lastSuccess;
  String? message;
  BackupSnapshot? conflict;
  Map<String, dynamic>? _pending;

  bool get online =>
      session.phase == SessionPhase.authenticated &&
      session.currentUser?.id == userId &&
      session.sessionRevision == _lifecycle;
  bool _current(int generation) =>
      !_disposed &&
      generation == _generation &&
      session.sessionRevision == _lifecycle;

  int get pendingCount {
    if (!enabled) return 0;
    final local = available
        .where((note) => selectedIds.contains(note.id))
        .toList();
    final changed = local.where((note) => !_baseline.contains(note)).length;
    final removed = _baseline
        .where((note) => !local.any((item) => item.id == note.id))
        .length;
    return changed + removed;
  }

  Future<void> initialize() async {
    final generation = _generation;
    final state = await drafts.read('personal_backup', 'notes');
    if (!_current(generation)) return;
    if (state != null) {
      enabled = state['enabled'] == true;
      selectedIds = (state['selected_ids'] as List).cast<String>().toSet();
      cloudRevision = state['revision'] as int;
      _baseline = BackupNote.listFromJson(state['baseline']);
      lastSuccess = DateTime.tryParse(state['last_success'] as String? ?? '');
      message = state['message'] as String?;
      _pending = (state['pending'] as Map?)?.cast<String, dynamic>();
    }
    final notes = await listNotes();
    if (!_current(generation)) return;
    available = notes;
    loaded = true;
    notifyListeners();
  }

  Future<void> refreshLocal() async {
    final generation = _generation;
    final notes = await listNotes();
    if (!_current(generation)) return;
    available = notes;
    notifyListeners();
  }

  Future<void> enable(Set<String> ids) async {
    if (busy || !loaded || !online) return;
    if (ids.isEmpty || ids.length > 100) {
      message = '请选择 1–100 条笔记。';
      notifyListeners();
      return;
    }
    selectedIds = Set.of(ids);
    enabled = true;
    _pending = null;
    conflict = null;
    message = '已开启，仅在点击“同步所选笔记”时上传。缩小范围会移除未选云端内容。';
    await _save(_generation);
    if (!_disposed) notifyListeners();
  }

  Future<void> disable() async {
    _generation++;
    enabled = false;
    busy = false;
    _pending = null;
    conflict = null;
    message = '已停止后续上传。已发送的请求可能已完成，可检查并删除云端副本。';
    await _save(_generation);
    if (!_disposed) notifyListeners();
  }

  Future<void> sync() => _run((generation) async {
    if (!enabled) return;
    final current = await remote.read();
    if (!_current(generation)) return;
    final pending = _pending;
    final request = pending?['kind'] == 'put'
        ? PutNotesBackupRequest.fromJson(pending!['request'])!
        : PutNotesBackupRequest(
            expectedRevision: cloudRevision,
            notes: await exportNotes(selectedIds),
          );
    if (!_current(generation)) return;
    final alreadyApplied =
        pending?['kind'] == 'put' &&
        current.revision == request.expectedRevision + 1 &&
        !current.deleted &&
        listEquals(current.notes, request.notes);
    if (current.revision != request.expectedRevision && !alreadyApplied) {
      throw BackupConflict(current);
    }
    final key = pending?['kind'] == 'put'
        ? pending!['key'] as String
        : const Uuid().v4();
    _pending = {'kind': 'put', 'key': key, 'request': request.toJson()};
    await _save(generation);
    if (!_current(generation) || !enabled) return;
    final receipt = await remote.put(key, request);
    if (!_current(generation)) return;
    final confirmed = await remote.read();
    if (!_current(generation)) return;
    if (confirmed.revision != receipt.revision ||
        confirmed.deleted ||
        !listEquals(confirmed.notes, request.notes)) {
      throw BackupConflict(confirmed);
    }
    cloudRevision = receipt.revision;
    _baseline = request.notes;
    _pending = null;
    lastSuccess = DateTime.now().toUtc();
    message = '所选笔记已同步。';
    conflict = null;
    final notes = await listNotes();
    if (!_current(generation)) return;
    available = notes;
  }, requiresUpload: true);

  Future<void> restore() => _run((generation) async {
    final current = await remote.read();
    if (!_current(generation)) return;
    if (!current.deleted) {
      await importNotes(current.notes, isCurrent: () => _current(generation));
      if (!_current(generation)) return;
    }
    cloudRevision = current.revision;
    _baseline = current.notes;
    _pending = null;
    enabled = false;
    conflict = null;
    lastSuccess = DateTime.now().toUtc();
    message = current.deleted
        ? '云端没有笔记副本，本地内容未删除。'
        : '已恢复。不同内容保留为独立副本；检查后重新选择上传范围。';
    final notes = await listNotes();
    if (!_current(generation)) return;
    available = notes;
  });

  Future<void> deleteCloud() => _run((generation) async {
    enabled = false;
    final current = await remote.read();
    if (!_current(generation)) return;
    final pending = _pending;
    final revision = pending?['kind'] == 'delete'
        ? pending!['revision'] as int
        : current.revision;
    final key = pending?['kind'] == 'delete'
        ? pending!['key'] as String
        : const Uuid().v4();
    _pending = {'kind': 'delete', 'key': key, 'revision': revision};
    await _save(generation);
    if (!_current(generation)) return;
    final receipt = await remote.delete(key, revision);
    if (!_current(generation)) return;
    final confirmed = await remote.read();
    if (!_current(generation)) return;
    if (!confirmed.deleted || confirmed.revision < receipt.revision) {
      throw BackupConflict(confirmed);
    }
    cloudRevision = confirmed.revision;
    _baseline = [];
    _pending = null;
    conflict = null;
    lastSuccess = DateTime.now().toUtc();
    message = '已删除当前云端副本，本地笔记保留。运维备份按保留策略管理。';
  });

  Future<void> _run(
    Future<void> Function(int) action, {
    bool requiresUpload = false,
  }) async {
    if (busy || !loaded || !online || (requiresUpload && !enabled)) return;
    final generation = _generation;
    busy = true;
    message = null;
    notifyListeners();
    try {
      await action(generation);
    } on BackupConflict catch (error) {
      if (_current(generation)) {
        if (_pending?['kind'] == 'delete') _pending = null;
        conflict = error.current;
        message = '云端版本已变化，未覆盖任何内容。请先恢复并保留双方，再选择同步范围。';
      }
    } on Object catch (error) {
      if (_current(generation)) {
        message = error is ApiFailure
            ? '${error.displayMessage} 本地笔记仍可使用，请重试。'
            : '操作未完成，本地笔记保留。请检查所选笔记与网络后重试。';
      }
    } finally {
      if (_current(generation)) {
        busy = false;
        await _save(generation);
        if (_current(generation)) notifyListeners();
      }
    }
  }

  Future<void> _save(int generation) {
    final payload =
        jsonDecode(
              jsonEncode({
                'enabled': enabled,
                'selected_ids': selectedIds.toList()..sort(),
                'revision': cloudRevision,
                'baseline': _baseline,
                'last_success': lastSuccess?.toIso8601String(),
                'message': message,
                'pending': _pending,
              }),
            )
            as Map<String, dynamic>;
    return _saveQueue = _saveQueue.catchError((Object _) {}).then((_) async {
      if (_current(generation)) {
        await drafts.write('personal_backup', 'notes', payload);
      }
    });
  }

  void _sessionChanged() {
    if (session.sessionRevision != _lifecycle) {
      _generation++;
      enabled = false;
      busy = false;
      available = [];
      selectedIds = {};
      _baseline = [];
      _pending = null;
      conflict = null;
      message = null;
      cloudRevision = 0;
      lastSuccess = null;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    session.removeListener(_sessionChanged);
    _generation++;
    _disposed = true;
    super.dispose();
  }
}
