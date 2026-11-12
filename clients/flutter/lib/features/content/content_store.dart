import '../../core/storage/local_database.dart';

class ContentStore {
  ContentStore(this.database, this.userId);

  final LocalDatabase database;
  final String userId;
}
