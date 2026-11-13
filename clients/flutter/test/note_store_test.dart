import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/features/notes/note_models.dart';
import 'package:jlu_dela/features/notes/note_store.dart';

import 'support/local_database_test_support.dart';

void main() {
  late LocalDatabase database;

  setUp(() async {
    database = await openTestDatabase();
  });

  tearDown(() async {
    await database.close();
  });

  NoteStore storeFor(String userId, {DateTime Function()? now}) =>
      NoteStore(database, userId, now: now);

  group('notes', () {
    test('a new note starts at revision 1 and carries its target', () async {
      final store = storeFor('user-a');
      final note = await store.create(
        title: '第三讲要点',
        body: '贝叶斯公式',
        target: const NoteTarget(
          courseOfferingId: 'course-1',
          lessonId: 'lesson-1',
          replaySource: 'ilearn',
          replayId: 'replay-1',
          replayTitle: '第三讲回放',
        ),
        positionMs: 754000,
      );

      expect(note.revision, 1);
      expect(note.courseOfferingId, 'course-1');
      expect(note.lessonId, 'lesson-1');
      expect(note.replaySource, 'ilearn');
      expect(note.replayId, 'replay-1');
      expect(note.replayTitle, '第三讲回放');
      expect(note.positionMs, 754000);
      expect(note.hasReplay, isTrue);
      expect(note.hasPosition, isTrue);
    });

    test('a note survives with no course, lesson or replay', () async {
      final store = storeFor('user-a');
      final note = await store.create(title: '随手记', body: '买墨水');

      expect(note.courseOfferingId, isNull);
      expect(note.lessonId, isNull);
      expect(note.hasReplay, isFalse);
      expect(note.hasPosition, isFalse);
      expect((await store.get(note.id))!.body, '买墨水');
    });

    test('notes are isolated per user', () async {
      final alice = storeFor('user-a');
      final bob = storeFor('user-b');
      final mine = await alice.create(title: '我的笔记');

      expect(await bob.get(mine.id), isNull);
      expect(await bob.list(), isEmpty);
      expect((await alice.list()).single.id, mine.id);
    });

    test('listing filters by course, lesson and replay', () async {
      final store = storeFor('user-a');
      await store.create(
        title: '课程一',
        target: const NoteTarget(courseOfferingId: 'course-1'),
      );
      await store.create(
        title: '课程二',
        target: const NoteTarget(courseOfferingId: 'course-2'),
      );
      await store.create(
        title: '某课次',
        target: const NoteTarget(
          courseOfferingId: 'course-1',
          lessonId: 'lesson-9',
        ),
      );
      await store.create(
        title: '回放笔记',
        target: const NoteTarget(
          replaySource: 'ilearn',
          replayId: 'replay-7',
          replayTitle: '第七讲',
        ),
      );

      expect((await store.list(courseOfferingId: 'course-1')).length, 2);
      expect((await store.list(lessonId: 'lesson-9')).single.title, '某课次');
      expect((await store.list(replayId: 'replay-7')).single.title, '回放笔记');
      // 只给 replayId 不带来源时也能命中：来源只是附加限定。
      expect((await store.list(replayId: 'replay-7')).length, 1);
      expect(
        (await store.list(replaySource: 'chaoxing', replayId: 'replay-7')),
        isEmpty,
      );
      expect(await store.count(), 4);
    });

    test('listing is ordered by the most recent edit', () async {
      var clock = DateTime.utc(2026, 11, 13, 10);
      final store = storeFor('user-a', now: () => clock);
      final first = await store.create(title: '先写的');
      clock = DateTime.utc(2026, 11, 13, 11);
      final second = await store.create(title: '后写的');

      expect((await store.list()).map((note) => note.id), [
        second.id,
        first.id,
      ]);
    });

    test('editing bumps the revision and keeps the creation time', () async {
      var clock = DateTime.utc(2026, 11, 13, 10);
      final store = storeFor('user-a', now: () => clock);
      final created = await store.create(title: '原标题');
      clock = DateTime.utc(2026, 11, 13, 12);
      created.title = '新标题';
      created.body = '补充内容';
      final updated = await store.update(created);

      expect(updated.revision, 2);
      expect(updated.title, '新标题');
      expect(updated.createdAtUtc, created.createdAtUtc);
      expect(updated.updatedAtUtc.isAfter(created.updatedAtUtc), isTrue);
    });

    test(
      'a stale revision reports the stored note instead of overwriting',
      () async {
        final store = storeFor('user-a');
        final created = await store.create(title: '原标题', body: '原文');
        final mine = await store.get(created.id);
        final other = await store.get(created.id);

        mine!.title = '我的改动';
        await store.update(mine);

        other!.body = '另一个窗口的改动';
        await expectLater(
          store.update(other),
          throwsA(
            isA<NoteRevisionConflict>().having(
              (conflict) => conflict.current.title,
              'current title',
              '我的改动',
            ),
          ),
        );
        expect((await store.get(created.id))!.body, '原文');
      },
    );

    test('deleting with a stale revision is refused', () async {
      final store = storeFor('user-a');
      final created = await store.create(title: '要删的');
      final mine = await store.get(created.id);
      mine!.title = '改过';
      await store.update(mine);

      await expectLater(
        store.delete(created.id, revision: 1),
        throwsA(isA<NoteRevisionConflict>()),
      );
      expect(await store.get(created.id), isNotNull);

      await store.delete(created.id, revision: 2);
      expect(await store.get(created.id), isNull);
    });

    test('the replay position can be updated on its own', () async {
      final store = storeFor('user-a');
      final note = await store.create(
        title: '边看边记',
        target: const NoteTarget(
          replaySource: 'ilearn',
          replayId: 'replay-1',
          replayTitle: '第一讲',
        ),
        positionMs: 1000,
      );

      final moved = await store.updatePosition(
        note.id,
        revision: note.revision,
        positionMs: 93000,
      );

      expect(moved.positionMs, 93000);
      expect(moved.revision, 2);
      expect(moved.body, note.body);
    });

    test('a position without a replay is refused at the boundary', () async {
      final store = storeFor('user-a');

      await expectLater(
        store.create(title: '没有回放', positionMs: 500),
        throwsA(isA<NoteValidationException>()),
      );
      await expectLater(
        store.create(
          title: '负数位置',
          target: const NoteTarget(replayId: 'replay-1'),
          positionMs: -1,
        ),
        throwsA(isA<NoteValidationException>()),
      );
      expect(await store.count(), 0);
    });

    test('title and body limits are enforced', () async {
      final store = storeFor('user-a');

      await expectLater(
        store.create(title: 'x' * (NoteLimits.maxTitleLength + 1)),
        throwsA(isA<NoteValidationException>()),
      );
      await expectLater(
        store.create(title: '正文超长', body: 'x' * (NoteLimits.maxBodyLength + 1)),
        throwsA(isA<NoteValidationException>()),
      );
      // 空标题允许：展示层用正文首行兜底。
      final untitled = await store.create(title: '', body: '第一行\n第二行');
      expect(untitled.displayTitle, '第一行');
    });

    test('renaming a replay updates the label but not the revision', () async {
      final store = storeFor('user-a');
      final note = await store.create(
        title: '看回放',
        target: const NoteTarget(
          replaySource: 'ilearn',
          replayId: 'replay-1',
          replayTitle: '旧名字',
        ),
      );

      await store.renameReplay(
        replaySource: 'ilearn',
        replayId: 'replay-1',
        replayTitle: '新名字',
      );

      final reloaded = (await store.get(note.id))!;
      expect(reloaded.replayTitle, '新名字');
      expect(reloaded.revision, 1);
    });

    test('notes outlive the course and replay they point at', () async {
      final store = storeFor('user-a');
      final note = await store.create(
        title: '课程没了也要留',
        target: const NoteTarget(
          courseOfferingId: 'course-gone',
          replaySource: 'ilearn',
          replayId: 'replay-gone',
        ),
      );

      // 来源刷新后课程与回放都不再存在，但笔记本身不受影响。
      final reloaded = (await store.get(note.id))!;
      expect(reloaded.courseOfferingId, 'course-gone');
      expect(reloaded.replayId, 'replay-gone');
      expect(reloaded.body, isEmpty);
      expect(await store.count(), 1);
    });

    test('a store refuses to write a note owned by another user', () async {
      final alice = storeFor('user-a');
      final bob = storeFor('user-b');
      final mine = await alice.create(title: '我的');
      mine.title = '偷改';

      await expectLater(
        bob.update(mine),
        throwsA(isA<NoteValidationException>()),
      );
      // alice 的笔记没有被 bob 的写入影响。
      expect((await alice.get(mine.id))!.title, '我的');
    });
  });
}
