import '../../core/storage/local_database.dart';

/// 通知与资料目录只缓存来源读取结果；校园 Cookie 与访问动作不落库。
const List<LocalMigration> contentMigrations = [
  LocalMigration(20, [
    '''
CREATE TABLE notices(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  source_scope TEXT NOT NULL,
  source_id TEXT NOT NULL,
  title TEXT NOT NULL,
  department TEXT,
  published_at_utc INTEGER,
  published_date TEXT,
  published_text TEXT,
  pinned INTEGER NOT NULL DEFAULT 0,
  text TEXT,
  source_url TEXT,
  detail_synced_at_utc INTEGER,
  observed_at_utc INTEGER NOT NULL,
  UNIQUE(user_id, source_scope, source_id),
  CHECK (published_at_utc IS NULL OR published_date IS NULL)
)
''',
    'CREATE INDEX notices_user_published ON notices(user_id, published_at_utc, published_date)',
    'CREATE INDEX notices_user_department ON notices(user_id, department)',
  ]),
  LocalMigration(21, [
    '''
CREATE TABLE notice_attachments(
  user_id TEXT NOT NULL,
  notice_id TEXT NOT NULL,
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  bytes INTEGER,
  downloadable INTEGER NOT NULL,
  element_id TEXT,
  source_path TEXT,
  position INTEGER NOT NULL,
  PRIMARY KEY(user_id, notice_id, id),
  FOREIGN KEY(notice_id) REFERENCES notices(id) ON DELETE CASCADE
)
''',
    'CREATE INDEX notice_attachments_notice ON notice_attachments(user_id, notice_id, position)',
    '''
CREATE TABLE notice_scopes(
  user_id TEXT NOT NULL,
  source_scope TEXT NOT NULL,
  total_pages INTEGER,
  fetched_pages INTEGER,
  last_complete_at_utc INTEGER,
  updated_at_utc INTEGER NOT NULL,
  PRIMARY KEY(user_id, source_scope)
)
''',
  ]),
  LocalMigration(22, [
    '''
CREATE TABLE materials(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  course_offering_id TEXT NOT NULL,
  parent_id TEXT,
  parent_key TEXT NOT NULL DEFAULT '',
  source_scope TEXT NOT NULL,
  source_id TEXT NOT NULL,
  name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('folder','file')),
  bytes INTEGER,
  downloadable INTEGER NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  observed_at_utc INTEGER NOT NULL,
  UNIQUE(user_id, course_offering_id, parent_key, source_id),
  FOREIGN KEY(course_offering_id) REFERENCES course_offerings(id) ON DELETE CASCADE,
  FOREIGN KEY(parent_id) REFERENCES materials(id) ON DELETE CASCADE
)
''',
    'CREATE INDEX materials_user_course ON materials(user_id, course_offering_id, parent_key, position)',
  ]),
  LocalMigration(23, [
    '''
CREATE TABLE material_scopes(
  user_id TEXT NOT NULL,
  course_offering_id TEXT NOT NULL,
  parent_key TEXT NOT NULL DEFAULT '',
  last_success_at_utc INTEGER,
  updated_at_utc INTEGER NOT NULL,
  PRIMARY KEY(user_id, course_offering_id, parent_key)
)
''',
  ]),
];
