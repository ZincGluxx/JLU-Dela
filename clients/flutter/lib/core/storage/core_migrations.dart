import 'local_database.dart';

const List<LocalMigration> coreMigrations = [
  LocalMigration(1, [
    '''
CREATE TABLE app_meta(
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''',
    '''
CREATE TABLE local_identity(
  user_id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  timezone TEXT NOT NULL,
  verified_at_utc INTEGER NOT NULL,
  last_used_at_utc INTEGER NOT NULL
)
''',
    '''
CREATE TABLE todos(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  notes TEXT NOT NULL,
  due_kind TEXT NOT NULL CHECK (due_kind IN ('none','date_only','exact')),
  due_date TEXT,
  due_at_utc INTEGER,
  color TEXT,
  show_in_calendar INTEGER NOT NULL,
  completed INTEGER NOT NULL,
  completed_at_utc INTEGER,
  revision INTEGER NOT NULL,
  created_at_utc INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL,
  CHECK (
    (due_kind = 'none' AND due_date IS NULL AND due_at_utc IS NULL)
    OR (due_kind = 'date_only' AND due_date IS NOT NULL AND due_at_utc IS NULL)
    OR (due_kind = 'exact' AND due_at_utc IS NOT NULL AND due_date IS NULL)
  )
)
''',
    'CREATE INDEX todos_user_due ON todos(user_id, completed, due_at_utc, due_date)',
    '''
CREATE TABLE course_offerings(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  source TEXT NOT NULL,
  source_scope TEXT NOT NULL,
  source_id TEXT NOT NULL,
  semester_id TEXT,
  name TEXT NOT NULL,
  teacher TEXT,
  remark TEXT,
  retained INTEGER NOT NULL DEFAULT 1,
  created_at_utc INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL,
  UNIQUE(user_id, source, source_scope, source_id)
)
''',
    '''
CREATE TABLE source_snapshots(
  user_id TEXT NOT NULL,
  source TEXT NOT NULL,
  resource TEXT NOT NULL,
  scope_key TEXT NOT NULL DEFAULT '',
  last_success_at_utc INTEGER,
  last_attempt_at_utc INTEGER,
  last_error_code TEXT,
  last_error_message TEXT,
  PRIMARY KEY(user_id, source, resource, scope_key)
)
''',
    '''
CREATE TABLE local_drafts(
  user_id TEXT NOT NULL,
  scope TEXT NOT NULL,
  key TEXT NOT NULL,
  payload TEXT NOT NULL,
  updated_at_utc INTEGER NOT NULL,
  PRIMARY KEY(user_id, scope, key)
)
''',
  ]),
];
