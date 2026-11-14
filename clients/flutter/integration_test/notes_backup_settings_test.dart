import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/features/settings/notes_backup_card.dart';

import '../test/notes_backup_http_test.dart' show openClient;

const _base = String.fromEnvironment('API_BASE_URL');
const _root = String.fromEnvironment('BACKUP_TEST_DATA_DIR');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows selected notes consent, manual sync and preserving restore',
    (tester) async {
      final uri = Uri.parse(_base);
      final source = await openClient(
        uri,
        await Directory('$_root/windows-a').create(recursive: true),
        'noteback1',
        passwordLogin: true,
      );
      final target = await openClient(
        uri,
        await Directory('$_root/windows-b').create(recursive: true),
        'noteback1',
        passwordLogin: true,
      );
      addTearDown(source.close);
      addTearDown(target.close);
      final local = await source.notes.create(
        title: 'Windows 合成笔记',
        body: '本机明确选择后才上传',
      );
      await source.backup.refreshLocal();
      await source.backup.restore();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotesBackupCard(controller: source.backup),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      debugPrint(
        'Windows backup logical viewport: ${tester.view.physicalSize / tester.view.devicePixelRatio}',
      );
      await tester.tap(find.byKey(const Key('notes-backup-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('notes-backup-note-${local.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notes-backup-enable-confirm')));
      await _waitFor(
        tester,
        () =>
            source.backup.enabled &&
            find
                .byKey(const Key('notes-backup-enable-confirm'))
                .evaluate()
                .isEmpty,
      );
      await tester.pumpAndSettle();
      expect(source.backup.enabled, isTrue);
      await tester.tap(find.byKey(const Key('notes-backup-sync')));
      await _waitFor(tester, () => !source.backup.busy);
      await tester.pumpAndSettle();
      expect(source.backup.message, '所选笔记已同步。');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotesBackupCard(controller: target.backup),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notes-backup-restore')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notes-backup-restore-confirm')));
      await _waitFor(tester, () => !target.backup.busy);
      await tester.pumpAndSettle();
      expect(target.backup.enabled, isFalse);
      expect((await target.notes.get(local.id))!.body, '本机明确选择后才上传');
      await tester.pumpWidget(const SizedBox());
    },
    skip: _base.isEmpty || _root.isEmpty,
  );
}

Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) throw TestFailure('备份操作未在20秒内完成');
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
