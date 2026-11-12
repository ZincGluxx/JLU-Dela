import '../core/storage/core_migrations.dart';
import '../core/storage/local_database.dart';
import '../features/assignments/assignments_migrations.dart';
import '../features/content/content_migrations.dart';
import '../features/teaching/teaching_migrations.dart';

const List<LocalMigration> appLocalMigrations = [
  ...coreMigrations,
  ...teachingMigrations,
  ...assignmentsMigrations,
  ...contentMigrations,
];
