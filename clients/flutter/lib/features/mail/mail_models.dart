/// 邮箱本地模型。
///
/// 时间一律用 UTC 毫秒；校园展示时区换算见 `core/models/school_time.dart`。
/// 邮件标识分三层：服务端（IMAP）的 `folderPath + uid` 是稳定标识，
/// 本地 `id` 只用于本机引用，不能冒充跨设备稳定 ID。
library;

/// 吉大学生邮箱预设（mails.jlu.edu.cn，IMAP 993 / SMTP 465）。
///
/// 教工邮箱 `mail.jlu.edu.cn` 是另一套 Coremail，需要用户自填服务器参数。
const MailServerConfig jluStudentMailServer = MailServerConfig(
  imapHost: 'mails.jlu.edu.cn',
  imapPort: 993,
  smtpHost: 'mails.jlu.edu.cn',
  smtpPort: 465,
);

class MailServerConfig {
  const MailServerConfig({
    required this.imapHost,
    required this.imapPort,
    required this.smtpHost,
    required this.smtpPort,
  });

  final String imapHost;
  final int imapPort;
  final String smtpHost;
  final int smtpPort;

  Map<String, dynamic> toJson() => {
    'imap_host': imapHost,
    'imap_port': imapPort,
    'smtp_host': smtpHost,
    'smtp_port': smtpPort,
  };

  factory MailServerConfig.fromJson(Map<String, dynamic> json) {
    return MailServerConfig(
      imapHost: json['imap_host'] as String,
      imapPort: json['imap_port'] as int,
      smtpHost: json['smtp_host'] as String,
      smtpPort: json['smtp_port'] as int,
    );
  }
}

class MailAddress {
  const MailAddress({this.name, this.address});

  final String? name;
  final String? address;

  String get display => name == null || name!.isEmpty
      ? (address ?? '')
      : '$name <${address ?? ''}>';

  Map<String, dynamic> toJson() => {'name': name, 'address': address};

  factory MailAddress.fromJson(Map<String, dynamic> json) {
    return MailAddress(
      name: json['name'] as String?,
      address: json['address'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MailAddress && other.name == name && other.address == address;

  @override
  int get hashCode => Object.hash(name, address);

  @override
  String toString() => display;
}

class MailAttachmentInfo {
  const MailAttachmentInfo({
    required this.filename,
    this.bytes,
    this.part,
    this.contentId,
  });

  final String filename;
  final int? bytes;

  /// MIME part 标识，取附件时用。
  final String? part;

  /// 内联图片的 `Content-ID`，正文 `cid:` 引用它。
  final String? contentId;

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'bytes': bytes,
    'part': part,
    'content_id': contentId,
  };

  factory MailAttachmentInfo.fromJson(Map<String, dynamic> json) {
    return MailAttachmentInfo(
      filename: json['filename'] as String,
      bytes: json['bytes'] as int?,
      part: json['part'] as String?,
      contentId: json['content_id'] as String?,
    );
  }
}

/// 邮箱连接状态：区分「账号/凭据问题」与「网络问题」。
enum MailConnectionState { unknown, connected, authRequired, unreachable }

class MailAccount {
  MailAccount({
    required this.id,
    required this.userId,
    required this.address,
    this.displayName,
    required this.server,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.lastConnectedAtUtc,
    this.lastErrorCode,
    this.lastErrorMessage,
  });

  final String id;
  final String userId;
  final String address;
  final String? displayName;
  final MailServerConfig server;
  final DateTime createdAtUtc;
  DateTime updatedAtUtc;
  DateTime? lastConnectedAtUtc;
  String? lastErrorCode;
  String? lastErrorMessage;

  MailConnectionState get connectionState {
    if (lastErrorCode == null) {
      return lastConnectedAtUtc == null
          ? MailConnectionState.unknown
          : MailConnectionState.connected;
    }
    return lastErrorCode == MailErrorCodes.authRequired
        ? MailConnectionState.authRequired
        : MailConnectionState.unreachable;
  }
}

class MailFolder {
  MailFolder({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.path,
    required this.name,
    this.specialUse,
    this.uidValidity,
    this.total,
    this.unread,
    this.syncedAtUtc,
  });

  final String id;
  final String userId;
  final String accountId;

  /// IMAP 文件夹路径，如 `INBOX`、`Sent`。跨设备稳定。
  final String path;
  final String name;

  /// `\Inbox` `\Sent` `\Drafts` `\Trash` `\Junk` 等特殊用途标记。
  final String? specialUse;
  final String? uidValidity;
  final int? total;
  final int? unread;
  DateTime? syncedAtUtc;
}

class MailMessageSummary {
  MailMessageSummary({
    required this.id,
    required this.accountId,
    required this.folderId,
    required this.folderPath,
    required this.uid,
    this.messageId,
    this.subject,
    this.sender,
    this.sentAtUtc,
    required this.seen,
    required this.flagged,
    required this.hasAttachments,
    this.snippet,
    this.size,
    required this.observedAtUtc,
  });

  final String id;
  final String accountId;
  final String folderId;
  final String folderPath;

  /// IMAP UID，与 [folderPath] 一起构成跨设备稳定标识。
  final int uid;
  final String? messageId;
  final String? subject;
  final MailAddress? sender;
  final DateTime? sentAtUtc;
  bool seen;
  bool flagged;
  final bool hasAttachments;
  final String? snippet;
  final int? size;
  final DateTime observedAtUtc;

  String get subjectOrPlaceholder =>
      (subject == null || subject!.isEmpty) ? '(无主题)' : subject!;
}

class MailMessageDetail extends MailMessageSummary {
  MailMessageDetail({
    required super.id,
    required super.accountId,
    required super.folderId,
    required super.folderPath,
    required super.uid,
    super.messageId,
    super.subject,
    super.sender,
    super.sentAtUtc,
    required super.seen,
    required super.flagged,
    required super.hasAttachments,
    super.snippet,
    super.size,
    required super.observedAtUtc,
    this.to = const [],
    this.cc = const [],
    this.bodyText,
    this.bodyHtml,
    this.attachments = const [],
    this.bodyFetchedAtUtc,
  });

  final List<MailAddress> to;
  final List<MailAddress> cc;
  final String? bodyText;
  final String? bodyHtml;
  final List<MailAttachmentInfo> attachments;
  final DateTime? bodyFetchedAtUtc;

  /// 正文是否已下载。列表页只取头部，打开邮件时才拉正文。
  bool get hasBody => bodyFetchedAtUtc != null;
}

/// 草稿发送状态。
///
/// `editing` 表示用户还在编辑或已保存未发送；`sending` 表示正在提交 SMTP；
/// `failed` 必须保留正文与附件选择，允许再次发送；`sent` 只作短暂展示。
enum MailSendState { editing, sending, failed, sent }

class MailDraft {
  MailDraft({
    required this.id,
    required this.userId,
    required this.accountId,
    this.recipientText = '',
    this.subject = '',
    this.bodyText = '',
    this.bodyHtml = '',
    this.inReplyTo,
    this.attachments = const [],
    this.sendState = MailSendState.editing,
    this.lastErrorCode,
    this.lastErrorMessage,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final String id;
  final String userId;
  final String accountId;

  /// 收件人原始文本（可能多个、含显示名），发送时才解析。
  String recipientText;
  String subject;
  String bodyText;
  String bodyHtml;

  /// 回复/转发时的原邮件 `Message-ID`。
  String? inReplyTo;
  List<MailDraftAttachment> attachments;
  MailSendState sendState;
  String? lastErrorCode;
  String? lastErrorMessage;
  final DateTime createdAtUtc;
  DateTime updatedAtUtc;

  bool get canRetry =>
      sendState == MailSendState.failed || sendState == MailSendState.editing;

  bool get isEmpty =>
      recipientText.trim().isEmpty &&
      subject.trim().isEmpty &&
      bodyText.trim().isEmpty &&
      bodyHtml.trim().isEmpty &&
      attachments.isEmpty;
}

/// 草稿附件。附件内容存本机文件，草稿只记引用。
class MailDraftAttachment {
  const MailDraftAttachment({
    required this.id,
    required this.name,
    this.bytes,
    this.inline = false,
  });

  final String id;
  final String name;
  final int? bytes;
  final bool inline;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'bytes': bytes,
    'inline': inline,
  };

  factory MailDraftAttachment.fromJson(Map<String, dynamic> json) {
    return MailDraftAttachment(
      id: json['id'] as String,
      name: json['name'] as String,
      bytes: json['bytes'] as int?,
      inline: json['inline'] as bool? ?? false,
    );
  }
}

/// 邮箱错误码。与来源层共用 `SOURCE_AUTH_REQUIRED` 语义：
/// 凭据失效进重连流程，不登出工作台账号。
abstract final class MailErrorCodes {
  static const authRequired = 'SOURCE_AUTH_REQUIRED';
  static const network = 'SOURCE_NETWORK';
  static const timeout = 'SOURCE_TIMEOUT';
  static const protocol = 'SOURCE_PROTOCOL';
  static const unavailable = 'SOURCE_UNAVAILABLE';
  static const attachmentMissing = 'MAIL_ATTACHMENT_MISSING';
  static const draftTooLarge = 'MAIL_DRAFT_TOO_LARGE';
  static const sendRejected = 'MAIL_SEND_REJECTED';
}

class MailException implements Exception {
  const MailException(this.code, this.message, {this.retryable = false});

  final String code;
  final String message;
  final bool retryable;

  @override
  String toString() => 'MailException($code: $message)';
}

/// 文件夹同步快照。由 `MailGateway` 产出，不依赖任何邮件协议类型。
class MailFolderSnapshot {
  const MailFolderSnapshot({
    required this.path,
    required this.name,
    this.specialUse,
    this.uidValidity,
    this.total,
    this.unread,
  });

  final String path;
  final String name;
  final String? specialUse;
  final String? uidValidity;
  final int? total;
  final int? unread;
}
