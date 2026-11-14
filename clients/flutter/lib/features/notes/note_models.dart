/// 个人笔记的本地模型。
///
/// 笔记是**私人数据**：只属于当前用户，来源（课程、回放）失效时不得删除。
/// 时间位置是回放内的偏移量，与设备时区无关；展示时间另由 `school_time.dart` 换算。
library;

/// 笔记的归属目标。
///
/// 课程与课次用本地 ID；回放用来源侧的稳定标识，显示名单独存放——
/// 来源改名不该影响笔记归属，来源消失也不该带走笔记。
class NoteTarget {
  const NoteTarget({
    this.courseOfferingId,
    this.lessonId,
    this.replaySource,
    this.replayId,
    this.replayTitle,
  });

  /// 本地课程 ID。可空：允许不挂课程的独立笔记。
  final String? courseOfferingId;

  /// 本地课次 ID。可空。
  final String? lessonId;

  /// 回放来源（如学在吉大）。与 [replayId] 一起构成跨来源唯一的回放标识。
  final String? replaySource;

  /// 来源侧回放稳定标识。可空：非回放笔记。
  final String? replayId;

  /// 回放显示名。与 [replayId] 分开，来源改名不改变归属。
  final String? replayTitle;

  /// 回放身份是否完整。
  ///
  /// 回放靠 [replaySource] + [replayId] 两个字段才能跨来源唯一定位：
  /// 只有 id 没有来源时，调用方不知道该去哪个来源跳转，等于「保存成功但跳不回去」。
  /// 所以两个字段都非空才算挂了回放。
  bool get hasReplay => _isPresent(replaySource) && _isPresent(replayId);

  /// 回放标识只填了一半（有来源没 id，或有 id 没来源）。
  ///
  /// 存储层据此在创建与更新边界拒绝，避免落库后无法复用。
  bool get hasPartialReplay => _isPresent(replaySource) != _isPresent(replayId);

  bool get hasCourse => courseOfferingId != null;
}

bool _isPresent(String? value) => value != null && value.trim().isNotEmpty;

/// 一条笔记。
class Note {
  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.courseOfferingId,
    this.lessonId,
    this.replaySource,
    this.replayId,
    this.replayTitle,
    this.positionMs,
    required this.revision,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final String id;
  final String userId;
  String title;
  String body;

  /// 本地课程 ID。
  String? courseOfferingId;

  /// 本地课次 ID。
  String? lessonId;

  /// 回放来源标识。
  String? replaySource;

  /// 来源侧回放稳定标识。
  String? replayId;

  /// 回放显示名，可随来源更新，不参与归属判定。
  String? replayTitle;

  /// 回放内时间位置（毫秒）。仅当 [replayId] 存在时有意义。
  int? positionMs;

  int revision;
  final DateTime createdAtUtc;
  DateTime updatedAtUtc;

  NoteTarget get target => NoteTarget(
    courseOfferingId: courseOfferingId,
    lessonId: lessonId,
    replaySource: replaySource,
    replayId: replayId,
    replayTitle: replayTitle,
  );

  bool get hasReplay => target.hasReplay;

  /// 是否有可跳回的时间位置。界面据此决定是否显示「回到 12:34」。
  bool get hasPosition => hasReplay && positionMs != null;

  /// 标题为空时用正文首行兜底，避免列表里出现空白条目。
  String get displayTitle {
    if (title.trim().isNotEmpty) {
      return title.trim();
    }
    final firstLine = body
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) {
      return '未命名笔记';
    }
    return firstLine.runes.length > 40
        ? '${String.fromCharCodes(firstLine.runes.take(40))}…'
        : firstLine;
  }
}

/// 笔记校验失败。
class NoteValidationException implements Exception {
  const NoteValidationException(this.message);

  final String message;

  @override
  String toString() => 'NoteValidationException: $message';
}

/// 版本冲突：携带服务端/库内当前版本，界面据此保留草稿并提示。
class NoteRevisionConflict implements Exception {
  const NoteRevisionConflict(this.current);

  final Note current;

  @override
  String toString() =>
      'NoteRevisionConflict(current revision: ${current.revision})';
}

class NoteNotFoundException implements Exception {
  const NoteNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'NoteNotFoundException($id)';
}

/// 笔记长度上限。与待办备注保持同一量级，避免单条笔记撑爆本地库。
abstract final class NoteLimits {
  static const int maxTitleLength = 200;
  static const int maxBodyLength = 20000;
}
