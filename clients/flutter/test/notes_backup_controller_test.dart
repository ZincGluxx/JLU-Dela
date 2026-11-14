import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_migrations.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/backup/backup_gateway.dart';
import 'package:jlu_dela/core/backup/notes_backup_controller.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/local_draft_store.dart';
import 'package:jlu_dela/features/notes/note_backup_adapter.dart';
import 'package:jlu_dela/features/notes/note_models.dart';
import 'package:jlu_dela/features/notes/note_store.dart';
import 'package:jlu_dela_api/api.dart';

import 'support/session_test_support.dart';

class MemoryBackup implements BackupRemote {
  BackupSnapshot current = BackupSnapshot(
    revision: 0,
    deleted: true,
    notes: [],
    updatedAt: null,
  );
  final Map<String, BackupReceipt> receipts = {};
  final List<String> putKeys = [];
  int reads = 0;
  int deletes = 0;
  bool losePutResponse = false;
  bool loseDeleteResponse = false;
  bool deleteAfterPut = false;
  bool offline = false;
  Completer<BackupSnapshot>? readGate;
  Completer<BackupReceipt>? putGate;

  @override
  Future<BackupSnapshot> read() async {
    reads++;
    if (readGate != null) return readGate!.future;
    if (offline) throw const SocketException('synthetic offline');
    return current;
  }

  @override
  Future<BackupReceipt> put(String key, PutNotesBackupRequest request) async {
    putKeys.add(key);
    if (putGate != null) return putGate!.future;
    if (receipts.containsKey(key)) return receipts[key]!;
    if (request.expectedRevision != current.revision) {
      throw BackupConflict(current);
    }
    final now = DateTime.now().toUtc();
    current = BackupSnapshot(
      revision: current.revision + 1,
      deleted: false,
      notes: request.notes,
      updatedAt: now,
    );
    final result = BackupReceipt(
      revision: current.revision,
      deleted: false,
      updatedAt: now,
    );
    receipts[key] = result;
    if (losePutResponse) {
      losePutResponse = false;
      throw const SocketException('synthetic lost response');
    }
    if (deleteAfterPut) {
      deleteAfterPut = false;
      current = BackupSnapshot(
        revision: current.revision + 1,
        deleted: true,
        notes: [],
        updatedAt: now,
      );
    }
    return result;
  }

  @override
  Future<BackupReceipt> delete(String key, int revision) async {
    deletes++;
    if (receipts.containsKey(key)) return receipts[key]!;
    if (current.revision != revision) throw BackupConflict(current);
    final now = DateTime.now().toUtc();
    current = BackupSnapshot(
      revision: revision + 1,
      deleted: true,
      notes: [],
      updatedAt: now,
    );
    final result = receipts[key] = BackupReceipt(
      revision: current.revision,
      deleted: true,
      updatedAt: now,
    );
    if (loseDeleteResponse) {
      loseDeleteResponse = false;
      throw const SocketException('synthetic lost deletion response');
    }
    return result;
  }
}

class ClientFixture {
  ClientFixture(
    this.database,
    this.session,
    this.backup,
    this.store,
    this.auth,
  );
  final LocalDatabase database;
  final SessionController session;
  final NotesBackupController backup;
  final NoteStore store;
  final FakeAuthGateway auth;
  Future<void> close() async {
    backup.dispose();
    store.dispose();
    session.dispose();
    await database.close();
  }
}

Future<ClientFixture> client(
  Directory directory,
  MemoryBackup remote, {
  String userId = 'user-a',
}) async {
  final database = await LocalDatabase.open(
    migrations: appLocalMigrations,
    path: '${directory.path}/dela.db',
  );
  final auth = FakeAuthGateway(
    onFetchMe: (_) async => testUser(id: userId),
    onRevoke: (_, _) async {},
  );
  final session = SessionController(
    gateway: auth,
    refreshTokenStore: MemoryRefreshTokenStore(),
  );
  await session.signIn(testCredentials());
  final adapter = NoteBackupAdapter(database, userId);
  final backup = NotesBackupController(
    userId: userId,
    session: session,
    remote: remote,
    drafts: LocalDraftStore(database, userId),
    listNotes: adapter.listAll,
    exportNotes: adapter.exportSelected,
    importNotes: adapter.restore,
  );
  await backup.initialize();
  return ClientFixture(
    database,
    session,
    backup,
    NoteStore(database, userId),
    auth,
  );
}

Future<Directory> directory() async {
  final dir = await Directory.systemTemp.createTemp('jlu-backup-client-');
  addTearDown(() => dir.delete(recursive: true));
  return dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'an old write receipt cannot report a later deleted cloud as synced',
    () async {
      final remote = MemoryBackup();
      final a = await client(await directory(), remote);
      addTearDown(a.close);
      final note = await a.store.create(title: 'must confirm current cloud');
      await a.backup.enable({note.id});
      remote.deleteAfterPut = true;
      await a.backup.sync();
      expect(a.backup.conflict?.deleted, isTrue);
      expect(a.backup.lastSuccess, isNull);
      expect(a.backup.message, isNot('所选笔记已同步。'));
      expect(await a.store.count(), 1);
    },
  );

  test(
    'a changed cloud after uncertain delete needs another explicit confirmation',
    () async {
      final remote = MemoryBackup();
      final a = await client(await directory(), remote);
      addTearDown(a.close);
      final note = await a.store.create(title: 'delete retry');
      await a.backup.enable({note.id});
      await a.backup.sync();
      final oldNotes = remote.current.notes;
      remote.loseDeleteResponse = true;
      await a.backup.deleteCloud();
      remote.current = BackupSnapshot(
        revision: 3,
        deleted: false,
        notes: oldNotes,
        updatedAt: DateTime.now().toUtc(),
      );
      await a.backup.deleteCloud();
      expect(a.backup.conflict, isNotNull);
      expect(remote.current.deleted, isFalse);
      await a.backup.deleteCloud();
      expect(remote.current.revision, 4);
      expect(remote.current.deleted, isTrue);
      expect(a.backup.conflict, isNull);
      expect(await a.store.count(), 1);
    },
  );

  test('login, ordinary reads and restore do not authorize upload', () async {
    final remote = MemoryBackup();
    final a = await client(await directory(), remote);
    addTearDown(a.close);
    await a.store.create(title: 'local only');
    await a.backup.refreshLocal();
    await a.backup.sync();
    expect(remote.reads, 0);
    expect(remote.putKeys, isEmpty);
    await a.backup.restore();
    expect(a.backup.enabled, isFalse);
    await a.backup.sync();
    expect(remote.putKeys, isEmpty);
    expect(await a.store.count(), 1);
  });

  test(
    'two independent disk clients recover selected real notes and preserve conflicts',
    () async {
      final remote = MemoryBackup();
      final a = await client(await directory(), remote);
      final b = await client(await directory(), remote);
      addTearDown(a.close);
      addTearDown(b.close);
      final selected = await a.store.create(
        title: '课堂理解',
        body: '合成笔记正文',
        target: const NoteTarget(
          courseOfferingId: 'course-one',
          lessonId: 'lesson-one',
          replaySource: 'ilearn',
          replayId: 'replay-one',
          replayTitle: '第一讲',
        ),
        positionMs: 754000,
      );
      await a.store.create(title: '未选中', body: '不能上传');
      await a.backup.refreshLocal();
      await a.backup.enable({selected.id});
      expect(remote.putKeys, isEmpty);
      expect(a.backup.pendingCount, 1);
      await a.backup.sync();
      expect(remote.current.notes.single.body, '合成笔记正文');
      expect(a.backup.pendingCount, 0);
      await b.backup.restore();
      expect(b.backup.enabled, isFalse);
      var restored = (await b.store.list()).single;
      expect(restored.id, selected.id);
      expect(restored.courseOfferingId, 'course-one');
      expect(restored.lessonId, 'lesson-one');
      expect(restored.replaySource, 'ilearn');
      expect(restored.replayId, 'replay-one');
      expect(restored.positionMs, 754000);
      expect(
        restored.createdAtUtc.millisecondsSinceEpoch,
        selected.createdAtUtc.millisecondsSinceEpoch,
      );
      restored.body = 'B 修改';
      await b.store.update(restored);
      selected.body = 'A 修改';
      await a.store.update(selected);
      await a.backup.refreshLocal();
      await a.backup.sync();
      expect(remote.current.notes.single.body, 'A 修改');
      await b.backup.enable({restored.id});
      await b.backup.sync();
      expect(b.backup.conflict, isNotNull);
      expect(remote.current.notes.single.body, 'A 修改');
      expect((await b.store.list()).single.body, 'B 修改');
      await b.backup.restore();
      expect(
        (await b.store.list()).map((note) => note.body),
        containsAll(['A 修改', 'B 修改']),
      );
      expect(await b.store.count(), 2);
      await b.backup.restore();
      expect(await b.store.count(), 2);
      await b.backup.enable(
        (await b.store.list()).map((note) => note.id).toSet(),
      );
      await b.backup.sync();
      expect(remote.current.notes.length, 2);
    },
  );

  test(
    'uncertain PUT survives process restart with the exact idempotency key and body',
    () async {
      final remote = MemoryBackup();
      final dir = await directory();
      var a = await client(dir, remote);
      final note = await a.store.create(title: 'retry');
      await a.backup.refreshLocal();
      await a.backup.enable({note.id});
      remote.losePutResponse = true;
      await a.backup.sync();
      expect(a.backup.message, contains('本地笔记保留'));
      final key = remote.putKeys.single;
      await a.close();
      a = await client(dir, remote);
      addTearDown(a.close);
      final edited = (await a.store.list()).single..body = '离线后续修改';
      await a.store.update(edited);
      await a.backup.sync();
      expect(remote.putKeys.last, key);
      expect(remote.current.notes.single.body, '');
      await a.backup.refreshLocal();
      expect(a.backup.pendingCount, 1);
      await a.backup.sync();
      expect(remote.current.notes.single.body, '离线后续修改');
      expect(remote.putKeys.last, isNot(key));
    },
  );

  test(
    'offline failure preserves local content and manual retry succeeds',
    () async {
      final remote = MemoryBackup();
      final a = await client(await directory(), remote);
      addTearDown(a.close);
      final note = await a.store.create(title: '断网可读');
      await a.backup.enable({note.id});
      remote.offline = true;
      await a.backup.sync();
      expect(a.backup.message, contains('本地笔记保留'));
      expect((await a.store.get(note.id))!.title, '断网可读');
      remote.offline = false;
      await a.backup.sync();
      expect(remote.current.notes.single.title, '断网可读');
    },
  );

  test(
    'disable discards delayed upload and stops all subsequent upload',
    () async {
      final remote = MemoryBackup();
      final a = await client(await directory(), remote);
      addTearDown(a.close);
      final note = await a.store.create(title: '取消');
      await a.backup.enable({note.id});
      remote.readGate = Completer();
      final operation = a.backup.sync();
      await Future<void>.delayed(Duration.zero);
      await a.backup.disable();
      remote.readGate!.complete(remote.current);
      await operation;
      await a.backup.sync();
      expect(remote.putKeys, isEmpty);
      expect(a.backup.enabled, isFalse);
      expect(a.backup.message, contains('停止后续上传'));
    },
  );

  test(
    'a delayed PUT result after account switch never updates the new account state',
    () async {
      final remote = MemoryBackup();
      final a = await client(await directory(), remote);
      addTearDown(a.close);
      final note = await a.store.create(title: 'A private upload');
      await a.backup.enable({note.id});
      final gate = remote.putGate = Completer();
      final operation = a.backup.sync();
      while (remote.putKeys.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      a.auth.onFetchMe = (_) async => testUser(id: 'user-b');
      await a.session.signIn(testCredentials(accessToken: 'b-access'));
      gate.complete(
        BackupReceipt(
          revision: 1,
          deleted: false,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await operation;
      expect(a.session.currentUser!.id, 'user-b');
      expect(a.backup.available, isEmpty);
      expect(a.backup.lastSuccess, isNull);
      expect(a.backup.cloudRevision, 0);
      expect(await NoteStore(a.database, 'user-b').count(), 0);
      expect(await a.store.count(), 1);
    },
  );

  for (final signOut in [false, true]) {
    test(
      '${signOut ? 'signout' : 'switch account'} rejects delayed restore results and private state',
      () async {
        final remote = MemoryBackup();
        final a = await client(await directory(), remote);
        addTearDown(a.close);
        final gate = remote.readGate = Completer();
        final operation = a.backup.restore();
        await Future<void>.delayed(Duration.zero);
        if (signOut) {
          await a.session.signOut();
        } else {
          a.auth.onFetchMe = (_) async => testUser(id: 'user-b');
          await a.session.signIn(testCredentials(accessToken: 'other-access'));
        }
        gate.complete(
          BackupSnapshot(
            revision: 1,
            deleted: false,
            updatedAt: DateTime.now().toUtc(),
            notes: [
              BackupNote(
                id: '119ad51d-e21a-4620-9d12-a3e0a0f23f42',
                title: '旧账号',
                body: '不得恢复',
                courseOfferingId: null,
                lessonId: null,
                replaySource: null,
                replayId: null,
                replayTitle: null,
                positionMs: null,
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
              ),
            ],
          ),
        );
        await operation;
        expect(await a.store.count(), 0);
        expect(a.backup.available, isEmpty);
        expect(a.backup.lastSuccess, isNull);
      },
    );
  }

  test(
    'disable and delete retain local data and a stale peer cannot recreate cloud content',
    () async {
      final remote = MemoryBackup();
      final a = await client(await directory(), remote);
      final b = await client(await directory(), remote);
      addTearDown(a.close);
      addTearDown(b.close);
      final note = await a.store.create(title: '保留本地');
      await a.backup.enable({note.id});
      await a.backup.sync();
      await b.backup.restore();
      await b.backup.enable({note.id});
      await a.backup.disable();
      await a.backup.deleteCloud();
      expect(remote.current.deleted, isTrue);
      expect(remote.current.notes, isEmpty);
      expect(await a.store.count(), 1);
      await b.backup.sync();
      expect(b.backup.conflict?.deleted, isTrue);
      expect(remote.current.notes, isEmpty);
      expect(await b.store.count(), 1);
    },
  );
}
