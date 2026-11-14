import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart' as enough;
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/features/mail/enough_mail_gateway.dart';
import 'package:jlu_dela/features/mail/mail_models.dart';

enough.Mailbox _mailbox(
  String name,
  List<enough.MailboxFlag> flags, {
  int? uidValidity,
  int exists = 0,
  int unseen = 0,
}) {
  return enough.Mailbox(
    encodedName: name,
    encodedPath: name,
    flags: flags,
    pathSeparator: '/',
    uidValidity: uidValidity,
    messagesExists: exists,
    messagesUnseen: unseen,
  );
}

String _encodedWord(String text) =>
    '=?UTF-8?B?${base64.encode(utf8.encode(text))}?=';

String _base64(String text) => base64.encode(utf8.encode(text));

String _mixedMessage() {
  final name = _encodedWord('作业设计.pdf');
  return [
    'From: ${_encodedWord('张三')} <zhangsan@mails.jlu.edu.cn>',
    'To: ${_encodedWord('李四')} <lisi@mails.jlu.edu.cn>',
    'Cc: wangwu@mails.jlu.edu.cn',
    'Subject: ${_encodedWord('你好，作业')}',
    'Date: Tue, 3 Jun 2025 10:00:00 +0800',
    'Message-ID: <abc123@mails.jlu.edu.cn>',
    'MIME-Version: 1.0',
    'Content-Type: multipart/mixed; boundary="MIX"',
    '',
    '--MIX',
    'Content-Type: text/plain; charset="utf-8"',
    'Content-Transfer-Encoding: base64',
    '',
    _base64('你好，作业'),
    '--MIX',
    'Content-Type: application/pdf; name="$name"',
    'Content-Disposition: attachment; filename="$name"',
    'Content-Transfer-Encoding: base64',
    '',
    _base64('附件内容'),
    '--MIX--',
    '',
  ].join('\r\n');
}

String _alternativeMessage() {
  return [
    'From: teacher@mails.jlu.edu.cn',
    'To: zhangsan@mails.jlu.edu.cn',
    'Subject: 课程通知',
    'Date: Wed, 4 Jun 2025 08:30:00 +0800',
    'MIME-Version: 1.0',
    'Content-Type: multipart/alternative; boundary="ALT"',
    '',
    '--ALT',
    'Content-Type: text/plain; charset="utf-8"',
    '',
    '本周五停课。',
    '--ALT',
    'Content-Type: text/html; charset="utf-8"',
    '',
    '<p>本周五停课。</p>',
    '--ALT--',
    '',
  ].join('\r\n');
}

void main() {
  group('folderSnapshotFrom', () {
    test('六种特殊用途映射成固定标记', () {
      final cases = <enough.MailboxFlag, String>{
        enough.MailboxFlag.inbox: 'inbox',
        enough.MailboxFlag.drafts: 'drafts',
        enough.MailboxFlag.sent: 'sent',
        enough.MailboxFlag.trash: 'trash',
        enough.MailboxFlag.junk: 'junk',
        enough.MailboxFlag.archive: 'archive',
      };
      for (final entry in cases.entries) {
        final snapshot = folderSnapshotFrom(_mailbox('文件夹', [entry.key]));
        expect(
          snapshot.specialUse,
          entry.value,
          reason: 'flag ${entry.key.name}',
        );
      }
      expect(folderSnapshotFrom(_mailbox('自定义', [])).specialUse, isNull);
    });

    test('uidValidity 从 int 转成 String，并带出总数与未读数', () {
      final snapshot = folderSnapshotFrom(
        _mailbox(
          'INBOX',
          [enough.MailboxFlag.inbox],
          uidValidity: 4294967295,
          exists: 128,
          unseen: 7,
        ),
      );
      expect(snapshot.path, 'INBOX');
      expect(snapshot.name, 'INBOX');
      expect(snapshot.uidValidity, '4294967295');
      expect(snapshot.total, 128);
      expect(snapshot.unread, 7);
    });

    test('跳过不可选中的文件夹', () {
      final snapshots = folderSnapshotsFrom([
        _mailbox('INBOX', [enough.MailboxFlag.inbox]),
        _mailbox('Archive', [enough.MailboxFlag.noSelect]),
        _mailbox('Sent', [enough.MailboxFlag.sent]),
      ]);
      expect(snapshots.map((snapshot) => snapshot.path), ['INBOX', 'Sent']);
    });
  });

  group('headerFrom', () {
    test('映射头部字段，日期归一到 UTC', () {
      final message = enough.MimeMessage.parseFromText(_mixedMessage())
        ..uid = 42
        ..size = 2048
        ..flags = [r'\Seen', r'\Flagged'];

      final header = headerFrom(message);
      expect(header.uid, 42);
      expect(header.messageId, '<abc123@mails.jlu.edu.cn>');
      expect(header.subject, '你好，作业');
      expect(
        header.sender,
        const MailAddress(name: '张三', address: 'zhangsan@mails.jlu.edu.cn'),
      );
      expect(header.sentAtUtc, DateTime.utc(2025, 6, 3, 2));
      expect(header.sentAtUtc!.isUtc, isTrue);
      expect(header.seen, isTrue);
      expect(header.flagged, isTrue);
      expect(header.hasAttachments, isTrue);
      expect(header.size, 2048);
      expect(header.snippet, isNull);
    });

    test('没有 UID 时报协议错误', () {
      final message = enough.MimeMessage.parseFromText(_alternativeMessage());
      expect(
        () => headerFrom(message),
        throwsA(
          isA<MailException>().having(
            (error) => error.code,
            'code',
            MailErrorCodes.protocol,
          ),
        ),
      );
    });
  });

  group('bodyFrom', () {
    test('取到纯文本正文与附件定位', () {
      final body = bodyFrom(enough.MimeMessage.parseFromText(_mixedMessage()));
      expect(body.bodyText, '你好，作业');
      expect(body.bodyHtml, isNull);
      expect(body.to.single.address, 'lisi@mails.jlu.edu.cn');
      expect(body.to.single.name, '李四');
      expect(body.cc.single.address, 'wangwu@mails.jlu.edu.cn');
      expect(body.attachments, hasLength(1));
      final attachment = body.attachments.single;
      expect(attachment.filename, '作业设计.pdf');
      expect(attachment.part, '2');
      expect(attachment.bytes, greaterThan(0));
    });

    test('multipart/alternative 同时给出纯文本与 HTML', () {
      final body = bodyFrom(
        enough.MimeMessage.parseFromText(_alternativeMessage()),
      );
      expect(body.bodyText, contains('本周五停课。'));
      expect(body.bodyHtml, contains('本周五停课。'));
      expect(body.attachments, isEmpty);
    });
  });

  group('mapMailError', () {
    test('连接与超时类异常', () {
      expect(
        mapMailError(const SocketException('connection refused')).code,
        MailErrorCodes.network,
      );
      expect(
        mapMailError(TimeoutException('slow')).code,
        MailErrorCodes.timeout,
      );
    });

    test('服务端认证失败文案映射成 authRequired', () {
      final imap = enough.ImapClient();
      expect(
        mapMailError(
          enough.ImapException(imap, 'NO AUTHENTICATIONFAILED bad password'),
        ).code,
        MailErrorCodes.authRequired,
      );
      expect(
        mapMailError(enough.ImapException(imap, 'NO such mailbox')).code,
        MailErrorCodes.protocol,
      );
      final smtp = enough.SmtpClient('jlu-dela.local');
      expect(
        mapMailError(
          enough.SmtpException(
            smtp,
            enough.SmtpResponse(['535 5.7.8 Authentication failed']),
          ),
        ).code,
        MailErrorCodes.authRequired,
      );
    });

    test('已映射的异常原样返回', () {
      const original = MailException(MailErrorCodes.sendRejected, '拒绝');
      expect(identical(mapMailError(original), original), isTrue);
    });
  });
}
