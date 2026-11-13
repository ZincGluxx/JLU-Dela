import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/features/mail/mail_models.dart';
import 'package:jlu_dela/features/mail/mail_store.dart';

import 'support/local_database_test_support.dart';

void main() {
  late LocalDatabase database;
  late MailStore store;
  late DateTime clock;

  setUp(() async {
    database = await openTestDatabase();
    clock = DateTime.utc(2026, 11, 13, 10);
    store = MailStore(database, 'user-a', now: () => clock);
  });

  tearDown(() async {
    store.dispose();
    await database.close();
  });

  Future<MailAccount> seedAccount() => store.upsertAccount(
    address: 'dela@mails.jlu.edu.cn',
    displayName: '测试账号',
  );

  Future<MailFolder> seedInbox(MailAccount account) async {
    await store.replaceFolders(account.id, const [
      MailFolderSnapshot(
        path: 'INBOX',
        name: '收件箱',
        specialUse: r'\Inbox',
        uidValidity: '1',
        total: 3,
        unread: 1,
      ),
    ], complete: true);
    return (await store.folderByPath(account.id, 'INBOX'))!;
  }

  group('accounts', () {
    test(
      'saves the JLU preset and keeps credentials out of the database',
      () async {
        final account = await seedAccount();

        expect(account.server.imapHost, 'mails.jlu.edu.cn');
        expect(account.server.imapPort, 993);
        expect(account.server.smtpHost, 'mails.jlu.edu.cn');
        expect(account.server.smtpPort, 465);
        expect(account.connectionState, MailConnectionState.unknown);

        final columns = await database.database.rawQuery(
          'PRAGMA table_info(mail_accounts)',
        );
        final names = columns.map((row) => row['name'] as String).toSet();
        expect(names.any((name) => name.contains('password')), isFalse);
        expect(names.any((name) => name.contains('secret')), isFalse);
      },
    );

    test('upserting the same address updates rather than duplicates', () async {
      final first = await seedAccount();
      final second = await store.upsertAccount(
        address: '  dela@mails.jlu.edu.cn  ',
        displayName: '改名',
      );

      expect(second.id, first.id);
      expect((await store.listAccounts()).length, 1);
      expect(second.displayName, '改名');
    });

    test('distinguishes auth failure from network failure', () async {
      final account = await seedAccount();

      await store.recordConnection(
        accountId: account.id,
        connected: false,
        errorCode: MailErrorCodes.authRequired,
        errorMessage: '凭据失效',
      );
      expect(
        (await store.accountById(account.id))!.connectionState,
        MailConnectionState.authRequired,
      );

      await store.recordConnection(
        accountId: account.id,
        connected: false,
        errorCode: MailErrorCodes.network,
        errorMessage: '网络不可达',
      );
      expect(
        (await store.accountById(account.id))!.connectionState,
        MailConnectionState.unreachable,
      );
    });

    test(
      'a failed reconnect keeps the last successful connection time',
      () async {
        final account = await seedAccount();
        await store.recordConnection(accountId: account.id, connected: true);
        final connectedAt = (await store.accountById(
          account.id,
        ))!.lastConnectedAtUtc;
        expect(connectedAt, isNotNull);

        clock = DateTime.utc(2026, 11, 13, 11);
        await store.recordConnection(
          accountId: account.id,
          connected: false,
          errorCode: MailErrorCodes.timeout,
          errorMessage: '超时',
        );

        final after = (await store.accountById(account.id))!;
        expect(after.lastConnectedAtUtc, connectedAt);
        expect(after.lastErrorCode, MailErrorCodes.timeout);
      },
    );

    test('accounts of another user are invisible', () async {
      await seedAccount();
      final other = MailStore(database, 'user-b', now: () => clock);

      expect(await other.listAccounts(), isEmpty);
      expect(await other.accountByAddress('dela@mails.jlu.edu.cn'), isNull);
      other.dispose();
    });
  });

  group('folders', () {
    test('a complete sync removes folders that disappeared', () async {
      final account = await seedAccount();
      await store.replaceFolders(account.id, const [
        MailFolderSnapshot(path: 'INBOX', name: '收件箱'),
        MailFolderSnapshot(path: 'Sent', name: '已发送'),
      ], complete: true);
      expect((await store.listFolders(account.id)).length, 2);

      await store.replaceFolders(account.id, const [
        MailFolderSnapshot(path: 'INBOX', name: '收件箱'),
      ], complete: true);

      final folders = await store.listFolders(account.id);
      expect(folders.map((f) => f.path), ['INBOX']);
    });

    test('a partial sync keeps folders it did not see', () async {
      final account = await seedAccount();
      await store.replaceFolders(account.id, const [
        MailFolderSnapshot(path: 'INBOX', name: '收件箱'),
        MailFolderSnapshot(path: 'Sent', name: '已发送'),
      ], complete: true);

      await store.replaceFolders(account.id, const [
        MailFolderSnapshot(path: 'Archive', name: '归档'),
      ], complete: false);

      final paths = (await store.listFolders(
        account.id,
      )).map((f) => f.path).toList();
      expect(paths, containsAll(['INBOX', 'Sent', 'Archive']));
    });
  });

  group('messages', () {
    test('summaries stay lightweight until the body is fetched', () async {
      final account = await seedAccount();
      final inbox = await seedInbox(account);

      final saved = await store.upsertSummary(
        MailMessageSummary(
          id: 'ignored',
          accountId: account.id,
          folderId: inbox.id,
          folderPath: inbox.path,
          uid: 42,
          messageId: '<abc@mails.jlu.edu.cn>',
          subject: '关于选课',
          sender: const MailAddress(name: '教务', address: 'jwc@jlu.edu.cn'),
          sentAtUtc: DateTime.utc(2026, 11, 12, 3),
          seen: false,
          flagged: false,
          hasAttachments: false,
          snippet: '请于本周内完成',
          size: 2048,
          observedAtUtc: clock,
        ),
      );

      expect(saved.uid, 42);
      final detail = (await store.messageById(saved.id))!;
      expect(detail.hasBody, isFalse);
      expect(detail.bodyText, isNull);
      expect(detail.subjectOrPlaceholder, '关于选课');
    });

    test('re-syncing the same uid updates instead of duplicating', () async {
      final account = await seedAccount();
      final inbox = await seedInbox(account);
      MailMessageSummary summary({required bool seen}) => MailMessageSummary(
        id: 'x',
        accountId: account.id,
        folderId: inbox.id,
        folderPath: inbox.path,
        uid: 7,
        subject: '同一封',
        sentAtUtc: DateTime.utc(2026, 11, 12, 3),
        seen: seen,
        flagged: false,
        hasAttachments: false,
        observedAtUtc: clock,
      );

      await store.upsertSummary(summary(seen: false));
      await store.upsertSummary(summary(seen: true));

      final messages = await store.listMessages(folderId: inbox.id);
      expect(messages.length, 1);
      expect(messages.single.seen, isTrue);
    });

    test('saving a body records addresses and attachments', () async {
      final account = await seedAccount();
      final inbox = await seedInbox(account);
      final saved = await store.upsertSummary(
        MailMessageSummary(
          id: 'x',
          accountId: account.id,
          folderId: inbox.id,
          folderPath: inbox.path,
          uid: 8,
          subject: '带附件',
          sentAtUtc: DateTime.utc(2026, 11, 12, 3),
          seen: false,
          flagged: false,
          hasAttachments: true,
          observedAtUtc: clock,
        ),
      );

      await store.saveBody(
        messageId: saved.id,
        bodyText: '正文',
        bodyHtml: '<p>正文</p>',
        to: const [MailAddress(name: '我', address: 'dela@mails.jlu.edu.cn')],
        attachments: const [
          MailAttachmentInfo(filename: '通知.pdf', bytes: 1024, part: '2'),
        ],
      );

      final detail = (await store.messageById(saved.id))!;
      expect(detail.hasBody, isTrue);
      expect(detail.bodyText, '正文');
      expect(detail.to.single.address, 'dela@mails.jlu.edu.cn');
      expect(detail.attachments.single.filename, '通知.pdf');
      expect(detail.hasAttachments, isTrue);
    });

    test('messages are isolated per user', () async {
      final account = await seedAccount();
      final inbox = await seedInbox(account);
      await store.upsertSummary(
        MailMessageSummary(
          id: 'x',
          accountId: account.id,
          folderId: inbox.id,
          folderPath: inbox.path,
          uid: 9,
          subject: '私有',
          sentAtUtc: DateTime.utc(2026, 11, 12, 3),
          seen: false,
          flagged: false,
          hasAttachments: false,
          observedAtUtc: clock,
        ),
      );

      final other = MailStore(database, 'user-b', now: () => clock);
      expect(await other.listMessages(folderId: inbox.id), isEmpty);
      other.dispose();
    });
  });

  group('drafts', () {
    test('a draft reopens with its content and attachment selection', () async {
      final account = await seedAccount();
      final draft = await store.createDraft(
        accountId: account.id,
        recipientText: 'jwc@jlu.edu.cn',
        subject: '请假申请',
        bodyText: '老师您好，我因故需要请假。',
        attachments: const [
          MailDraftAttachment(id: 'a1', name: '证明.pdf', bytes: 2048),
        ],
      );
      final saved = await store.saveDraft(draft);

      final reopened = (await store.draftById(saved.id))!;
      expect(reopened.subject, '请假申请');
      expect(reopened.bodyText, '老师您好，我因故需要请假。');
      expect(reopened.attachments.single.name, '证明.pdf');
      expect(reopened.sendState, MailSendState.editing);
      expect(reopened.canRetry, isTrue);
    });

    test('a failed send keeps the body and attachment selection', () async {
      final account = await seedAccount();
      final draft = await store.saveDraft(
        await store.createDraft(
          accountId: account.id,
          recipientText: 'jwc@jlu.edu.cn',
          subject: '成绩查询',
          bodyText: '请问成绩何时公布？',
          attachments: const [
            MailDraftAttachment(id: 'a1', name: '截图.png', bytes: 512),
          ],
        ),
      );

      await store.markSending(draft.id);
      expect(
        (await store.draftById(draft.id))!.sendState,
        MailSendState.sending,
      );

      await store.markSendFailed(
        draft.id,
        code: MailErrorCodes.network,
        message: '连接超时',
      );

      final failed = (await store.draftById(draft.id))!;
      expect(failed.sendState, MailSendState.failed);
      expect(failed.lastErrorCode, MailErrorCodes.network);
      expect(failed.lastErrorMessage, '连接超时');
      expect(failed.subject, '成绩查询');
      expect(failed.bodyText, '请问成绩何时公布？');
      expect(failed.attachments.single.name, '截图.png');
      expect(failed.canRetry, isTrue);
    });

    test('an interrupted send is recovered as retryable', () async {
      final account = await seedAccount();
      final draft = await store.saveDraft(
        await store.createDraft(accountId: account.id, subject: '中断'),
      );
      await store.markSending(draft.id);

      final recovered = await store.recoverInterruptedSends();

      expect(recovered, 1);
      final after = (await store.draftById(draft.id))!;
      expect(after.sendState, MailSendState.failed);
      expect(after.lastErrorMessage, contains('中断'));
      expect(after.canRetry, isTrue);
    });

    test('a sent draft is no longer offered for retry', () async {
      final account = await seedAccount();
      final draft = await store.saveDraft(
        await store.createDraft(accountId: account.id, subject: '已发送'),
      );

      await store.markSending(draft.id);
      await store.markSent(draft.id);

      final after = (await store.draftById(draft.id))!;
      expect(after.sendState, MailSendState.sent);
      expect(after.canRetry, isFalse);
    });

    test('drafts are isolated per user and per account', () async {
      final account = await seedAccount();
      await store.saveDraft(
        await store.createDraft(accountId: account.id, subject: '甲'),
      );

      final other = MailStore(database, 'user-b', now: () => clock);
      expect(await other.listDrafts(), isEmpty);
      other.dispose();

      expect(await store.listDrafts(accountId: 'missing'), isEmpty);
      expect((await store.listDrafts(accountId: account.id)).length, 1);
    });

    test('rejects an over-long subject', () async {
      final account = await seedAccount();
      final draft = await store.createDraft(
        accountId: account.id,
        subject: 'x' * (MailStore.maxSubjectLength + 1),
      );

      expect(
        () => store.saveDraft(draft),
        throwsA(
          isA<MailException>().having(
            (error) => error.code,
            'code',
            MailErrorCodes.draftTooLarge,
          ),
        ),
      );
    });

    test('an empty draft reports itself as empty', () async {
      final account = await seedAccount();
      final draft = await store.createDraft(accountId: account.id);
      expect(draft.isEmpty, isTrue);
    });
  });
}
