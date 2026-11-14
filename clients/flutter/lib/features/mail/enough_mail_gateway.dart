import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart' as enough;
import 'package:flutter/foundation.dart';

import 'mail_gateway.dart';
import 'mail_models.dart';

/// 创建直连 IMAP/SMTP 的网关。
class EnoughMailGatewayFactory implements MailGatewayFactory {
  const EnoughMailGatewayFactory();

  @override
  MailGateway create({required MailAccount account, required String secret}) =>
      EnoughMailGateway(account: account, secret: secret);
}

/// 用 IMAP/SMTP 直连邮箱服务商的网关。
///
/// IMAP 在 [connect] 时建立；SMTP 只在真正发信时连接，列表页不为发信付代价。
/// 凭据只保存在本对象的字段里，不写入任何持久化位置，也不进异常消息。
class EnoughMailGateway implements MailGateway {
  EnoughMailGateway({required MailAccount account, required String secret})
    : this._(account, secret);

  EnoughMailGateway._(this._account, this._secret);

  static const Duration _responseTimeout = Duration(seconds: 30);
  static const String _smtpClientDomain = 'jlu-dela.local';

  /// 列表页只要信封与头部，正文一律不同步下载。
  static const String _headerFetchDefinition =
      '(UID FLAGS RFC822.SIZE ENVELOPE BODY.PEEK[HEADER.FIELDS '
      '(MESSAGE-ID FROM TO CC SUBJECT DATE CONTENT-TYPE)] BODYSTRUCTURE)';

  final MailAccount _account;
  final String _secret;

  enough.ImapClient? _imap;
  enough.SmtpClient? _smtp;

  @override
  Future<void> connect() async {
    if (_imap?.isLoggedIn ?? false) {
      return;
    }
    final imap = enough.ImapClient(defaultResponseTimeout: _responseTimeout);
    _imap = imap;
    try {
      await imap
          .connectToServer(
            _account.server.imapHost,
            _account.server.imapPort,
            isSecure: true,
          )
          .timeout(_responseTimeout);
      await imap.login(_account.address, _secret).timeout(_responseTimeout);
    } catch (error) {
      _imap = null;
      await _closeImapQuietly(imap);
      throw _mapError(error);
    }
  }

  @override
  Future<void> disconnect() async {
    final imap = _imap;
    final smtp = _smtp;
    _imap = null;
    _smtp = null;
    if (smtp != null) {
      try {
        await smtp.quit();
      } catch (_) {
        // 连接可能已经断了，退出失败不影响调用方。
      }
    }
    if (imap != null) {
      try {
        await imap.logout();
      } catch (_) {
        // LOGOUT 失败时下面直接断开底层连接。
      }
      await _closeImapQuietly(imap);
    }
  }

  @override
  Future<List<MailFolderSnapshot>> listFolders() async {
    final imap = _requireImap();
    try {
      final mailboxes = await imap.listMailboxes(recursive: true);
      final snapshots = <MailFolderSnapshot>[];
      for (final mailbox in mailboxes) {
        if (mailbox.isNotSelectable) {
          continue;
        }
        // LIST 只回名字与 \Noselect 之类的标志，UIDVALIDITY 与邮件数是 STATUS
        // 才有的：不补这一步，快照里的 uidValidity 永远是 null、总数永远是 0。
        var withStatus = mailbox;
        try {
          withStatus = await imap.statusMailbox(mailbox, const [
            enough.StatusFlags.messages,
            enough.StatusFlags.uidValidity,
            enough.StatusFlags.unseen,
          ]);
        } catch (_) {
          // 单个文件夹查不到状态不该让整份目录失败，保留 LIST 已有字段。
        }
        snapshots.add(folderSnapshotFrom(withStatus));
      }
      return snapshots;
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<MailHeaderBatch> fetchHeaders({
    required String folderPath,
    required int sinceUid,
    required int limit,
  }) async {
    final imap = _requireImap();
    try {
      final mailbox = await imap.selectMailboxByPath(folderPath);
      // UID 不连续，按 sinceUid + limit 算上界会漏信：拉到最后一封再自己截断。
      final result = await imap.fetchMessages(
        enough.MessageSequence.fromRangeToLast(
          sinceUid < 0 ? 1 : sinceUid + 1,
          isUidSequence: true,
        ),
        _headerFetchDefinition,
      );
      // 区间为空时服务端仍会返回最后一封，必须按 UID 过滤。
      final messages =
          result.messages
              .where(
                (message) => message.uid != null && message.uid! > sinceUid,
              )
              .toList()
            ..sort((a, b) => a.uid!.compareTo(b.uid!));
      final headers = messages.take(limit).map(headerFrom).toList();
      return MailHeaderBatch(
        headers: headers,
        uidValidity: mailbox.uidValidity?.toString(),
        highestUid: headers.isEmpty ? 0 : headers.last.uid,
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<MailBody> fetchBody({
    required String folderPath,
    required int uid,
  }) async {
    final imap = _requireImap();
    try {
      await imap.selectMailboxByPath(folderPath);
      final result = await imap.fetchMessages(
        enough.MessageSequence.fromId(uid, isUid: true),
        '(UID FLAGS BODY.PEEK[])',
      );
      final message = _messageWithUid(result.messages, uid);
      if (message == null) {
        throw const MailException(MailErrorCodes.protocol, '服务端没有该邮件');
      }
      return bodyFrom(message);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<Uint8List> fetchAttachment({
    required String folderPath,
    required int uid,
    required String part,
  }) async {
    final imap = _requireImap();
    try {
      await imap.selectMailboxByPath(folderPath);
      // 整封下载后再按 part 取段：最省心也最可靠，后续可优化成
      // BODY.PEEK[<section>] 只取该段。
      final result = await imap.fetchMessages(
        enough.MessageSequence.fromId(uid, isUid: true),
        '(UID FLAGS BODY.PEEK[])',
      );
      final message = _messageWithUid(result.messages, uid);
      if (message == null) {
        throw const MailException(MailErrorCodes.protocol, '服务端没有该邮件');
      }
      final bytes = message.getPart(part)?.decodeContentBinary();
      if (bytes == null || bytes.isEmpty) {
        throw const MailException(
          MailErrorCodes.attachmentMissing,
          '服务端没有该附件内容',
        );
      }
      return bytes;
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<MailSendReceipt> send(MailOutgoing message) async {
    try {
      final mimeMessage = _buildMessage(message);
      final smtp = await _openSmtp();
      final response = await smtp
          .sendMessage(mimeMessage, use8BitEncoding: true)
          .timeout(_responseTimeout);
      if (!response.isOkStatus) {
        throw MailException(
          MailErrorCodes.sendRejected,
          response.message ?? '服务器拒绝发信',
        );
      }
      return MailSendReceipt(
        messageId: mimeMessage.getHeaderValue('message-id'),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> appendToSent({
    required String folderPath,
    required MailOutgoing message,
  }) async {
    final imap = _imap;
    if (imap == null || !imap.isLoggedIn) {
      return;
    }
    try {
      await imap.appendMessage(
        _buildMessage(message),
        targetMailboxPath: folderPath,
      );
    } catch (error) {
      // 追加副本失败不影响「已发送」的事实，只留一行诊断。
      debugPrint('追加已发送副本失败：${mapMailError(error).code}');
    }
  }

  enough.ImapClient _requireImap() {
    final imap = _imap;
    if (imap == null || !imap.isLoggedIn) {
      throw const MailException(MailErrorCodes.unavailable, '邮箱未连接');
    }
    return imap;
  }

  Future<enough.SmtpClient> _openSmtp() async {
    final existing = _smtp;
    if (existing != null && existing.isLoggedIn) {
      return existing;
    }
    final smtp = enough.SmtpClient(_smtpClientDomain);
    try {
      await smtp
          .connectToServer(
            _account.server.smtpHost,
            _account.server.smtpPort,
            isSecure: true,
          )
          .timeout(_responseTimeout);
      final hello = await smtp.ehlo().timeout(_responseTimeout);
      if (!hello.isOkStatus) {
        throw const MailException(MailErrorCodes.protocol, '发信服务器握手失败');
      }
      final auth = await smtp
          .authenticate(_account.address, _secret)
          .timeout(_responseTimeout);
      if (!auth.isOkStatus) {
        throw const MailException(
          MailErrorCodes.authRequired,
          '发信认证失败，请检查账号或授权码',
        );
      }
    } catch (error) {
      try {
        await smtp.disconnect();
      } catch (_) {
        // 连接可能还没建立，断开失败无需处理。
      }
      throw _mapError(error);
    }
    _smtp = smtp;
    return smtp;
  }

  Future<void> _closeImapQuietly(enough.ImapClient imap) async {
    try {
      await imap.disconnect();
    } catch (_) {
      // 连接可能还没建立，断开失败无需处理。
    }
  }

  enough.MimeMessage _buildMessage(MailOutgoing message) {
    final builder = enough.MessageBuilder()
      ..from = [enough.MailAddress(null, message.from)]
      ..subject = message.subject;
    final recipients = message.to
        .map((address) => enough.MailAddress(null, address))
        .toList();
    if (recipients.isNotEmpty) {
      builder.to = recipients;
    }
    final copies = message.cc
        .map((address) => enough.MailAddress(null, address))
        .toList();
    if (copies.isNotEmpty) {
      builder.cc = copies;
    }
    final inReplyTo = message.inReplyTo;
    if (inReplyTo != null && inReplyTo.isNotEmpty) {
      builder
        ..setHeader('In-Reply-To', inReplyTo)
        ..setHeader('References', inReplyTo);
    }
    final bodyText = message.bodyText;
    final bodyHtml = message.bodyHtml;
    final hasText = bodyText.isNotEmpty;
    final hasHtml = bodyHtml.isNotEmpty;
    if (message.attachments.isEmpty) {
      if (hasText && hasHtml) {
        builder
          ..setContentType(enough.MediaSubtype.multipartAlternative.mediaType)
          ..addTextPlain(bodyText)
          ..addTextHtml(bodyHtml);
      } else if (hasHtml) {
        builder
          ..setContentType(enough.MediaSubtype.textHtml.mediaType)
          ..text = bodyHtml;
      } else {
        builder.text = bodyText;
      }
    } else {
      builder.setContentType(enough.MediaSubtype.multipartMixed.mediaType);
      if (hasText && hasHtml) {
        builder.addMultipartAlternative(
          plainText: bodyText,
          htmlText: bodyHtml,
        );
      } else if (hasHtml) {
        builder.addTextHtml(bodyHtml);
      } else {
        builder.addTextPlain(bodyText);
      }
      for (final attachment in message.attachments) {
        final part = builder.addBinary(
          attachment.bytes,
          _mediaTypeOf(attachment.contentType),
        );
        final contentId = attachment.contentId;
        if (contentId != null && contentId.isNotEmpty) {
          part.setHeader('Content-ID', '<$contentId>');
        }
      }
    }
    final built = builder.buildMimeMessage();
    _rewriteAttachmentDisposition(built, message.attachments);
    return built;
  }

  /// 重新写附件的 `Content-Disposition`。
  /// [enough.MessageBuilder.buildMimeMessage] **之后**做：构建阶段会按
  /// `addBinary` 里的 disposition 字段重渲染一遍头部，提前 setHeader 会被覆盖。
  /// 协议库的 `renderField` 把参数值原样塞进引号，中文名会以裸 UTF-8 字节写进
  /// 头部，收件端按 Latin-1 解析就成了乱码，所以这里自己写、非 ASCII 走 RFC 2231。
  void _rewriteAttachmentDisposition(
    enough.MimeMessage message,
    List<MailOutgoingAttachment> attachments,
  ) {
    if (attachments.isEmpty) {
      return;
    }
    final parts = message.allPartsFlat
        .where((part) => part.getHeaderContentDisposition() != null)
        .toList();
    for (
      var index = 0;
      index < parts.length && index < attachments.length;
      index++
    ) {
      final attachment = attachments[index];
      parts[index].setHeader(
        'Content-Disposition',
        _contentDispositionValue(
          attachment.filename,
          inline: attachment.inline,
        ),
      );
    }
  }
}

/// 把协议库的文件夹映射成网关快照。
MailFolderSnapshot folderSnapshotFrom(enough.Mailbox mailbox) {
  return MailFolderSnapshot(
    path: mailbox.path,
    name: mailbox.name,
    specialUse: _specialUseOf(mailbox),
    uidValidity: mailbox.uidValidity?.toString(),
    total: mailbox.messagesExists,
    unread: mailbox.messagesUnseen,
  );
}

/// 列表里只保留可选中的文件夹：选中 \Noselect 的文件夹必然失败。
List<MailFolderSnapshot> folderSnapshotsFrom(List<enough.Mailbox> mailboxes) {
  return mailboxes
      .where((mailbox) => !mailbox.isNotSelectable)
      .map(folderSnapshotFrom)
      .toList();
}

/// 把协议库的邮件映射成列表摘要。列表同步不下载正文，snippet 一律为空。
MailHeader headerFrom(enough.MimeMessage message) {
  final uid = message.uid;
  if (uid == null) {
    throw const MailException(MailErrorCodes.protocol, '服务端没有返回邮件 UID');
  }
  final from = message.from;
  return MailHeader(
    uid: uid,
    messageId: _nonEmpty(message.getHeaderValue('message-id')),
    subject: message.decodeSubject(),
    sender: from == null || from.isEmpty
        ? null
        : MailAddress(name: from.first.personalName, address: from.first.email),
    sentAtUtc: message.decodeDate()?.toUtc(),
    seen: message.isSeen,
    flagged: message.isFlagged,
    hasAttachments: message.hasAttachments(),
    size: message.size,
  );
}

/// 把整封邮件映射成正文与附件清单。
MailBody bodyFrom(enough.MimeMessage message) {
  final attachments = <MailAttachmentInfo>[];
  _collectAttachments(message, '', attachments);
  return MailBody(
    bodyText: message.decodeTextPlainPart(),
    bodyHtml: message.decodeTextHtmlPart(),
    to: _addressesOf(message.to),
    cc: _addressesOf(message.cc),
    attachments: attachments,
  );
}

/// 把任意异常映射成带 [MailErrorCodes] 的 [MailException]。
///
/// 先按异常类型判断，字符串匹配只在协议库只给出服务器文字时兜底；
/// 映射出的消息不携带凭据，也不回显原始异常里的密码。
MailException mapMailError(Object error) {
  if (error is MailException) {
    return error;
  }
  if (error is TimeoutException) {
    return const MailException(
      MailErrorCodes.timeout,
      '邮箱服务器响应超时，请稍后重试',
      retryable: true,
    );
  }
  if (error is SocketException || error is HandshakeException) {
    return const MailException(
      MailErrorCodes.network,
      '无法连接邮箱服务器，请检查网络',
      retryable: true,
    );
  }
  if (error is enough.ImapException) {
    final message = error.message;
    if (_isTimeoutText(message)) {
      return const MailException(
        MailErrorCodes.timeout,
        '邮箱服务器响应超时，请稍后重试',
        retryable: true,
      );
    }
    if (looksLikeAuthFailure(message)) {
      return const MailException(MailErrorCodes.authRequired, '邮箱账号或授权码无效');
    }
    return MailException(MailErrorCodes.protocol, '邮箱协议错误：${message ?? '未知'}');
  }
  if (error is enough.SmtpException) {
    final code = error.response.code;
    if (code == 530 || code == 534 || code == 535) {
      return const MailException(MailErrorCodes.authRequired, '邮箱账号或授权码无效');
    }
    if (looksLikeAuthFailure(error.message)) {
      return const MailException(MailErrorCodes.authRequired, '邮箱账号或授权码无效');
    }
    return MailException(
      MailErrorCodes.protocol,
      '发信服务器拒绝：${error.message ?? '未知'}',
    );
  }
  if (error is enough.InvalidArgumentException) {
    return MailException(MailErrorCodes.protocol, '邮箱协议错误：${error.message}');
  }
  return const MailException(MailErrorCodes.protocol, '邮箱操作失败');
}

/// 服务端文字是否在说认证失败。
bool looksLikeAuthFailure(String? text) {
  if (text == null) {
    return false;
  }
  final upper = text.toUpperCase();
  return upper.contains('AUTHENTICATIONFAILED') ||
      upper.contains('AUTHENTICATION FAILED') ||
      upper.contains('LOGIN FAILED') ||
      upper.contains('INVALID CREDENTIALS');
}

MailException _mapError(Object error) => mapMailError(error);

bool _isTimeoutText(String? text) =>
    text != null && text.trim().toUpperCase() == 'TIMEOUT';

String? _specialUseOf(enough.Mailbox mailbox) {
  if (mailbox.isInbox) {
    return 'inbox';
  }
  if (mailbox.isDrafts) {
    return 'drafts';
  }
  if (mailbox.isSent) {
    return 'sent';
  }
  if (mailbox.isTrash) {
    return 'trash';
  }
  if (mailbox.isJunk) {
    return 'junk';
  }
  if (mailbox.isArchive) {
    return 'archive';
  }
  return null;
}

List<MailAddress> _addressesOf(List<enough.MailAddress>? addresses) {
  if (addresses == null) {
    return const [];
  }
  return addresses
      .map(
        (address) =>
            MailAddress(name: address.personalName, address: address.email),
      )
      .toList();
}

void _collectAttachments(
  enough.MimePart part,
  String prefix,
  List<MailAttachmentInfo> result,
) {
  final parts = part.parts;
  if (parts == null) {
    return;
  }
  for (var index = 0; index < parts.length; index++) {
    final child = parts[index];
    final fetchId = prefix.isEmpty ? '${index + 1}' : '$prefix.${index + 1}';
    if (child.getHeaderContentDisposition()?.disposition ==
        enough.ContentDisposition.attachment) {
      result.add(
        MailAttachmentInfo(
          filename: child.decodeFileName() ?? '未命名附件',
          bytes: child.decodeContentBinary()?.length,
          part: fetchId,
          contentId: _contentIdOf(child),
        ),
      );
    }
    _collectAttachments(child, fetchId, result);
  }
}

String? _contentIdOf(enough.MimePart part) {
  final raw = part.getHeaderValue('content-id')?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw.startsWith('<') && raw.endsWith('>')
      ? raw.substring(1, raw.length - 1)
      : raw;
}

enough.MediaType _mediaTypeOf(String contentType) {
  final text = contentType.trim();
  return text.isEmpty
      ? enough.MediaSubtype.applicationOctetStream.mediaType
      : enough.MediaType.fromText(text);
}

/// 拼 `Content-Disposition` 的值。
///
/// 纯 ASCII 文件名用普通的引号形式；含非 ASCII 字符时按 RFC 2231 写成
/// `filename*=utf-8''%E6%8E%A2...`，否则收件端会按 Latin-1 解出乱码。
String _contentDispositionValue(String filename, {required bool inline}) {
  final kind = inline ? 'inline' : 'attachment';
  final name = filename.trim();
  if (name.isEmpty) {
    return kind;
  }
  if (_isPlainHeaderAscii(name)) {
    final escaped = name.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '$kind; filename="$escaped"';
  }
  return "$kind; filename*=utf-8''${_percentEncodeAscii(name)}";
}

bool _isPlainHeaderAscii(String value) {
  for (final unit in value.codeUnits) {
    if (unit < 0x20 || unit > 0x7e) {
      return false;
    }
  }
  return true;
}

String _percentEncodeAscii(String value) {
  final buffer = StringBuffer();
  for (final byte in utf8.encode(value)) {
    final isUnreserved =
        (byte >= 0x30 && byte <= 0x39) ||
        (byte >= 0x41 && byte <= 0x5a) ||
        (byte >= 0x61 && byte <= 0x7a) ||
        byte == 0x21 ||
        byte == 0x23 ||
        byte == 0x24 ||
        byte == 0x26 ||
        byte == 0x2b ||
        byte == 0x2d ||
        byte == 0x2e ||
        byte == 0x5e ||
        byte == 0x5f ||
        byte == 0x60 ||
        byte == 0x7c ||
        byte == 0x7e;
    if (isUnreserved) {
      buffer.writeCharCode(byte);
    } else {
      buffer
        ..write('%')
        ..write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
    }
  }
  return buffer.toString();
}

enough.MimeMessage? _messageWithUid(
  List<enough.MimeMessage> messages,
  int uid,
) {
  for (final message in messages) {
    if (message.uid == uid) {
      return message;
    }
  }
  return null;
}

String? _nonEmpty(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}
