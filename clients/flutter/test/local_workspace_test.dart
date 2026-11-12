import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_workbench.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/source_portal.dart';
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
      browser: const UnsupportedSourcePageOpener(),
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

  group('source cookie jar', () {
    test('parent-domain cookies apply to subdomains', () {
      sessions.save(SourceAuthGroup.jluCampus, [
        const SourceCookie(
          name: 'JSESSIONID',
          value: 'campus',
          domain: '.jlu.edu.cn',
        ),
      ]);

      expect(
        sessions.cookieHeaderFor(
          SourceKind.jluIedu,
          Uri.parse('https://iedu.jlu.edu.cn/jwapp'),
        ),
        {'JSESSIONID': 'campus'},
      );
      expect(
        sessions.cookieHeaderFor(
          SourceKind.jluOa,
          Uri.parse('https://oa.jlu.edu.cn/'),
        ),
        {'JSESSIONID': 'campus'},
      );
      expect(
        sessions.cookieHeaderFor(
          SourceKind.chaoxing,
          Uri.parse('https://i.chaoxing.com/'),
        ),
        isEmpty,
      );
      expect(sessions.hasSession(SourceKind.chaoxing), isFalse);
    });

    test('host-only cookies never leak to sibling hosts', () {
      sessions.save(SourceAuthGroup.jluCampus, [
        const SourceCookie(
          name: 'SESSION',
          value: 'iedu',
          domain: 'iedu.jlu.edu.cn',
          hostOnly: true,
        ),
      ]);

      expect(
        sessions.cookieHeaderFor(
          SourceKind.jluIedu,
          Uri.parse('https://iedu.jlu.edu.cn/'),
        ),
        {'SESSION': 'iedu'},
      );
      expect(
        sessions.cookieHeaderFor(
          SourceKind.jluOa,
          Uri.parse('https://oa.jlu.edu.cn/'),
        ),
        isEmpty,
      );
    });

    test('the longest matching path wins for duplicate names', () {
      sessions.save(SourceAuthGroup.jluCampus, [
        const SourceCookie(
          name: 'SESSION',
          value: 'root',
          domain: 'iedu.jlu.edu.cn',
          path: '/',
        ),
        const SourceCookie(
          name: 'SESSION',
          value: 'jwapp',
          domain: 'iedu.jlu.edu.cn',
          path: '/jwapp',
        ),
      ]);

      expect(
        sessions.cookieHeaderFor(
          SourceKind.jluIedu,
          Uri.parse('https://iedu.jlu.edu.cn/jwapp/sys/index.do'),
        ),
        {'SESSION': 'jwapp'},
      );
      expect(
        sessions.cookieHeaderFor(
          SourceKind.jluIedu,
          Uri.parse('https://iedu.jlu.edu.cn/other'),
        ),
        {'SESSION': 'root'},
      );
      expect(
        sessions.cookieHeaderFor(
          SourceKind.jluIedu,
          Uri.parse('https://iedu.jlu.edu.cn/jwapplication'),
        ),
        {'SESSION': 'root'},
      );
    });

    test('expired and secure cookies are filtered', () {
      final now = DateTime.utc(2026, 11, 12);
      final registry = SourceSessionRegistry(now: () => now);
      registry.save(SourceAuthGroup.jluCampus, [
        SourceCookie(
          name: 'expired',
          value: '1',
          domain: 'jlu.edu.cn',
          path: '/',
          expiresAtUtc: now,
        ),
        const SourceCookie(
          name: 'secure',
          value: '1',
          domain: 'jlu.edu.cn',
          path: '/',
          secure: true,
        ),
      ]);

      expect(
        registry.cookiesForUri(
          SourceKind.jluIedu,
          Uri.parse('http://iedu.jlu.edu.cn/'),
        ),
        isEmpty,
      );
      expect(
        registry.cookieHeaderFor(
          SourceKind.jluIedu,
          Uri.parse('https://iedu.jlu.edu.cn/'),
        ),
        {'secure': '1'},
      );
    });

    test('expired cookies do not count as a session', () {
      final now = DateTime.utc(2026, 11, 12);
      final registry = SourceSessionRegistry(now: () => now);
      registry.save(SourceAuthGroup.chaoxing, [
        SourceCookie(
          name: 'c',
          value: '1',
          domain: 'chaoxing.com',
          path: '/',
          expiresAtUtc: now.subtract(const Duration(seconds: 1)),
        ),
      ]);

      expect(registry.hasSession(SourceKind.chaoxing), isFalse);
      expect(
        registry.stateFor(SourceKind.chaoxing),
        SourceConnectionState.disconnected,
      );
    });

    test('clearing a group keeps the other group', () {
      sessions.save(SourceAuthGroup.jluCampus, [
        const SourceCookie(name: 'campus', value: '1', domain: '.jlu.edu.cn'),
      ]);
      sessions.save(SourceAuthGroup.chaoxing, [
        const SourceCookie(
          name: 'chaoxing',
          value: '1',
          domain: '.chaoxing.com',
        ),
      ]);

      sessions.clearGroup(SourceAuthGroup.jluCampus);

      expect(sessions.hasSession(SourceKind.jluIedu), isFalse);
      expect(sessions.hasSession(SourceKind.chaoxing), isTrue);

      sessions.clearAll();
      expect(sessions.hasSession(SourceKind.chaoxing), isFalse);
    });
  });
}
