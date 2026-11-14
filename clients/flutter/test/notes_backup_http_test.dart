import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jlu_dela/app/local_migrations.dart';
import 'package:jlu_dela/core/auth/account_gateway.dart';
import 'package:jlu_dela/core/auth/auth_gateway.dart';
import 'package:jlu_dela/core/auth/workbench_api.dart';
import 'package:jlu_dela/core/backup/backup_gateway.dart';
import 'package:jlu_dela/core/backup/notes_backup_controller.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/local_draft_store.dart';
import 'package:jlu_dela/features/notes/note_backup_adapter.dart';
import 'package:jlu_dela/features/notes/note_models.dart';
import 'package:jlu_dela/features/notes/note_store.dart';

import 'support/session_test_support.dart';

class HttpClientFixture {
  HttpClientFixture(this.database, this.api, this.backup, this.notes);
  final LocalDatabase database;
  final WorkbenchApi api;
  final NotesBackupController backup;
  final NoteStore notes;
  Future<void> close() async {
    backup.dispose();
    notes.dispose();
    api.close();
    await database.close();
  }
}

Future<HttpClientFixture> openClient(
  Uri baseUri,
  Directory directory,
  String phone, {
  bool create = false,
  bool passwordLogin = false,
}) async {
  final transport = http.Client();
  final accounts = HttpAccountGateway(baseUri: baseUri, httpClient: transport);
  if (create) {
    expect((await accounts.sendPhoneCode(phone)).devMode, isTrue);
  }
  final credentials = passwordLogin
      ? await accounts.login(login: phone, password: 'SyntheticA1')
      : await accounts.loginWithPhone(phone: phone, smsCode: '114514');
  transport.close();
  final api = WorkbenchApi(
    baseUri: baseUri,
    authGateway: HttpAuthGateway(baseUri: baseUri),
    refreshTokenStore: MemoryRefreshTokenStore(),
  );
  await api.session.signIn(credentials);
  final owner = api.session.currentUser!.id;
  final database = await LocalDatabase.open(
    migrations: appLocalMigrations,
    path: '${directory.path}/dela.db',
  );
  final adapter = NoteBackupAdapter(database, owner);
  final backup = NotesBackupController(
    userId: owner,
    session: api.session,
    remote: BackupGateway(api.apiClient),
    drafts: LocalDraftStore(database, owner),
    listNotes: adapter.listAll,
    exportNotes: adapter.exportSelected,
    importNotes: adapter.restore,
  );
  await backup.initialize();
  return HttpClientFixture(database, api, backup, NoteStore(database, owner));
}

void main() {
  final base = Platform.environment['BACKUP_TEST_API'];
  final root = Platform.environment['BACKUP_TEST_DATA_DIR'];
  test(
    'real HTTP notes backup between independent SQLite client directories',
    () async {
      final uri = Uri.parse(base!);
      final aDir = await Directory('$root/client-a').create(recursive: true);
      final bDir = await Directory('$root/client-b').create(recursive: true);
      final otherDir = await Directory(
        '$root/client-other',
      ).create(recursive: true);
      final a = await openClient(uri, aDir, '13800004401', create: true);
      addTearDown(a.close);
      await a.api.session.updateAccount(
        username: 'noteback1',
        password: 'SyntheticA1',
      );
      final b = await openClient(uri, bDir, 'noteback1', passwordLogin: true);
      addTearDown(b.close);
      final other = await openClient(
        uri,
        otherDir,
        '13800004402',
        create: true,
      );
      addTearDown(other.close);
      expect(a.database.database.path, isNot(b.database.database.path));
      expect(a.api.session.currentUser!.id, b.api.session.currentUser!.id);
      expect(
        a.api.session.currentUser!.id,
        isNot(other.api.session.currentUser!.id),
      );

      final note = await a.notes.create(
        title: '合成课程笔记',
        body: 'A 初始理解',
        target: const NoteTarget(
          courseOfferingId: 'synthetic-course',
          lessonId: 'synthetic-lesson',
          replaySource: 'ilearn',
          replayId: 'synthetic-replay',
          replayTitle: '合成回放',
        ),
        positionMs: 754000,
      );
      await a.notes.create(title: '不上传的私人笔记', body: '未选内容');
      final remoteA = BackupGateway(a.api.apiClient);
      final remoteOther = BackupGateway(other.api.apiClient);
      await a.backup.refreshLocal();
      await a.backup.sync();
      expect((await remoteA.read()).revision, 0);
      await a.backup.enable({note.id});
      expect((await remoteA.read()).revision, 0);
      await a.backup.sync();
      expect(a.backup.message, '所选笔记已同步。');
      expect((await remoteA.read()).notes.single.id, note.id);
      expect((await remoteOther.read()).notes, isEmpty);

      await b.backup.restore();
      expect(b.backup.enabled, isFalse);
      final bNote = (await b.notes.list()).single;
      expect(bNote.courseOfferingId, 'synthetic-course');
      expect(bNote.lessonId, 'synthetic-lesson');
      expect(bNote.replayId, 'synthetic-replay');
      expect(bNote.positionMs, 754000);
      note.body = 'A 后续修改';
      await a.notes.update(note);
      await a.backup.refreshLocal();
      await a.backup.sync();
      expect((await remoteA.read()).notes.single.body, 'A 后续修改');
      bNote.body = 'B 独立修改';
      await b.notes.update(bNote);
      await b.backup.enable({bNote.id});
      await b.backup.sync();
      expect(b.backup.conflict, isNotNull);
      expect((await remoteA.read()).notes.single.body, 'A 后续修改');
      await b.backup.restore();
      final both = await b.notes.list();
      expect(both.map((item) => item.body), containsAll(['A 后续修改', 'B 独立修改']));
      expect(both.length, 2);
      await b.backup.enable(both.map((item) => item.id).toSet());
      await b.backup.sync();
      expect((await remoteA.read()).notes.length, 2);
      await a.backup.disable();
      final oldRevision = (await remoteA.read()).revision;
      await a.backup.sync();
      expect((await remoteA.read()).revision, oldRevision);
      await a.backup.deleteCloud();
      expect((await remoteA.read()).deleted, isTrue);
      expect((await remoteA.read()).notes, isEmpty);
      expect(await a.notes.count(), 2);
      await b.backup.sync();
      expect(b.backup.conflict?.deleted, isTrue);
      expect((await remoteOther.read()).revision, 0);
      expect(await b.notes.count(), 2);
      final owner = a.api.session.currentUser!.id;
      await a.api.session.signOut();
      expect(a.backup.available, isEmpty);
      expect((await NoteStore(a.database, owner).list()).length, 2);
      // The directory remains as synthetic evidence; no app default directory is used.
    },
    skip: base == null || root == null
        ? 'Requires isolated BACKUP_TEST_API and BACKUP_TEST_DATA_DIR.'
        : false,
  );
}
