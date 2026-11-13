import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/features/mail/mail_credential_store.dart';
import 'package:jlu_dela/features/mail/mail_gateway.dart';
import 'package:jlu_dela/features/mail/mail_models.dart';
import 'package:jlu_dela/features/mail/mail_store.dart';
import 'package:jlu_dela/features/mail/mail_sync.dart';

import 'support/local_database_test_support.dart';

class _MemorySecretStore implements MailSecretStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String userId, String accountId) async {
    _values.remove('$userId/$accountId');
  }

  @override
  Future<String?> read(String userId, String accountId) async =>
      _values['$userId/$accountId'];

  @override
  Future<void> write(String userId, String accountId, String secret) async {
    _values['$userId/$accountId'] = secret;
  }
}

class _MemoryAttachments implements MailAttachmentSource {
  _MemoryAttachments(this.files);

  final Map<String, Uint8List> files;

  @override
  Future<Uint8List?> read(String attachmentId) async => files[attachmentId];
}

class _FakeGateway implements MailGateway {
  _FakeGateway({
    this.headers = const [],
    this.uidValidity = '1',
    this.body,
    this.connectError,
    this.headerError,
    this.bodyError,
    this.sendError,
    this.appendFails = false,
  });

  final List<MailHeader> headers;

  /// 可变：模拟服务端重建 UID 空间。
  String uidValidity;
  final MailBody? body;
  final MailException? connectError;
  final MailException? headerError;
  final MailException? bodyError;
  final MailException? sendError;
  final bool appendFails;

  int connectCount = 0;
  int disconnectCount = 0;
  int appendCount = 0;
  String? lastSinceUidFolder;
  int? lastSinceUid;
  MailOutgoing? lastOutgoing;
  String? lastBodyFolder;
  int? lastBodyUid;
  String? lastAttachmentFolder;
  int? lastAttachmentUid;

  @override
  Future<void> connect() async {
    connectCount++;
    if (connectError != null) {
      throw connectError!;
    }
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
  }

  @override
  Future<List<MailFolderSnapshot>> listFolders() async => const [
    MailFolderSnapshot(
      path: 'INBOX',
      name: '收件箱',
      specialUse: r'\Inbox',
      uidValidity: '1',
    ),
    MailFolderSnapshot(path: 'Sent', name: '已发送', specialUse: r'\Sent'),
  ];

  @override
  Future<MailHeaderBatch> fetchHeaders({
    required String folderPath,
    required int sinceUid,
    required int limit,
  }) async {
    lastSinceUidFolder = folderPath;
    lastSinceUid = sinceUid;
    if (headerError != null) {
      throw headerError!;
    }
    return MailHeaderBatch(
      headers: headers.where((h) => h.uid > sinceUid).take(limit).toList(),
      uidValidity: uidValidity,
      highestUid: headers.isEmpty
          ? 0
          : headers.map((h) => h.uid).reduce((a, b) => a > b ? a : b),
    );
  }

  @override
  Future<MailBody> fetchBody({
    required String folderPath,
    required int uid,
  }) async {
    lastBodyFolder = folderPath;
    lastBodyUid = uid;
    if (bodyError != null) {
      throw bodyError!;
    }
    return body ?? const MailBody();
  }

  @override
  Future<Uint8List> fetchAttachment({
    required String folderPath,
    required int uid,
    required String part,
  }) async {
    lastAttachmentFolder = folderPath;
    lastAttachmentUid = uid;
    return Uint8List(0);
  }

  @override
  Future<MailSendReceipt> send(MailOutgoing message) async {
    if (sendError != null) {
      throw sendError!;
    }
    lastOutgoing = message;
    return const MailSendReceipt(messageId: '<sent@jlu.edu.cn>');
  }

  @override
  Future<void> appendToSent({
    required String folderPath,
    required MailOutgoing message,
  }) async {
    appendCount++;
    if (appendFails) {
      throw const MailException(MailErrorCodes.protocol, '追加已发送失败');
    }
  }
}

class _FakeFactory implements MailGatewayFactory {
  _FakeFactory(this.gateway);

  final MailGateway gateway;
  String? lastSecret;
  MailAccount? lastAccount;

  @override
  MailGateway create({required MailAccount account, required String secret}) {
    lastAccount = account;
    lastSecret = secret;
    return gateway;
  }
}

void main() {
  late LocalDatabase database;
  late MailStore store;
  late MailAccount account;
  late _MemorySecretStore secrets;
  late DateTime clock;

  setUp(() async {
    database = await openTestDatabase();
    clock = DateTime.utc(2026, 11, 13, 10);
    store = MailStore(database, 'user-a', now: () => clock);
    secrets = _MemorySecretStore();
    account = await store.upsertAccount(address: 'dela@mails.jlu.edu.cn');
  });

  tearDown(() async {
    store.dispose();
    await database.close();
  });

  MailSyncService serviceFor(
    MailGateway gateway, {
    MailAttachmentSource? attachments,
  }) {
    return MailSyncService(
      store: store,
      credentials: secrets,
      gatewayFactory: _FakeFactory(gateway),
      attachments: attachments ?? _MemoryAttachments(const {}),
      now: () => clock,
    );
  }

  group('connect', () {
    test(
      'without a saved secret it reports auth required, not a crash',
      () async {
        final gateway = _FakeGateway();
        final service = serviceFor(gateway);

        final outcome = await service.connect(account);

        expect(outcome.isSuccess, isFalse);
        expect(outcome.state, MailConnectionState.authRequired);
        expect(outcome.errorCode, MailErrorCodes.authRequired);
        expect(gateway.connectCount, 0);
        expect(
          (await store.accountById(account.id))!.connectionState,
          MailConnectionState.authRequired,
        );
      },
    );

    test(
      'a wrong password surfaces as auth required and keeps the account',
      () async {
        await secrets.write('user-a', account.id, 'wrong');
        final gateway = _FakeGateway(
          connectError: const MailException(
            MailErrorCodes.authRequired,
            '认证失败',
          ),
        );
        final service = serviceFor(gateway);

        final outcome = await service.connect(account);

        expect(outcome.state, MailConnectionState.authRequired);
        expect(await store.accountById(account.id), isNotNull);
        expect(
          (await store.accountById(account.id))!.lastErrorCode,
          MailErrorCodes.authRequired,
        );
      },
    );

    test('a network failure is reported as unreachable', () async {
      await secrets.write('user-a', account.id, 'secret');
      final gateway = _FakeGateway(
        connectError: const MailException(MailErrorCodes.network, '连不上'),
      );
      final service = serviceFor(gateway);

      final outcome = await service.connect(account);

      expect(outcome.state, MailConnectionState.unreachable);
      expect(outcome.errorCode, MailErrorCodes.network);
    });

    test('saving the secret connects immediately', () async {
      final gateway = _FakeGateway();
      final service = serviceFor(gateway);

      final outcome = await service.saveSecret(account, 'auth-code');

      expect(outcome.isSuccess, isTrue);
      expect(await secrets.read('user-a', account.id), 'auth-code');
      expect(gateway.connectCount, 1);
      expect(
        (await store.accountById(account.id))!.connectionState,
        MailConnectionState.connected,
      );
    });
  });

  group('folders and headers', () {
    Future<MailSyncService> connected(_FakeGateway gateway) async {
      await secrets.write('user-a', account.id, 'secret');
      final service = serviceFor(gateway);
      await service.connect(account);
      return service;
    }

    test('folders are stored and then messages arrive', () async {
      final gateway = _FakeGateway(
        headers: [
          MailHeader(
            uid: 10,
            subject: '关于选课',
            sender: const MailAddress(name: '教务', address: 'jwc@jlu.edu.cn'),
            sentAtUtc: DateTime.utc(2026, 11, 12, 3),
          ),
          MailHeader(uid: 11, subject: '第二条'),
        ],
      );
      final service = await connected(gateway);

      final folders = await service.syncFolders(account);
      expect(folders.isSuccess, isTrue);
      expect(folders.foldersSynced, 2);

      final result = await service.syncHeaders(
        account,
        folderPath: 'INBOX',
        sinceUid: 0,
      );

      expect(result.isSuccess, isTrue);
      expect(result.messagesSynced, 2);
      final inbox = (await store.folderByPath(account.id, 'INBOX'))!;
      final messages = await store.listMessages(folderId: inbox.id);
      expect(messages.length, 2);
      expect(messages.first.subject, '关于选课');
    });

    test('incremental sync starts from the highest cached uid', () async {
      final gateway = _FakeGateway(
        headers: [MailHeader(uid: 5), MailHeader(uid: 9)],
      );
      final service = await connected(gateway);
      await service.syncFolders(account);
      await service.syncHeaders(account, folderPath: 'INBOX');

      final inbox = (await store.folderByPath(account.id, 'INBOX'))!;
      expect(await store.highestUid(inbox.id), 9);

      await service.syncHeaders(account, folderPath: 'INBOX', sinceUid: 9);

      expect(gateway.lastSinceUid, 9);
      expect(gateway.lastSinceUidFolder, 'INBOX');
    });

    test(
      'a changed uidvalidity drops the stale cache instead of mixing uids',
      () async {
        final first = _FakeGateway(
          headers: [MailHeader(uid: 100, subject: '旧')],
        );
        await secrets.write('user-a', account.id, 'secret');
        final service = serviceFor(first);
        await service.connect(account);
        await service.syncFolders(account);
        await service.syncHeaders(account, folderPath: 'INBOX');

        final inbox = (await store.folderByPath(account.id, 'INBOX'))!;
        expect(await store.highestUid(inbox.id), 100);

        // 服务端重建 UID 空间：同一个 uid 100 现在是另一封邮件。
        final second = _FakeGateway(
          headers: [MailHeader(uid: 100, subject: '新')],
          uidValidity: '2',
        );
        final reopened = serviceFor(second);
        await reopened.connect(account);
        await reopened.syncFolders(account);
        await reopened.syncHeaders(account, folderPath: 'INBOX');

        final messages = await store.listMessages(folderId: inbox.id);
        expect(messages.length, 1);
        expect(messages.single.subject, '新');
      },
    );

    test('syncing a folder that was never listed says so', () async {
      final gateway = _FakeGateway();
      final service = await connected(gateway);

      final result = await service.syncHeaders(account, folderPath: 'INBOX');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('文件夹'));
    });

    test('a header failure keeps the cached messages', () async {
      final gateway = _FakeGateway(
        headers: [MailHeader(uid: 1, subject: '已有')],
      );
      final service = await connected(gateway);
      await service.syncFolders(account);
      await service.syncHeaders(account, folderPath: 'INBOX');

      final failing = _FakeGateway(
        headerError: const MailException(MailErrorCodes.timeout, '超时'),
      );
      await secrets.write('user-a', account.id, 'secret');
      final second = serviceFor(failing);
      await second.connect(account);
      final result = await second.syncHeaders(account, folderPath: 'INBOX');

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, MailErrorCodes.timeout);
      final inbox = (await store.folderByPath(account.id, 'INBOX'))!;
      expect(await store.listMessages(folderId: inbox.id), hasLength(1));
    });
  });

  group('reading a message', () {
    Future<(MailSyncService, MailMessageDetail)> openWith(
      _FakeGateway gateway,
    ) async {
      await secrets.write('user-a', account.id, 'secret');
      final service = serviceFor(gateway);
      await service.connect(account);
      await service.syncFolders(account);
      await service.syncHeaders(account, folderPath: 'INBOX');
      final inbox = (await store.folderByPath(account.id, 'INBOX'))!;
      final summary = (await store.listMessages(folderId: inbox.id)).single;
      final detail = (await store.messageById(summary.id))!;
      return (service, detail);
    }

    test('opening a message fetches and caches the body once', () async {
      final gateway = _FakeGateway(
        headers: [MailHeader(uid: 3, subject: '正文测试')],
        body: const MailBody(
          bodyText: '正文内容',
          to: [MailAddress(address: 'dela@mails.jlu.edu.cn')],
          attachments: [MailAttachmentInfo(filename: 'a.pdf', part: '2')],
        ),
      );
      final (service, summary) = await openWith(gateway);

      final opened = await service.openMessage(summary);

      expect(opened.hasBody, isTrue);
      expect(opened.bodyText, '正文内容');
      expect(opened.attachments.single.filename, 'a.pdf');

      // 第二次直接命中缓存，不再发请求。
      final again = await service.openMessage(opened);
      expect(again.bodyText, '正文内容');
    });

    test('a body failure leaves the summary readable', () async {
      final gateway = _FakeGateway(
        headers: [MailHeader(uid: 4, subject: '正文失败')],
        bodyError: const MailException(MailErrorCodes.network, '断网'),
      );
      final (service, summary) = await openWith(gateway);

      await expectLater(
        service.openMessage(summary),
        throwsA(
          isA<MailException>().having(
            (error) => error.code,
            'code',
            MailErrorCodes.network,
          ),
        ),
      );

      final still = (await store.messageById(summary.id))!;
      expect(still.subject, '正文失败');
      expect(still.hasBody, isFalse);
    });

    test(
      'a missing attachment reports an error instead of empty bytes',
      () async {
        final gateway = _FakeGateway(
          headers: [MailHeader(uid: 5, subject: '附件')],
          body: const MailBody(
            bodyText: '见附件',
            attachments: [MailAttachmentInfo(filename: 'a.pdf', part: '2')],
          ),
        );
        final (service, summary) = await openWith(gateway);
        final opened = await service.openMessage(summary);

        await expectLater(
          service.downloadAttachment(
            message: opened,
            attachment: opened.attachments.single,
          ),
          throwsA(
            isA<MailException>().having(
              (error) => error.code,
              'code',
              MailErrorCodes.attachmentMissing,
            ),
          ),
        );
      },
    );

    test('an attachment without a part reference is reported', () async {
      final gateway = _FakeGateway(
        headers: [MailHeader(uid: 6)],
        body: const MailBody(
          bodyText: 'x',
          attachments: [MailAttachmentInfo(filename: 'b.pdf')],
        ),
      );
      final (service, summary) = await openWith(gateway);
      final opened = await service.openMessage(summary);

      await expectLater(
        service.downloadAttachment(
          message: opened,
          attachment: opened.attachments.single,
        ),
        throwsA(
          isA<MailException>().having(
            (error) => error.code,
            'code',
            MailErrorCodes.attachmentMissing,
          ),
        ),
      );
    });
  });

  group('sending', () {
    Future<(MailSyncService, MailDraft)> draftWith(
      _FakeGateway gateway, {
      MailAttachmentSource? attachments,
      String recipientText = 'jwc@jlu.edu.cn',
      List<MailDraftAttachment> files = const [],
    }) async {
      await secrets.write('user-a', account.id, 'secret');
      final service = serviceFor(gateway, attachments: attachments);
      await service.connect(account);
      final draft = await store.saveDraft(
        await store.createDraft(
          accountId: account.id,
          recipientText: recipientText,
          subject: '请假',
          bodyText: '老师您好',
          attachments: files,
        ),
      );
      return (service, draft);
    }

    test('a successful send marks the draft sent', () async {
      final gateway = _FakeGateway();
      final (service, draft) = await draftWith(gateway);

      final outcome = await service.sendDraft(draft);

      expect(outcome.isSent, isTrue);
      expect((await store.draftById(draft.id))!.sendState, MailSendState.sent);
      expect(gateway.lastOutgoing!.to, ['jwc@jlu.edu.cn']);
      expect(gateway.lastOutgoing!.subject, '请假');
    });

    test('a failed send keeps the body and attachment selection', () async {
      final gateway = _FakeGateway(
        sendError: const MailException(MailErrorCodes.network, '连接超时'),
      );
      final (service, draft) = await draftWith(
        gateway,
        attachments: _MemoryAttachments({
          'a1': Uint8List.fromList([1, 2, 3]),
        }),
        files: const [MailDraftAttachment(id: 'a1', name: '证明.pdf', bytes: 3)],
      );

      final outcome = await service.sendDraft(draft);

      expect(outcome.isSent, isFalse);
      expect(outcome.code, MailErrorCodes.network);
      final failed = (await store.draftById(draft.id))!;
      expect(failed.sendState, MailSendState.failed);
      expect(failed.bodyText, '老师您好');
      expect(failed.attachments.single.name, '证明.pdf');
      expect(failed.canRetry, isTrue);
    });

    test('a vanished attachment blocks the send before SMTP', () async {
      final gateway = _FakeGateway();
      final (service, draft) = await draftWith(
        gateway,
        attachments: _MemoryAttachments(const {}),
        files: const [MailDraftAttachment(id: 'gone', name: '没了.pdf')],
      );

      final outcome = await service.sendDraft(draft);

      expect(outcome.isSent, isFalse);
      expect(outcome.code, MailErrorCodes.attachmentMissing);
      expect(gateway.lastOutgoing, isNull);
      expect(
        (await store.draftById(draft.id))!.attachments.single.name,
        '没了.pdf',
      );
    });

    test(
      'an empty recipient list is rejected without pretending to send',
      () async {
        final gateway = _FakeGateway();
        final (service, draft) = await draftWith(gateway, recipientText: '   ');

        final outcome = await service.sendDraft(draft);

        expect(outcome.isSent, isFalse);
        expect(outcome.code, MailErrorCodes.sendRejected);
        expect(gateway.lastOutgoing, isNull);
        expect(
          (await store.draftById(draft.id))!.sendState,
          MailSendState.failed,
        );
      },
    );

    test('a failing sent-folder append does not fail the send', () async {
      final gateway = _FakeGateway(appendFails: true);
      final (service, draft) = await draftWith(gateway);

      final outcome = await service.sendDraft(draft);

      expect(outcome.isSent, isTrue);
      expect(gateway.appendCount, 1);
      expect((await store.draftById(draft.id))!.sendState, MailSendState.sent);
    });
  });

  group('recipient parsing', () {
    test('handles separators, display names and invalid entries', () {
      expect(
        MailSyncService.parseRecipients(
          'a@jlu.edu.cn; 张三 <b@jlu.edu.cn>\n c@jlu.edu.cn, 不是邮箱',
        ),
        ['a@jlu.edu.cn', 'b@jlu.edu.cn', 'c@jlu.edu.cn'],
      );
    });

    test('an empty string yields no recipients', () {
      expect(MailSyncService.parseRecipients('  '), isEmpty);
    });
  });

  test('recovering interrupted sends is exposed through the service', () async {
    final gateway = _FakeGateway();
    await secrets.write('user-a', account.id, 'secret');
    final service = serviceFor(gateway);
    final draft = await store.saveDraft(
      await store.createDraft(accountId: account.id, subject: '中断'),
    );
    await store.markSending(draft.id);

    expect(await service.recoverInterruptedSends(), 1);
    expect((await store.draftById(draft.id))!.canRetry, isTrue);
  });

  group('account binding', () {
    Future<MailAccount> secondAccount() =>
        store.upsertAccount(address: 'other@mails.jlu.edu.cn');

    test('reading a message of another account is refused', () async {
      final other = await secondAccount();
      final gatewayA = _FakeGateway(
        headers: [MailHeader(uid: 1, subject: 'A 的邮件')],
        body: const MailBody(bodyText: 'A 的正文'),
      );
      await secrets.write('user-a', account.id, 'secret');
      await secrets.write('user-a', other.id, 'secret');
      final serviceA = serviceFor(gatewayA);
      await serviceA.connect(account);
      await serviceA.syncFolders(account);
      await serviceA.syncHeaders(account, folderPath: 'INBOX');
      final inboxA = (await store.folderByPath(account.id, 'INBOX'))!;
      final messageA = (await store.listMessages(folderId: inboxA.id)).single;
      final detailA = (await store.messageById(messageA.id))!;

      // 切到 B 的连接，再打开 A 的邮件。
      final gatewayB = _FakeGateway(
        headers: [MailHeader(uid: 1, subject: 'B 的邮件')],
        body: const MailBody(bodyText: 'B 的正文'),
      );
      final serviceB = serviceFor(gatewayB);
      await serviceB.connect(other);

      await expectLater(
        serviceB.openMessage(detailA),
        throwsA(
          isA<MailException>().having(
            (error) => error.code,
            'code',
            MailErrorCodes.wrongAccount,
          ),
        ),
      );
      expect(gatewayB.lastBodyUid, isNull);
      final untouched = (await store.messageById(detailA.id))!;
      expect(untouched.hasBody, isFalse);
      expect(untouched.bodyText, isNull);
    });

    test('downloading an attachment of another account is refused', () async {
      final other = await secondAccount();
      final gatewayA = _FakeGateway(
        headers: [MailHeader(uid: 2, subject: 'A 的附件')],
        body: const MailBody(
          bodyText: '见附件',
          attachments: [MailAttachmentInfo(filename: 'a.pdf', part: '2')],
        ),
      );
      await secrets.write('user-a', account.id, 'secret');
      await secrets.write('user-a', other.id, 'secret');
      final serviceA = serviceFor(gatewayA);
      await serviceA.connect(account);
      await serviceA.syncFolders(account);
      await serviceA.syncHeaders(account, folderPath: 'INBOX');
      final inboxA = (await store.folderByPath(account.id, 'INBOX'))!;
      final summary = (await store.listMessages(folderId: inboxA.id)).single;
      final opened = await serviceA.openMessage(
        (await store.messageById(summary.id))!,
      );

      final gatewayB = _FakeGateway();
      final serviceB = serviceFor(gatewayB);
      await serviceB.connect(other);

      await expectLater(
        serviceB.downloadAttachment(
          message: opened,
          attachment: opened.attachments.single,
        ),
        throwsA(
          isA<MailException>().having(
            (error) => error.code,
            'code',
            MailErrorCodes.wrongAccount,
          ),
        ),
      );
      expect(gatewayB.lastAttachmentUid, isNull);
    });

    test('sending a draft of another account is refused and kept', () async {
      final other = await secondAccount();
      final gatewayA = _FakeGateway();
      await secrets.write('user-a', account.id, 'secret');
      await secrets.write('user-a', other.id, 'secret');
      final serviceA = serviceFor(gatewayA);
      await serviceA.connect(account);
      final draftA = await store.saveDraft(
        await store.createDraft(
          accountId: account.id,
          recipientText: 'jwc@jlu.edu.cn',
          subject: 'A 的私人草稿',
          bodyText: '只有 A 该看到的内容',
        ),
      );

      final gatewayB = _FakeGateway();
      final serviceB = serviceFor(gatewayB);
      await serviceB.connect(other);
      final outcome = await serviceB.sendDraft(draftA);

      expect(outcome.isSent, isFalse);
      expect(outcome.code, MailErrorCodes.wrongAccount);
      expect(gatewayB.lastOutgoing, isNull);
      final kept = (await store.draftById(draftA.id))!;
      expect(kept.sendState, MailSendState.failed);
      expect(kept.bodyText, '只有 A 该看到的内容');
      expect(kept.canRetry, isTrue);
    });

    test('the owning account still reads its own message', () async {
      final gatewayA = _FakeGateway(
        headers: [MailHeader(uid: 3, subject: '自己的')],
        body: const MailBody(bodyText: '自己的正文'),
      );
      await secrets.write('user-a', account.id, 'secret');
      final service = serviceFor(gatewayA);
      await service.connect(account);
      await service.syncFolders(account);
      await service.syncHeaders(account, folderPath: 'INBOX');
      final inbox = (await store.folderByPath(account.id, 'INBOX'))!;
      final summary = (await store.listMessages(folderId: inbox.id)).single;

      final opened = await service.openMessage(
        (await store.messageById(summary.id))!,
      );

      expect(opened.bodyText, '自己的正文');
      expect(gatewayA.lastBodyUid, 3);
    });
  });

  group('uidvalidity handling', () {
    Future<String> syncOnce(_FakeGateway gateway) async {
      await secrets.write('user-a', account.id, 'secret');
      final service = serviceFor(gateway);
      await service.connect(account);
      await service.syncFolders(account);
      await service.syncHeaders(account, folderPath: 'INBOX');
      final inbox = (await store.folderByPath(account.id, 'INBOX'))!;
      return inbox.id;
    }

    test(
      'a reset refetches from zero instead of reusing the old watermark',
      () async {
        final first = _FakeGateway(
          headers: [MailHeader(uid: 100, subject: '旧')],
        );
        final inboxId = await syncOnce(first);
        expect(await store.highestUid(inboxId), 100);

        // 服务端重建 UID 空间：新邮件 uid 从 1 开始。
        final second = _FakeGateway(
          headers: [MailHeader(uid: 1, subject: '新')],
          uidValidity: '2',
        );
        await secrets.write('user-a', account.id, 'secret');
        final reopened = serviceFor(second);
        await reopened.connect(account);
        final result = await reopened.syncHeaders(
          account,
          folderPath: 'INBOX',
          sinceUid: 100,
        );

        expect(result.isSuccess, isTrue);
        // 发现 UIDVALIDITY 变化后必须从 0 重拉，否则 uid=1 会被旧水位挡掉。
        expect(second.lastSinceUid, 0);
        final messages = await store.listMessages(folderId: inboxId);
        expect(messages.length, 1);
        expect(messages.single.subject, '新');
        expect(messages.single.uid, 1);
      },
    );

    test(
      'a reset records the new uidvalidity so the next sync is stable',
      () async {
        final first = _FakeGateway(headers: [MailHeader(uid: 50)]);
        final inboxId = await syncOnce(first);

        final second = _FakeGateway(
          headers: [MailHeader(uid: 1)],
          uidValidity: '2',
        );
        await secrets.write('user-a', account.id, 'secret');
        final service = serviceFor(second);
        await service.connect(account);
        await service.syncHeaders(account, folderPath: 'INBOX', sinceUid: 50);

        final folder = (await store.listFolders(
          account.id,
        )).firstWhere((f) => f.id == inboxId);
        expect(folder.uidValidity, '2');

        // 第二次同步：UIDVALIDITY 已相同，不该再清缓存、也不该回退到 0。
        final third = _FakeGateway(
          headers: [MailHeader(uid: 2, subject: '后续')],
          uidValidity: '2',
        );
        await secrets.write('user-a', account.id, 'secret');
        final again = serviceFor(third);
        await again.connect(account);
        await again.syncHeaders(account, folderPath: 'INBOX', sinceUid: 1);

        expect(third.lastSinceUid, 1);
        final messages = await store.listMessages(folderId: inboxId);
        expect(messages.length, 2);
      },
    );

    test(
      'a folder snapshot that changes uidvalidity drops stale bodies',
      () async {
        final first = _FakeGateway(
          headers: [MailHeader(uid: 7, subject: '旧标题')],
          body: const MailBody(bodyText: '上一 UID 空间的正文'),
        );
        await secrets.write('user-a', account.id, 'secret');
        final service = serviceFor(first);
        await service.connect(account);
        await service.syncFolders(account);
        await service.syncHeaders(account, folderPath: 'INBOX');
        final inbox = (await store.folderByPath(account.id, 'INBOX'))!;
        final oldSummary = (await store.listMessages(
          folderId: inbox.id,
        )).single;
        await service.openMessage((await store.messageById(oldSummary.id))!);
        expect(
          (await store.messageById(oldSummary.id))!.bodyText,
          '上一 UID 空间的正文',
        );

        // 文件夹同步先看到新的 UIDVALIDITY —— 此时旧缓存必须立刻失效，
        // 否则紧接着的头部同步会认为两边一致，把新摘要盖在旧正文上。
        await store.replaceFolders(account.id, const [
          MailFolderSnapshot(path: 'INBOX', name: '收件箱', uidValidity: '2'),
        ], complete: false);
        expect(await store.listMessages(folderId: inbox.id), isEmpty);

        final second = _FakeGateway(
          headers: [MailHeader(uid: 7, subject: '新标题')],
          uidValidity: '2',
          body: const MailBody(bodyText: '新 UID 空间的正文'),
        );
        await secrets.write('user-a', account.id, 'secret');
        final reopened = serviceFor(second);
        await reopened.connect(account);
        // 调用方按契约重新读取本地水位：缓存刚被清空，此时应为 0。
        final watermark = await store.highestUid(inbox.id);
        expect(watermark, 0);
        await reopened.syncHeaders(
          account,
          folderPath: 'INBOX',
          sinceUid: watermark,
        );
        final fresh = (await store.listMessages(folderId: inbox.id)).single;
        final detail = (await store.messageById(fresh.id))!;

        expect(detail.subject, '新标题');
        expect(detail.hasBody, isFalse);
        expect(detail.bodyText, isNull);
      },
    );

    test('an empty complete snapshot removes every folder', () async {
      await secrets.write('user-a', account.id, 'secret');
      final service = serviceFor(_FakeGateway());
      await service.connect(account);
      await service.syncFolders(account);
      expect(await store.listFolders(account.id), isNotEmpty);

      await store.replaceFolders(account.id, const [], complete: true);

      expect(await store.listFolders(account.id), isEmpty);
    });
  });
}
