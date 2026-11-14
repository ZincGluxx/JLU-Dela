import '../../core/storage/local_database.dart';

/// 笔记的本地表结构。
///
/// 版本段 30–39 预留给「笔记与资料」一侧（邮箱占了 30–31）。
///
/// 表里**刻意不建外键**：课程与课次来自教务来源，同步时会被整批替换。
/// 若用 `ON DELETE CASCADE`，来源一次刷新就会连带删掉用户手写的笔记；
/// 若用 `ON DELETE SET NULL`，又会悄悄改写用户看到的归属。两种都不对——
/// 归属只是提示，笔记本身永远归用户。所以这里只存 ID，失效由展示层说明。
const List<LocalMigration> noteMigrations = [
  LocalMigration(32, [
    '''
CREATE TABLE notes(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  course_offering_id TEXT,
  lesson_id TEXT,
  replay_source TEXT,
  replay_id TEXT,
  replay_title TEXT,
  position_ms INTEGER,
  revision INTEGER NOT NULL,
  created_at_utc INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL,
  CHECK (revision >= 1),
  CHECK (position_ms IS NULL OR position_ms >= 0)
)
''',
    '''
CREATE INDEX notes_user_updated
ON notes(user_id, updated_at_utc DESC)
''',
    '''
CREATE INDEX notes_user_course
ON notes(user_id, course_offering_id)
''',
    '''
CREATE INDEX notes_user_lesson
ON notes(user_id, lesson_id)
''',
    '''
CREATE INDEX notes_user_replay
ON notes(user_id, replay_source, replay_id)
''',
  ]),
];
