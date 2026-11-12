import '../../core/storage/local_database.dart';

/// CHAOXING 的本地迁移（v10–19）。
///
/// 作业按来源身份唯一：同一用户、来源范围、课程与作业标识只保留一行；个人标记
/// 与来源状态分列保存，刷新来源时只更新来源字段。
const List<LocalMigration> assignmentsMigrations = [
  LocalMigration(10, [
    '''
CREATE TABLE assignments(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  course_offering_id TEXT NOT NULL,
  source_scope TEXT NOT NULL,
  source_course_id TEXT NOT NULL,
  source_work_id TEXT NOT NULL,
  title TEXT NOT NULL,
  source_status TEXT NOT NULL,
  source_status_text TEXT,
  due_kind TEXT NOT NULL CHECK (due_kind IN ('exact','date_only','relative','unknown')),
  due_date TEXT,
  due_at_utc INTEGER,
  timing_text TEXT,
  observed_at_utc INTEGER NOT NULL,
  detail_observed_at_utc INTEGER,
  read_at_utc INTEGER,
  muted_at_utc INTEGER,
  created_at_utc INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL,
  CHECK (
    (due_kind = 'exact' AND due_at_utc IS NOT NULL AND due_date IS NULL)
    OR (due_kind = 'date_only' AND due_date IS NOT NULL AND due_at_utc IS NULL)
    OR (due_kind IN ('relative','unknown') AND due_date IS NULL AND due_at_utc IS NULL)
  ),
  UNIQUE(user_id, source_scope, source_course_id, source_work_id),
  FOREIGN KEY (course_offering_id) REFERENCES course_offerings(id) ON DELETE CASCADE
)
''',
    'CREATE INDEX assignments_user_due ON assignments(user_id, due_at_utc, due_date)',
    'CREATE INDEX assignments_user_course ON assignments(user_id, course_offering_id)',
  ]),
];
