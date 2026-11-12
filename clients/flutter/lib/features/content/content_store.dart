import '../../core/source/source_context.dart';
import '../../core/storage/local_database.dart';

class ContentStore {
  ContentStore(this.database, this.userId, {this.source});

  final LocalDatabase database;
  final String userId;
  final SourceContext? source;
}
