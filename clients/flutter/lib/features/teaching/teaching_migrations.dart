import '../../core/storage/local_database.dart';

const List<LocalMigration> teachingMigrations = [
  LocalMigration(2, [
    '''
CREATE TABLE teaching_semesters(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  source TEXT NOT NULL,
  source_scope TEXT NOT NULL,
  source_id TEXT NOT NULL,
  name TEXT NOT NULL,
  is_current INTEGER NOT NULL DEFAULT 0,
  last_observed_at_utc INTEGER NOT NULL,
  created_at_utc INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL,
  UNIQUE(user_id, source, source_scope, source_id)
)
''',
  ]),
  LocalMigration(3, [
    '''
CREATE TABLE teaching_lessons(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  semester_id TEXT NOT NULL REFERENCES teaching_semesters(id) ON DELETE CASCADE,
  course_offering_id TEXT NOT NULL REFERENCES course_offerings(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  starts_at_utc INTEGER NOT NULL,
  ends_at_utc INTEGER NOT NULL,
  location TEXT,
  period_start INTEGER,
  period_end INTEGER,
  weekday INTEGER NOT NULL,
  week_number INTEGER NOT NULL,
  source_lesson_id TEXT NOT NULL,
  note TEXT,
  created_at_utc INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL,
  CHECK (ends_at_utc > starts_at_utc)
)
''',
    '''
CREATE INDEX teaching_lessons_user_range
ON teaching_lessons(user_id, starts_at_utc, ends_at_utc)
''',
    '''
CREATE INDEX teaching_lessons_semester_range
ON teaching_lessons(user_id, semester_id, starts_at_utc)
''',
  ]),
  LocalMigration(4, [
    '''
CREATE TABLE teaching_period_times(
  user_id TEXT NOT NULL,
  campus TEXT NOT NULL,
  period INTEGER NOT NULL,
  start_minute INTEGER NOT NULL,
  end_minute INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL,
  PRIMARY KEY(user_id, campus, period),
  CHECK (start_minute >= 0 AND end_minute > start_minute)
)
''',
  ]),
  LocalMigration(5, [
    '''
CREATE TABLE teaching_calendars(
  user_id TEXT NOT NULL,
  semester_id TEXT NOT NULL REFERENCES teaching_semesters(id) ON DELETE CASCADE,
  starts_on TEXT NOT NULL,
  total_weeks INTEGER,
  observed_at_utc INTEGER NOT NULL,
  PRIMARY KEY(user_id, semester_id)
)
''',
  ]),
  LocalMigration(6, [
    '''
CREATE TABLE teaching_parse_issues(
  user_id TEXT NOT NULL,
  semester_id TEXT NOT NULL REFERENCES teaching_semesters(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  observed_at_utc INTEGER NOT NULL,
  PRIMARY KEY(user_id, semester_id, message)
)
''',
  ]),
];
