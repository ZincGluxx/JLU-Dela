import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_workbench.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/local_identity_store.dart';

import 'support/local_database_test_support.dart';

void main() {
  late LocalDatabase database;
  late SourceSessionRegistry sessions;
  late SourceHttpClient http;

  setUp(() async {
    database = await openTestDatabase();
    sessions = SourceSessionRegistry();
    http = UnavailableSourceHttpClient(sessions: sessions);
  });

  tearDown(() => database.close());

  WorkbenchData workbench(String userId) {
    return buildWorkbenchData(
      database: database,
      userId: userId,
      sessions: sessions,
      http: http,
      campusLogin: const UnsupportedCampusLogin(),
      now: () => DateTime.utc(2026, 11, 12, 4),
    );
  }

  test('two users never see each other local data', () async {
    final first = workbench('user-a');
    final second = workbench('user-b');
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    final firstTodo = await first.workspace.todos.create(title: 'A 的待办');
    final secondTodo = await second.workspace.todos.create(title: 'B 的待办');
    await first.workspace.drafts.write('todo', 'draft', {'title': 'A 草稿'});
    await second.workspace.drafts.write('todo', 'draft', {'title': 'B 草稿'});
    final firstCourse = await first.workspace.courses.upsert(
      const SourceCourse(
        source: SourceKind.jluIedu,
        sourceScope: '2026-fall',
        sourceId: 'shared-id',
        name: 'A 的课',
      ),
    );
    final secondCourse = await second.workspace.courses.upsert(
      const SourceCourse(
        source: SourceKind.jluIedu,
        sourceScope: '2026-fall',
        sourceId: 'shared-id',
        name: 'B 的课',
      ),
    );

    expect((await first.workspace.todos.list()).single.id, firstTodo.id);
    expect((await second.workspace.todos.list()).single.id, secondTodo.id);
    expect(await first.workspace.todos.get(secondTodo.id), isNull);
    expect((await first.workspace.courses.list()).single.id, firstCourse.id);
    expect((await second.workspace.courses.list()).single.id, secondCourse.id);
    expect(await first.workspace.drafts.read('todo', 'draft'), {
      'title': 'A 草稿',
    });
    expect(await second.workspace.drafts.read('todo', 'draft'), {
      'title': 'B 草稿',
    });
    expect(await first.workspace.drafts.read('todo', 'missing'), isNull);
  });

  test('cached identity is written only after a verified identity', () async {
    final identities = LocalIdentityStore(database);
    expect(await identities.lastUsed(), isNull);

    await identities.recordVerified(
      userId: 'user-a',
      displayName: '用户甲',
      timezone: 'Asia/Shanghai',
      verifiedAt: DateTime.utc(2026, 11, 12, 3),
    );
    final first = await identities.lastUsed();
    expect(first?.userId, 'user-a');
    expect(first?.displayName, '用户甲');
    expect(first?.verifiedAtUtc, DateTime.utc(2026, 11, 12, 3));

    await identities.recordVerified(
      userId: 'user-b',
      displayName: '用户乙',
      timezone: 'Asia/Shanghai',
      verifiedAt: DateTime.utc(2026, 11, 12, 4),
    );
    expect((await identities.lastUsed())?.userId, 'user-b');
  });

  test('source cookies stay in memory and share campus auth group', () {
    sessions.save(SourceAuthGroup.jluCampus, {'JSESSIONID': 'memory-only'});

    expect(sessions.hasSession(SourceKind.jluIedu), isTrue);
    expect(sessions.hasSession(SourceKind.jluOa), isTrue);
    expect(sessions.hasSession(SourceKind.chaoxing), isFalse);
    expect(
      sessions.stateFor(SourceKind.jluIedu),
      SourceConnectionState.connected,
    );
    expect(
      sessions.stateFor(SourceKind.chaoxing),
      SourceConnectionState.disconnected,
    );

    sessions.save(SourceAuthGroup.chaoxing, {'c': '1'});
    expect(sessions.cookiesFor(SourceKind.chaoxing), {'c': '1'});

    sessions.clearGroup(SourceAuthGroup.jluCampus);
    expect(sessions.hasSession(SourceKind.jluIedu), isFalse);
    expect(sessions.hasSession(SourceKind.chaoxing), isTrue);

    sessions.clearAll();
    expect(sessions.hasSession(SourceKind.chaoxing), isFalse);
  });
}
