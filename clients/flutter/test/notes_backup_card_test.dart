import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/api/diagnostics_service.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/backup/backup_gateway.dart';
import 'package:jlu_dela/core/backup/notes_backup_controller.dart';
import 'package:jlu_dela/core/storage/local_draft_store.dart';
import 'package:jlu_dela/features/settings/notes_backup_card.dart';
import 'package:jlu_dela/features/settings/settings_page.dart';
import 'package:jlu_dela_api/api.dart';

import 'support/session_test_support.dart';

class _Drafts implements LocalDraftStore {
  final _values = <String, Map<String, dynamic>>{};

  @override
  String get userId => 'user-a';

  @override
  Future<Map<String, dynamic>?> read(String scope, String key) async =>
      _values['$scope/$key'];

  @override
  Future<void> write(
    String scope,
    String key,
    Map<String, dynamic> payload,
  ) async {
    _values['$scope/$key'] = payload;
  }

  @override
  Future<void> clear(String scope, String key) async {
    _values.remove('$scope/$key');
  }
}

class _Remote implements BackupRemote {
  BackupSnapshot snapshot = BackupSnapshot(
    revision: 0,
    deleted: true,
    updatedAt: null,
  );
  int reads = 0;
  int deletes = 0;
  final uploads = <PutNotesBackupRequest>[];
  Completer<void>? putGate;

  @override
  Future<BackupSnapshot> read() async {
    reads++;
    return snapshot;
  }

  @override
  Future<BackupReceipt> put(String key, PutNotesBackupRequest request) async {
    uploads.add(request);
    await putGate?.future;
    snapshot = BackupSnapshot(
      revision: request.expectedRevision + 1,
      deleted: false,
      notes: request.notes,
      updatedAt: DateTime.now().toUtc(),
    );
    return BackupReceipt(
      revision: snapshot.revision,
      deleted: false,
      updatedAt: snapshot.updatedAt!,
    );
  }

  @override
  Future<BackupReceipt> delete(String key, int revision) async {
    deletes++;
    snapshot = BackupSnapshot(
      revision: revision + 1,
      deleted: true,
      updatedAt: DateTime.now().toUtc(),
    );
    return BackupReceipt(
      revision: snapshot.revision,
      deleted: true,
      updatedAt: snapshot.updatedAt!,
    );
  }
}

BackupNote _note(String id, {String? title, String body = '正文第一行\n后续正文'}) =>
    BackupNote(
      id: id,
      title: title ?? '笔记 $id',
      body: body,
      courseOfferingId: 'course-a',
      lessonId: 'lesson-a',
      replaySource: 'ilearn',
      replayId: 'replay-a',
      replayTitle: '课程回放',
      positionMs: 12000,
      createdAt: DateTime.utc(2026, 11, 13),
      updatedAt: DateTime.utc(2026, 11, 14),
    );

void main() {
  late SessionController session;
  late NotesBackupController controller;
  late _Remote remote;
  late List<BackupNote> localNotes;
  late List<BackupNote> imported;

  setUp(() async {
    session = SessionController(
      gateway: FakeAuthGateway(
        onFetchMe: (_) async => testUser(),
        onRevoke: (_, _) async {},
        onRefresh: (_) async => throw http.ClientException('offline'),
      ),
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(session.dispose);
    await session.signIn(testCredentials());
    remote = _Remote();
    localNotes = [_note('one'), _note('two', title: '', body: '正文作为标题\n另一行')];
    imported = [];
    controller = NotesBackupController(
      userId: 'user-a',
      session: session,
      remote: remote,
      drafts: _Drafts(),
      listNotes: () async => List.of(localNotes),
      exportNotes: (ids) async =>
          localNotes.where((note) => ids.contains(note.id)).toList(),
      importNotes: (notes, {required isCurrent}) async {
        if (!isCurrent()) return [];
        imported.addAll(notes);
        return notes.map((note) => note.id).toList();
      },
    );
    addTearDown(controller.dispose);
    await controller.initialize();
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    double width = 800,
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('backup-capture-root'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: NotesBackupCard(controller: controller),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
  }

  Future<void> showSelection(WidgetTester tester) =>
      tapKey(tester, 'notes-backup-select');

  Future<void> scrollToNote(WidgetTester tester, String id) async {
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('notes-backup-note-$id')),
      400,
      scrollable: find.descendant(
        of: find.byKey(const Key('notes-backup-selection-list')),
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 100,
      continuous: true,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('capture synthetic backup settings and consent', (tester) async {
    final output = Platform.environment['BACKUP_CAPTURE_DIR'];
    if (output == null) return;
    final fonts = FontLoader('HarmonyOS Sans SC')
      ..addFont(rootBundle.load('assets/fonts/HarmonyOS_Sans_SC_Regular.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await pumpCard(tester, width: 1280);
    Future<void> capture(String name) async {
      final element = find.byKey(const Key('backup-capture-root'));
      final boundary = tester.renderObject<RenderRepaintBoundary>(element);
      final image = (await tester.runAsync(() => boundary.toImage()))!;
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      ))!;
      await tester.runAsync(
        () =>
            File('$output/$name.png').writeAsBytes(bytes.buffer.asUint8List()),
      );
      image.dispose();
    }

    await capture('notes-backup-settings');
    await showSelection(tester);
    await capture('notes-backup-consent');
  });

  testWidgets(
    'signout clears private note text from the open selection route',
    (tester) async {
      await pumpCard(tester);
      await showSelection(tester);
      expect(find.text('笔记 one'), findsOneWidget);
      expect(find.text('正文第一行'), findsOneWidget);
      await tester.runAsync(session.signOut);
      await tester.pumpAndSettle();
      expect(find.text('笔记 one'), findsNothing);
      expect(find.text('正文第一行'), findsNothing);
      expect(find.text('账号已变化'), findsOneWidget);
      expect(remote.uploads, isEmpty);
    },
  );

  testWidgets('no upload before explicit selection, consent and manual sync', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.text('未开启'), findsOneWidget);
    expect(find.text('最近成功：暂无记录'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('notes-backup-sync')))
          .onPressed,
      isNull,
    );
    expect(remote.reads, 0);
    expect(remote.uploads, isEmpty);
    await showSelection(tester);
    expect(find.textContaining('凭据不在备份中'), findsOneWidget);
    expect(find.textContaining('回放来源'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('notes-backup-enable-confirm')),
          )
          .onPressed,
      isNull,
    );
    await scrollToNote(tester, 'one');
    await tapKey(tester, 'notes-backup-note-one');
    expect(controller.enabled, isFalse);
    expect(remote.uploads, isEmpty);
    await tapKey(tester, 'notes-backup-enable-confirm');
    expect(controller.enabled, isTrue);
    expect(controller.selectedIds, {'one'});
    expect(remote.reads, 0);
    expect(remote.uploads, isEmpty);
    expect(find.text('已选 1 条 · 待同步 1 项'), findsOneWidget);
    await tapKey(tester, 'notes-backup-sync');
    expect(remote.uploads.single.notes.map((note) => note.id), ['one']);
    expect(find.text('已选 1 条 · 待同步 0 项'), findsOneWidget);
    expect(find.text('所选笔记已同步。'), findsOneWidget);
    expect(controller.lastSuccess, isNotNull);
  });

  testWidgets('refresh local status picks up edits without uploading', (
    tester,
  ) async {
    await tester.runAsync(() => controller.enable({'one'}));
    await tester.runAsync(controller.sync);
    await pumpCard(tester);
    expect(find.text('已选 1 条 · 待同步 0 项'), findsOneWidget);
    localNotes[0] = _note('one', body: '更新后的正文');
    await tapKey(tester, 'notes-backup-refresh-local');
    expect(find.text('已选 1 条 · 待同步 1 项'), findsOneWidget);
    expect(remote.uploads.length, 1);
  });

  testWidgets('cancelling consent leaves backup disabled', (tester) async {
    await pumpCard(tester);
    await showSelection(tester);
    await scrollToNote(tester, 'two');
    expect(find.text('正文作为标题'), findsOneWidget);
    await tapKey(tester, 'notes-backup-note-two');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.enabled, isFalse);
    expect(controller.selectedIds, isEmpty);
    expect(remote.reads, 0);
    expect(remote.uploads, isEmpty);
  });

  testWidgets(
    'range updates require the same consent and new notes are unchecked',
    (tester) async {
      await tester.runAsync(() => controller.enable({'one'}));
      localNotes.add(_note('new'));
      await pumpCard(tester);
      await showSelection(tester);
      await scrollToNote(tester, 'new');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('notes-backup-note-new')),
            )
            .value,
        isFalse,
      );
      await scrollToNote(tester, 'two');
      await tapKey(tester, 'notes-backup-note-two');
      expect(controller.selectedIds, {'one'});
      await tapKey(tester, 'notes-backup-enable-confirm');
      expect(controller.selectedIds, {'one', 'two'});
      expect(remote.uploads, isEmpty);
      expect(remote.reads, 0);
    },
  );

  testWidgets('all local notes remain scrollable beyond the selection limit', (
    tester,
  ) async {
    localNotes = List.generate(125, (index) => _note('note-$index'));
    await controller.refreshLocal();
    await tester.runAsync(
      () => controller.enable(
        localNotes.take(100).map((note) => note.id).toSet(),
      ),
    );
    await pumpCard(tester, width: 375);
    await showSelection(tester);
    await scrollToNote(tester, 'note-124');
    await tapKey(tester, 'notes-backup-note-note-124');
    expect(find.text('超出备份上限，请减少所选笔记。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('notes-backup-enable-confirm')),
          )
          .onPressed,
      isNull,
    );
    expect(controller.selectedIds.length, 100);
    expect(remote.uploads, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consent is disabled above 512 KiB', (tester) async {
    localNotes = [_note('large', body: '正文首行\n${'x' * (512 * 1024)}')];
    await controller.refreshLocal();
    await pumpCard(tester);
    await showSelection(tester);
    await scrollToNote(tester, 'large');
    await tapKey(tester, 'notes-backup-note-large');
    expect(find.text('超出备份上限，请减少所选笔记。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('notes-backup-enable-confirm')),
          )
          .onPressed,
      isNull,
    );
    expect(controller.enabled, isFalse);
    expect(remote.uploads, isEmpty);
  });

  testWidgets('empty local state has no fabricated notes or automatic upload', (
    tester,
  ) async {
    localNotes = [];
    await controller.refreshLocal();
    await pumpCard(tester);
    expect(find.byKey(const Key('notes-backup-empty')), findsOneWidget);
    await showSelection(tester);
    expect(find.text('本机暂无可选择的笔记。'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('notes-backup-enable-confirm')),
          )
          .onPressed,
      isNull,
    );
    expect(remote.uploads, isEmpty);
  });

  testWidgets(
    'deleting cloud requires explicit confirmation and preserves local notes',
    (tester) async {
      await tester.runAsync(() => controller.enable({'one'}));
      await pumpCard(tester);
      await tapKey(tester, 'notes-backup-delete');
      expect(find.textContaining('运维备份按保留策略管理'), findsOneWidget);
      expect(remote.deletes, 0);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(remote.deletes, 0);
      expect(controller.enabled, isTrue);
      await tapKey(tester, 'notes-backup-delete');
      await tapKey(tester, 'notes-backup-delete-confirm');
      expect(remote.deletes, 1);
      expect(controller.enabled, isFalse);
      expect(localNotes.length, 2);
      expect(remote.uploads, isEmpty);
      expect(find.textContaining('已删除当前云端副本，本地笔记保留。'), findsOneWidget);
    },
  );

  testWidgets('restore confirms preservation and never authorizes uploading', (
    tester,
  ) async {
    remote.snapshot = BackupSnapshot(
      revision: 2,
      deleted: false,
      notes: [_note('cloud')],
      updatedAt: DateTime.utc(2026, 11, 14),
    );
    await pumpCard(tester);
    await tapKey(tester, 'notes-backup-restore');
    expect(remote.reads, 0);
    expect(find.textContaining('恢复不会授权上传'), findsOneWidget);
    await tapKey(tester, 'notes-backup-restore-confirm');
    expect(imported.single.id, 'cloud');
    expect(controller.enabled, isFalse);
    expect(remote.uploads, isEmpty);
    expect(localNotes.length, 2);
  });

  testWidgets('conflict blocks overwriting and offers preserving restore', (
    tester,
  ) async {
    await tester.runAsync(() => controller.enable({'one'}));
    remote.snapshot = BackupSnapshot(
      revision: 4,
      deleted: false,
      notes: [_note('cloud')],
      updatedAt: DateTime.utc(2026, 11, 14),
    );
    await pumpCard(tester);
    await tapKey(tester, 'notes-backup-sync');
    expect(find.byKey(const Key('notes-backup-conflict')), findsOneWidget);
    expect(remote.uploads, isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('notes-backup-sync')))
          .onPressed,
      isNull,
    );
    await tapKey(tester, 'notes-backup-restore');
    await tapKey(tester, 'notes-backup-restore-confirm');
    expect(imported.single.id, 'cloud');
    expect(find.byKey(const Key('notes-backup-conflict')), findsNothing);
    expect(controller.enabled, isFalse);
    expect(remote.uploads, isEmpty);
  });

  testWidgets(
    'offline operations are disabled but local backup can be stopped',
    (tester) async {
      await tester.runAsync(() => controller.enable({'one'}));
      await pumpCard(tester);
      await tester.runAsync(session.refreshSession);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notes-backup-offline')), findsOneWidget);
      for (final key in ['notes-backup-select', 'notes-backup-restore']) {
        expect(
          tester.widget<OutlinedButton>(find.byKey(Key(key))).onPressed,
          isNull,
        );
      }
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('notes-backup-sync')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('notes-backup-delete')))
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'notes-backup-disable');
      expect(controller.enabled, isFalse);
      expect(remote.reads, 0);
      expect(remote.uploads, isEmpty);
      expect(remote.deletes, 0);
    },
  );

  testWidgets(
    'busy progress is visible and stopping backup remains available',
    (tester) async {
      await tester.runAsync(() => controller.enable({'one'}));
      final gate = Completer<void>();
      remote.putGate = gate;
      await pumpCard(tester);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('notes-backup-sync')));
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(controller.busy, isTrue);
      expect(find.byKey(const Key('notes-backup-progress')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('notes-backup-sync')))
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'notes-backup-disable');
      expect(controller.enabled, isFalse);
      expect(find.byKey(const Key('notes-backup-progress')), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(controller.enabled, isFalse);
      expect(controller.lastSuccess, isNull);
    },
  );

  for (final width in [375.0, 800.0, 1100.0, 1920.0]) {
    testWidgets('card and consent wrap long content at width $width', (
      tester,
    ) async {
      localNotes = [_note('long', title: '可换行的长笔记标题' * 12, body: '正文第一行' * 20)];
      await controller.refreshLocal();
      await pumpCard(tester, width: width, scale: 1.4);
      await showSelection(tester);
      await scrollToNote(tester, 'long');
      await tapKey(tester, 'notes-backup-note-long');
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'notes-backup-enable-confirm');
      await tester.ensureVisible(find.byKey(const Key('notes-backup-delete')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'settings injects the optional controller in its existing scrollable header',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final diagnostics = DiagnosticsService(
        apiBaseUri: Uri.parse('http://127.0.0.1:8080'),
        httpClient: MockClient((_) async => http.Response('', 404)),
        clientVersionLoader: () async => '0.1.0',
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: Scaffold(
            body: SettingsPage(
              diagnosticsService: diagnostics,
              session: session,
              glassEnabled: false,
              onGlassEnabledChanged: (_) {},
              notesBackup: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('notes-backup-delete')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notes-backup-card')), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('notes-backup-card')),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(remote.reads, 0);
      expect(remote.uploads, isEmpty);
    },
  );
}
