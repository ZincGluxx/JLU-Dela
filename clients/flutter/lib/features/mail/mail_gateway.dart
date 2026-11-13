import 'dart:typed_data';

import 'mail_models.dart';

/// 邮件协议网关。
///
/// 这一层只描述「要做什么」，不绑定任何具体协议库：接入 IMAP/SMTP 时由
/// 实现类提供，测试里用假实现。引入第三方库时只新增一个实现，
/// 上层存储与页面都不需要改动。
abstract interface class MailGateway {
  /// 建立连接并完成认证。凭据由调用方注入，网关不自行读取存储。
  Future<void> connect();

  /// 主动断开。实现必须保证重复调用安全。
  Future<void> disconnect();

  /// 列出全部文件夹。返回的顺序不重要，调用方按 path 排序。
  Future<List<MailFolderSnapshot>> listFolders();

  /// 取某个文件夹里 UID 大于 [sinceUid] 的邮件摘要，最多 [limit] 封。
  ///
  /// 只取信封与头部，不下载正文——列表页不需要正文。
  Future<MailHeaderBatch> fetchHeaders({
    required String folderPath,
    required int sinceUid,
    required int limit,
  });

  /// 取单封邮件的正文与附件清单。
  Future<MailBody> fetchBody({required String folderPath, required int uid});

  /// 取单个附件的字节。附件可能很大，只在用户点下载时调用。
  Future<Uint8List> fetchAttachment({
    required String folderPath,
    required int uid,
    required String part,
  });

  /// 提交发信。成功返回回执；失败必须抛 [MailException]。
  Future<MailSendReceipt> send(MailOutgoing message);

  /// 把已发送的邮件追加到服务端「已发送」文件夹。
  ///
  /// 失败不应让整次发送变成失败：本地已视为发出，只记录提示。
  Future<void> appendToSent({
    required String folderPath,
    required MailOutgoing message,
  });
}

/// 由账户参数与凭据构造网关。凭据在调用瞬间传入，实现不得缓存到磁盘。
abstract interface class MailGatewayFactory {
  MailGateway create({required MailAccount account, required String secret});
}

/// 一次头部同步的结果。
class MailHeaderBatch {
  const MailHeaderBatch({
    required this.headers,
    required this.uidValidity,
    required this.highestUid,
  });

  final List<MailHeader> headers;

  /// 服务端返回的 UIDVALIDITY。与上次记录不同说明 UID 空间已重建，
  /// 本地缓存的 uid 全部失效，必须整体重同步。
  final String? uidValidity;

  /// 本批出现的最大 UID；空批次时为 0。
  final int highestUid;

  bool get isEmpty => headers.isEmpty;
}

/// 邮件头部（列表页需要的字段）。
class MailHeader {
  const MailHeader({
    required this.uid,
    this.messageId,
    this.subject,
    this.sender,
    this.sentAtUtc,
    this.seen = false,
    this.flagged = false,
    this.hasAttachments = false,
    this.snippet,
    this.size,
  });

  final int uid;
  final String? messageId;
  final String? subject;
  final MailAddress? sender;
  final DateTime? sentAtUtc;
  final bool seen;
  final bool flagged;
  final bool hasAttachments;
  final String? snippet;
  final int? size;
}

/// 邮件正文与附件清单。
class MailBody {
  const MailBody({
    this.bodyText,
    this.bodyHtml,
    this.to = const [],
    this.cc = const [],
    this.attachments = const [],
  });

  final String? bodyText;
  final String? bodyHtml;
  final List<MailAddress> to;
  final List<MailAddress> cc;
  final List<MailAttachmentInfo> attachments;

  /// 纯文本与 HTML 都为空时，界面必须显示「正文为空」而不是空白页。
  bool get isEmpty =>
      (bodyText == null || bodyText!.trim().isEmpty) &&
      (bodyHtml == null || bodyHtml!.trim().isEmpty);
}

/// 待发送邮件。附件字节由调用方提供，网关不读本地文件。
class MailOutgoing {
  const MailOutgoing({
    required this.from,
    required this.to,
    this.cc = const [],
    this.subject = '',
    this.bodyText = '',
    this.bodyHtml = '',
    this.inReplyTo,
    this.attachments = const [],
  });

  final String from;
  final List<String> to;
  final List<String> cc;
  final String subject;
  final String bodyText;
  final String bodyHtml;

  /// 回复时的原邮件 `Message-ID`，用于线程归并。
  final String? inReplyTo;
  final List<MailOutgoingAttachment> attachments;
}

class MailOutgoingAttachment {
  const MailOutgoingAttachment({
    required this.filename,
    required this.bytes,
    this.contentType = 'application/octet-stream',
    this.inline = false,
    this.contentId,
  });

  final String filename;
  final Uint8List bytes;
  final String contentType;
  final bool inline;
  final String? contentId;
}

class MailSendReceipt {
  const MailSendReceipt({this.messageId, this.appendedToSent = false});

  final String? messageId;

  /// 是否已成功追加到服务端「已发送」文件夹。
  final bool appendedToSent;
}

/// 草稿附件内容的来源。
///
/// 附件字节存在文件层（由 A 的文件能力提供），这里只描述取字节的边界：
/// 拿不到时必须抛 [MailException]，不能伪造空附件。
abstract interface class MailAttachmentSource {
  /// 返回 null 表示该附件已不存在（用户删了文件）。
  Future<Uint8List?> read(String attachmentId);
}
