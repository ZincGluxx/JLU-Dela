import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_migrations.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/features/notes/note_backup_adapter.dart';
import 'package:jlu_dela/features/notes/note_models.dart';
import 'package:jlu_dela/features/notes/note_store.dart';
import 'package:jlu_dela_api/api.dart' show BackupNote;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late String databasePath;
  late LocalDatabase database;
  late NoteBackupAdapter adapter;

  Future<void> openDatabase() async {
    database = await LocalDatabase.open(
      migrations: appLocalMigrations,
      path: databasePath,
      databaseFactory: databaseFactoryFfiNoIsolate,
    );
    adapter = NoteBackupAdapter(database, 'user-a');
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('jlu_note_backup_test_');
    databasePath = p.join(directory.path, 'notes.db');
    await openDatabase();
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'restore preserves IDs, references and UTC millisecond timestamps',
    () async {
      final createdAt = DateTime.fromMicrosecondsSinceEpoch(
        DateTime.utc(2026, 11, 13, 8, 9, 10, 123).microsecondsSinceEpoch + 456,
      );
      final updatedAt = DateTime.fromMicrosecondsSinceEpoch(
        DateTime.utc(2026, 11, 14, 8, 9, 10, 789).microsecondsSinceEpoch + 321,
      );
      final note = _backup(
        courseOfferingId: ' course-no-longer-present ',
        lessonId: 'lesson-no-longer-present',
        replaySource: ' ilearn ',
        replayId: ' replay-no-longer-present ',
        replayTitle: '第三讲回放',
        positionMs: 754000,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(await adapter.restore([note], isCurrent: () => true), [note.id]);
      expect(await File(databasePath).exists(), isTrue);
      await database.close();
      await openDatabase();

      final restored = (await NoteStore(database, 'user-a').get(note.id))!;
      expect(restored.revision, 1);
      expect(restored.courseOfferingId, note.courseOfferingId);
      expect(restored.lessonId, note.lessonId);
      expect(restored.replaySource, note.replaySource);
      expect(restored.replayId, note.replayId);
      expect(restored.replayTitle, note.replayTitle);
      expect(restored.positionMs, note.positionMs);
      expect(restored.createdAtUtc.isUtc, isTrue);
      expect(restored.updatedAtUtc.isUtc, isTrue);
      expect(restored.createdAtUtc.microsecond, 0);
      expect(restored.updatedAtUtc.microsecond, 0);
      expect(
        restored.createdAtUtc.millisecondsSinceEpoch,
        createdAt.millisecondsSinceEpoch,
      );
      expect(
        restored.updatedAtUtc.millisecondsSinceEpoch,
        updatedAt.millisecondsSinceEpoch,
      );
      expect(await database.database.query('course_offerings'), isEmpty);
      expect(await database.database.query('teaching_lessons'), isEmpty);

      final exported = (await adapter.exportSelected({note.id})).single;
      expect(exported.courseOfferingId, note.courseOfferingId);
      expect(exported.lessonId, note.lessonId);
      expect(exported.replaySource, note.replaySource);
      expect(exported.replayId, note.replayId);
      expect(exported.replayTitle, note.replayTitle);
      expect(exported.positionMs, note.positionMs);
      expect(exported.createdAt, restored.createdAtUtc);
      expect(exported.updatedAt, restored.updatedAtUtc);
    },
  );

  test(
    'export contains nullable DTO fields, not owner or local revision',
    () async {
      final store = NoteStore(database, 'user-a');
      final local = await store.create(title: '随手记', body: '第一行\n第二行');
      local.body = '修改后的正文';
      await store.update(local);

      final exported = (await adapter.exportSelected({local.id})).single;
      expect(exported.id, local.id);
      expect(exported.body, '修改后的正文');
      expect(exported.createdAt.isUtc, isTrue);
      expect(exported.updatedAt.isUtc, isTrue);
      expect(exported.toJson(), containsPair('course_offering_id', null));
      expect(exported.toJson(), containsPair('lesson_id', null));
      expect(exported.toJson(), containsPair('replay_source', null));
      expect(exported.toJson(), containsPair('replay_id', null));
      expect(exported.toJson(), containsPair('replay_title', null));
      expect(exported.toJson(), containsPair('position_ms', null));
      expect(exported.toJson(), isNot(contains('user_id')));
      expect(exported.toJson(), isNot(contains('revision')));
      expect(await adapter.restore([exported], isCurrent: () => true), [
        local.id,
      ]);
      expect((await store.get(local.id))!.revision, 2);
    },
  );

  test(
    'repeated restore reuses the original note without adding rows',
    () async {
      final note = _backup();
      expect(await adapter.restore([note, note], isCurrent: () => true), [
        note.id,
        note.id,
      ]);
      expect(await adapter.restore([note], isCurrent: () => true), [note.id]);
      expect(await adapter.listAll(), [note]);
    },
  );

  test(
    'local ID conflicts keep both versions with a stable cloud copy',
    () async {
      final store = NoteStore(database, 'user-a');
      final local = await store.create(title: '本地版本', body: '本机编辑');
      local.body = '本机最新编辑';
      await store.update(local);
      final before = (await database.database.query('notes')).single;
      final cloud = _backup(id: local.id, title: '云端版本', body: '远端正文');

      final restored = await adapter.restore([cloud], isCurrent: () => true);
      final copyId = restored.single;
      expect(copyId, isNot(local.id));
      expect(copyId[14], '5');
      expect((await store.get(copyId))!.body, cloud.body);
      expect((await store.get(copyId))!.revision, 1);
      expect(
        (await database.database.query(
          'notes',
          where: 'id = ?',
          whereArgs: [local.id],
        )).single,
        before,
      );

      await database.close();
      await openDatabase();
      expect(await adapter.restore([cloud], isCurrent: () => true), [copyId]);
      expect(await NoteStore(database, 'user-a').count(), 2);
      final sameMillis = _backup(
        id: cloud.id,
        title: cloud.title,
        body: cloud.body,
        createdAt: cloud.createdAt.add(const Duration(microseconds: 123)),
        updatedAt: cloud.updatedAt.add(const Duration(microseconds: 456)),
      );
      expect(await adapter.restore([sameMillis], isCurrent: () => true), [
        copyId,
      ]);
      expect(await NoteStore(database, 'user-a').count(), 2);
    },
  );

  test('an ID owned by another user is never reused or replaced', () async {
    final cloud = _backup();
    final bob = NoteBackupAdapter(database, 'user-b');
    expect(await bob.restore([cloud], isCurrent: () => true), [cloud.id]);
    final before = (await database.database.query('notes')).single;

    final copyId = (await adapter.restore([
      cloud,
    ], isCurrent: () => true)).single;
    expect(copyId, isNot(cloud.id));
    expect(await adapter.restore([cloud], isCurrent: () => true), [copyId]);
    expect((await adapter.listAll()).single.id, copyId);
    expect((await bob.listAll()).single.id, cloud.id);
    expect(
      (await database.database.query(
        'notes',
        where: 'id = ?',
        whereArgs: [cloud.id],
      )).single,
      before,
    );
    expect(await adapter.exportSelected({copyId}), hasLength(1));
    await expectLater(
      adapter.exportSelected({cloud.id}),
      throwsA(isA<NoteValidationException>()),
    );
    expect(await database.database.query('notes'), hasLength(2));
  });

  test(
    'a changed cloud copy is not silently overwritten or duplicated',
    () async {
      final local = _backup(title: '本地原文');
      final cloud = _backup(title: '云端原文');
      await adapter.restore([local], isCurrent: () => true);
      final copyId = (await adapter.restore([
        cloud,
      ], isCurrent: () => true)).single;
      final store = NoteStore(database, 'user-a');
      final copy = (await store.get(copyId))!..body = '副本上的新编辑';
      await store.update(copy);

      final imported = await adapter.restore([
        _backup(index: 2),
        cloud,
      ], isCurrent: () => true);
      expect(imported.last, isNot(copyId));
      expect((await store.get(imported.last))!.body, cloud.body);
      expect(
        await adapter.restore([
          _backup(index: 2),
          cloud,
        ], isCurrent: () => true),
        imported,
      );
      expect(await store.count(), 4);
      expect((await store.get(copyId))!.body, '副本上的新编辑');
      expect((await store.get(local.id))!.title, local.title);
    },
  );

  test('cloud copy IDs are deterministic and scoped to the owner', () async {
    final cloud = _backup();
    await NoteBackupAdapter(
      database,
      'original-owner',
    ).restore([cloud], isCurrent: () => true);
    final aliceCopy = (await adapter.restore([
      cloud,
    ], isCurrent: () => true)).single;
    final bob = NoteBackupAdapter(database, 'user-b');
    final bobCopy = (await bob.restore([cloud], isCurrent: () => true)).single;

    expect(aliceCopy, isNot(bobCopy));
    expect(await bob.restore([cloud], isCurrent: () => true), [bobCopy]);
    expect(await adapter.restore([cloud], isCurrent: () => true), [aliceCopy]);
    expect(await database.database.query('notes'), hasLength(3));
  });

  for (var checkpoint = 1; checkpoint <= 5; checkpoint++) {
    test(
      'stale session at transaction checkpoint $checkpoint rolls back all inserts',
      () async {
        var checks = 0;
        await expectLater(
          adapter.restore([
            _backup(),
            _backup(index: 2),
          ], isCurrent: () => ++checks < checkpoint),
          throwsA(isA<StateError>()),
        );
        expect(checks, checkpoint);
        expect(await adapter.listAll(), isEmpty);
      },
    );
  }

  for (final checkpoint in [3, 4]) {
    test(
      'stale session after conflict await $checkpoint preserves local content',
      () async {
        final local = _backup(title: '本地版本');
        await adapter.restore([local], isCurrent: () => true);
        var checks = 0;
        await expectLater(
          adapter.restore([
            _backup(title: '云端版本'),
          ], isCurrent: () => ++checks < checkpoint),
          throwsA(isA<StateError>()),
        );
        expect(checks, checkpoint);
        expect(await adapter.listAll(), [local]);
      },
    );
  }

  test(
    'listAll is complete and scoped while selection and restore cap at 100',
    () async {
      final notes = List.generate(101, (index) => _backup(index: index));
      await adapter.restore(notes.take(100).toList(), isCurrent: () => true);
      await adapter.restore([notes.last], isCurrent: () => true);
      final bob = NoteBackupAdapter(database, 'user-b');
      await bob.restore([_backup(index: 102)], isCurrent: () => true);

      expect(await adapter.listAll(), hasLength(101));
      expect(await bob.listAll(), hasLength(1));
      expect(
        (await adapter.listAll()).map((note) => note.id),
        orderedEquals(notes.map((note) => note.id)),
      );
      await expectLater(
        adapter.exportSelected(notes.map((note) => note.id).toSet()),
        throwsA(isA<NoteValidationException>()),
      );
      await expectLater(
        adapter.restore(notes, isCurrent: () => true),
        throwsA(isA<NoteValidationException>()),
      );
      expect(
        await adapter.exportSelected(
          notes.take(100).map((note) => note.id).toSet(),
        ),
        hasLength(100),
      );
      expect(await adapter.exportSelected({}), isEmpty);
      await expectLater(
        adapter.exportSelected({notes.first.id, _backup(index: 103).id}),
        throwsA(isA<NoteValidationException>()),
      );
    },
  );

  test(
    'export and restore enforce the UTF-8 JSON size, not character count',
    () async {
      final notes = List.generate(
        9,
        (index) => _backup(index: index, body: '界' * 20000),
      );
      expect(jsonEncode(notes).length, lessThan(512 * 1024));
      expect(utf8.encode(jsonEncode(notes)).length, greaterThan(512 * 1024));
      await expectLater(
        adapter.restore(notes, isCurrent: () => true),
        throwsA(isA<NoteValidationException>()),
      );
      expect(await adapter.listAll(), isEmpty);
      await adapter.restore(notes.take(8).toList(), isCurrent: () => true);
      await adapter.restore([notes.last], isCurrent: () => true);

      await expectLater(
        adapter.exportSelected(notes.map((note) => note.id).toSet()),
        throwsA(isA<NoteValidationException>()),
      );
      expect(
        await adapter.exportSelected(
          notes.take(8).map((note) => note.id).toSet(),
        ),
        hasLength(8),
      );
      expect(await adapter.listAll(), hasLength(9));
    },
  );

  test('exactly 512 KiB is allowed, one additional byte is refused', () async {
    final notes = List.generate(27, (index) => _backup(index: index, body: ''));
    var remaining = 512 * 1024 - utf8.encode(jsonEncode(notes)).length;
    for (final note in notes) {
      final length = remaining > 20000 ? 20000 : remaining;
      note.body = 'x' * length;
      remaining -= length;
    }
    expect(remaining, 0);
    expect(utf8.encode(jsonEncode(notes)).length, 512 * 1024);
    final ids = notes.map((note) => note.id).toSet();
    expect(await adapter.restore(notes, isCurrent: () => true), hasLength(27));
    expect(await adapter.exportSelected(ids), hasLength(27));

    notes.last.body += 'x';
    await expectLater(
      adapter.restore(notes, isCurrent: () => true),
      throwsA(isA<NoteValidationException>()),
    );
    await database.database.update(
      'notes',
      {'body': notes.last.body},
      where: 'id = ? AND user_id = ?',
      whereArgs: [notes.last.id, 'user-a'],
    );
    await expectLater(
      adapter.exportSelected(ids),
      throwsA(isA<NoteValidationException>()),
    );
  });

  test('title and body use E rune limits and title trimming', () async {
    final note = _backup(title: '  ${'😀' * 200}  ', body: '😀' * 20000);
    await adapter.restore([note], isCurrent: () => true);
    expect((await adapter.listAll()).single.title, '😀' * 200);
    expect((await adapter.listAll()).single.body, note.body);
    for (final invalid in [
      _backup(index: 2, title: '😀' * 201),
      _backup(index: 2, body: '😀' * 20001),
    ]) {
      await expectLater(
        adapter.restore([_backup(index: 3), invalid], isCurrent: () => true),
        throwsA(isA<NoteValidationException>()),
      );
    }
    expect(await adapter.listAll(), hasLength(1));
  });

  test(
    'invalid replay identities, positions, IDs and timestamps are refused',
    () async {
      final invalidNotes = [
        _backup(replayId: 'replay-only'),
        _backup(replaySource: 'ilearn'),
        _backup(replaySource: ' ', replayId: 'replay-1'),
        _backup(positionMs: 0),
        _backup(replaySource: 'ilearn', replayId: 'replay-1', positionMs: -1),
        _backup(id: 'not-a-uuid'),
        _backup(createdAt: DateTime.utc(2026, 11, 15)),
      ];
      for (final note in invalidNotes) {
        await expectLater(
          adapter.restore([_backup(index: 2), note], isCurrent: () => true),
          throwsA(isA<NoteValidationException>()),
        );
      }
      expect(await adapter.listAll(), isEmpty);
      await adapter.restore([
        _backup(replaySource: ' ', replayId: ''),
        _backup(
          index: 2,
          replaySource: 'ilearn',
          replayId: 'replay-1',
          positionMs: 0,
        ),
      ], isCurrent: () => true);
      expect(await adapter.listAll(), hasLength(2));
    },
  );

  test(
    'export validates selected local content rather than shipping invalid rows',
    () async {
      final note = _backup();
      await adapter.restore([note], isCurrent: () => true);
      await database.database.update(
        'notes',
        {'replay_source': 'ilearn'},
        where: 'id = ? AND user_id = ?',
        whereArgs: [note.id, 'user-a'],
      );
      await expectLater(
        adapter.exportSelected({note.id}),
        throwsA(isA<NoteValidationException>()),
      );
      expect(await adapter.listAll(), hasLength(1));
    },
  );
}

BackupNote _backup({
  int index = 1,
  String? id,
  String title = '课程笔记',
  String body = '贝叶斯公式',
  String? courseOfferingId,
  String? lessonId,
  String? replaySource,
  String? replayId,
  String? replayTitle,
  int? positionMs,
  DateTime? createdAt,
  DateTime? updatedAt,
}) => BackupNote(
  id: id ?? '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
  title: title,
  body: body,
  courseOfferingId: courseOfferingId,
  lessonId: lessonId,
  replaySource: replaySource,
  replayId: replayId,
  replayTitle: replayTitle,
  positionMs: positionMs,
  createdAt: createdAt ?? DateTime.utc(2026, 11, 13, 8, 9, 10, 123),
  updatedAt: updatedAt ?? DateTime.utc(2026, 11, 14, 8, 9, 10, 789),
);
