import 'mail_credential_store.dart';
import 'mail_gateway.dart';
import 'mail_models.dart';
import 'mail_store.dart';

/// 一次同步的结果。
///
/// 界面要能区分「同步成功但没新邮件」「凭据失效」「网络不通」，
/// 所以失败不是抛异常，而是返回带状态的对象。
class MailSyncOutcome {
  const MailSyncOutcome({
    required this.state,
    this.foldersSynced = 0,
    this.messagesSynced = 0,
    this.errorCode,
    this.errorMessage,
  });

  const MailSyncOutcome.ok({this.foldersSynced = 0, this.messagesSynced = 0})
    : state = MailConnectionState.connected,
      errorCode = null,
      errorMessage = null;

  const MailSyncOutcome.failed({
    required this.errorCode,
    required this.errorMessage,
    this.state = MailConnectionState.unreachable,
  }) : foldersSynced = 0,
       messagesSynced = 0;

  final MailConnectionState state;
  final int foldersSynced;
  final int messagesSynced;
  final String? errorCode;
  final String? errorMessage;

  bool get isSuccess => state == MailConnectionState.connected;
}

/// 邮件同步编排。
///
/// 把「连上邮箱 → 拉文件夹 → 拉头部 → 按需拉正文 → 发信」串起来，
/// 并把结果写进 [MailStore]。网络协议细节全在 [MailGateway]，
/// 本类不 import 任何 IMAP/SMTP 库。
class MailSyncService {
  MailSyncService({
    required this.store,
    required this.credentials,
    required this.gatewayFactory,
    required this.attachments,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// 单次头部同步的上限。列表页首屏够用，避免一次拉几千封。
  static const int defaultHeaderBatch = 50;

  final MailStore store;
  final MailSecretStore credentials;
  final MailGatewayFactory gatewayFactory;
  final MailAttachmentSource attachments;
  final DateTime Function() _now;

  MailGateway? _gateway;
  String? _gatewayAccountId;

  /// 连接账户。凭据从安全存储读取，不落日志。
  Future<MailSyncOutcome> connect(MailAccount account) async {
    final secret = await credentials.read(account.userId, account.id);
    if (secret == null || secret.isEmpty) {
      await store.recordConnection(
        accountId: account.id,
        connected: false,
        errorCode: MailErrorCodes.authRequired,
        errorMessage: '尚未保存邮箱密码或授权码',
      );
      return const MailSyncOutcome.failed(
        state: MailConnectionState.authRequired,
        errorCode: MailErrorCodes.authRequired,
        errorMessage: '尚未保存邮箱密码或授权码',
      );
    }
    try {
      await _disposeGateway();
      final gateway = gatewayFactory.create(account: account, secret: secret);
      await gateway.connect();
      _gateway = gateway;
      _gatewayAccountId = account.id;
      await store.recordConnection(accountId: account.id, connected: true);
      return const MailSyncOutcome.ok();
    } on MailException catch (error) {
      await store.recordConnection(
        accountId: account.id,
        connected: false,
        errorCode: error.code,
        errorMessage: error.message,
      );
      return MailSyncOutcome.failed(
        state: error.code == MailErrorCodes.authRequired
            ? MailConnectionState.authRequired
            : MailConnectionState.unreachable,
        errorCode: error.code,
        errorMessage: error.message,
      );
    }
  }

  /// 同步文件夹列表。完整读取时清掉服务端已不存在的文件夹。
  Future<MailSyncOutcome> syncFolders(MailAccount account) async {
    final gateway = await _requireGateway(account);
    if (gateway == null) {
      return const MailSyncOutcome.failed(
        state: MailConnectionState.authRequired,
        errorCode: MailErrorCodes.authRequired,
        errorMessage: '邮箱未连接',
      );
    }
    try {
      final snapshots = await gateway.listFolders();
      await store.replaceFolders(account.id, snapshots, complete: true);
      return MailSyncOutcome.ok(foldersSynced: snapshots.length);
    } on MailException catch (error) {
      await _recordFailure(account, error);
      return _failureOutcome(error);
    }
  }

  /// 同步一个文件夹的新邮件头部。
  ///
  /// [sinceUid] 传本地已缓存的最大 UID；首次同步传 0。
  /// 若服务端 UIDVALIDITY 变了，会清空该文件夹的本地缓存后从头同步——
  /// 否则旧 uid 指向的会是完全不同的邮件。
  Future<MailSyncOutcome> syncHeaders(
    MailAccount account, {
    required String folderPath,
    int sinceUid = 0,
    int limit = defaultHeaderBatch,
  }) async {
    final gateway = await _requireGateway(account);
    if (gateway == null) {
      return const MailSyncOutcome.failed(
        state: MailConnectionState.authRequired,
        errorCode: MailErrorCodes.authRequired,
        errorMessage: '邮箱未连接',
      );
    }
    try {
      final folder = await store.folderByPath(account.id, folderPath);
      if (folder == null) {
        return const MailSyncOutcome.failed(
          errorCode: MailErrorCodes.protocol,
          errorMessage: '本地没有该文件夹，请先同步文件夹列表',
        );
      }
      var batch = await gateway.fetchHeaders(
        folderPath: folderPath,
        sinceUid: sinceUid,
        limit: limit,
      );
      // 先比对 UIDVALIDITY，再决定这批结果能不能用。
      //
      // 顺序不能反：UID 空间重建后，旧 sinceUid 指向的是完全不存在的区间，
      // 按旧水位拉回来的增量是空的——清完缓存就什么都没了。发现变化必须
      // 从 0 重拉，并把新的 UIDVALIDITY 记下来，否则下次同步还会再判一次变化。
      if (MailStore.uidValidityChanged(folder.uidValidity, batch.uidValidity)) {
        await store.clearFolderMessages(folder.id);
        await store.updateFolderUidValidity(folder.id, batch.uidValidity!);
        batch = await gateway.fetchHeaders(
          folderPath: folderPath,
          sinceUid: 0,
          limit: limit,
        );
      } else if (folder.uidValidity == null && batch.uidValidity != null) {
        // 首次同步：记下 UIDVALIDITY 作为后续比较的基准。
        await store.updateFolderUidValidity(folder.id, batch.uidValidity!);
      }
      for (final header in batch.headers) {
        await store.upsertSummary(
          MailMessageSummary(
            id: '',
            accountId: account.id,
            folderId: folder.id,
            folderPath: folderPath,
            uid: header.uid,
            messageId: header.messageId,
            subject: header.subject,
            sender: header.sender,
            sentAtUtc: header.sentAtUtc,
            seen: header.seen,
            flagged: header.flagged,
            hasAttachments: header.hasAttachments,
            snippet: header.snippet,
            size: header.size,
            observedAtUtc: _now().toUtc(),
          ),
        );
      }
      return MailSyncOutcome.ok(messagesSynced: batch.headers.length);
    } on MailException catch (error) {
      await _recordFailure(account, error);
      return _failureOutcome(error);
    }
  }

  /// 打开一封邮件：正文已缓存就直接返回，否则拉取后落库。
  ///
  /// 拉取失败时抛 [MailException]，调用方保留已有摘要并显示错误，
  /// 不能把「没拉到正文」显示成「正文为空」。
  Future<MailMessageDetail> openMessage(MailMessageDetail summary) async {
    if (summary.hasBody) {
      return summary;
    }
    final gateway = _gatewayForAccount(summary.accountId);
    final body = await gateway.fetchBody(
      folderPath: summary.folderPath,
      uid: summary.uid,
    );
    await store.saveBody(
      messageId: summary.id,
      bodyText: body.bodyText,
      bodyHtml: body.bodyHtml,
      to: body.to,
      cc: body.cc,
      attachments: body.attachments,
    );
    return (await store.messageById(summary.id))!;
  }

  /// 下载单个附件。附件缺失必须明确报错，不能返回空字节。
  Future<List<int>> downloadAttachment({
    required MailMessageDetail message,
    required MailAttachmentInfo attachment,
  }) async {
    final gateway = _gatewayForAccount(message.accountId);
    final part = attachment.part;
    if (part == null || part.isEmpty) {
      throw MailException(
        MailErrorCodes.attachmentMissing,
        '附件「${attachment.filename}」缺少定位信息',
      );
    }
    final bytes = await gateway.fetchAttachment(
      folderPath: message.folderPath,
      uid: message.uid,
      part: part,
    );
    if (bytes.isEmpty) {
      throw MailException(
        MailErrorCodes.attachmentMissing,
        '附件「${attachment.filename}」在服务器上已不存在',
      );
    }
    return bytes;
  }

  /// 取指定账号的连接。
  ///
  /// 内容必须走它自己所属账号的网关：文件夹路径与 UID 只在同一个账号里
  /// 有意义，拿 A 的 UID 去 B 的服务器上读，要么读到别人的邮件，
  /// 要么把别人的正文写进 A 的缓存。当前连接不是这个账号时明确拒绝，
  /// 让调用方先切号，而不是静默用错账号。
  MailGateway _gatewayForAccount(String accountId) {
    final gateway = _gateway;
    if (gateway == null) {
      throw const MailException(MailErrorCodes.unavailable, '邮箱未连接');
    }
    if (_gatewayAccountId != accountId) {
      throw const MailException(
        MailErrorCodes.wrongAccount,
        '该内容属于另一个邮箱账号，请先切换到对应账号',
      );
    }
    return gateway;
  }

  /// 发送草稿。
  ///
  /// 顺序固定：先落 `sending`，再发信，最后按结果落 `sent` 或 `failed`。
  /// 失败时正文与附件选择全部保留，用户可以改完再发。
  Future<MailSendOutcome> sendDraft(MailDraft draft) async {
    final gateway = _gateway;
    if (gateway == null) {
      await store.markSendFailed(
        draft.id,
        code: MailErrorCodes.unavailable,
        message: '邮箱未连接',
      );
      return const MailSendOutcome.failed(
        code: MailErrorCodes.unavailable,
        message: '邮箱未连接',
      );
    }
    if (_gatewayAccountId != draft.accountId) {
      // 用 B 的连接发 A 的草稿会把 A 的私人内容交给 B 的服务器。
      await store.markSendFailed(
        draft.id,
        code: MailErrorCodes.wrongAccount,
        message: '该草稿属于另一个邮箱账号，请先切换到对应账号再发送',
      );
      return const MailSendOutcome.failed(
        code: MailErrorCodes.wrongAccount,
        message: '该草稿属于另一个邮箱账号，请先切换到对应账号再发送',
      );
    }
    final recipients = _parseRecipients(draft.recipientText);
    if (recipients.isEmpty) {
      await store.markSendFailed(
        draft.id,
        code: MailErrorCodes.sendRejected,
        message: '请填写收件人',
      );
      return const MailSendOutcome.failed(
        code: MailErrorCodes.sendRejected,
        message: '请填写收件人',
      );
    }
    final outgoing = <MailOutgoingAttachment>[];
    for (final attachment in draft.attachments) {
      final bytes = await attachments.read(attachment.id);
      if (bytes == null) {
        await store.markSendFailed(
          draft.id,
          code: MailErrorCodes.attachmentMissing,
          message: '附件「${attachment.name}」已不存在，请重新选择',
        );
        return MailSendOutcome.failed(
          code: MailErrorCodes.attachmentMissing,
          message: '附件「${attachment.name}」已不存在，请重新选择',
        );
      }
      outgoing.add(
        MailOutgoingAttachment(
          filename: attachment.name,
          bytes: bytes,
          inline: attachment.inline,
        ),
      );
    }

    await store.markSending(draft.id);
    final account = await store.accountById(draft.accountId);
    if (account == null) {
      await store.markSendFailed(
        draft.id,
        code: MailErrorCodes.protocol,
        message: '账户不存在',
      );
      return const MailSendOutcome.failed(
        code: MailErrorCodes.protocol,
        message: '账户不存在',
      );
    }
    final message = MailOutgoing(
      from: account.address,
      to: recipients,
      subject: draft.subject,
      bodyText: draft.bodyText,
      bodyHtml: draft.bodyHtml,
      inReplyTo: draft.inReplyTo,
      attachments: outgoing,
    );
    try {
      final receipt = await gateway.send(message);
      if (!receipt.appendedToSent) {
        await _appendToSentQuietly(gateway, message);
      }
      await store.markSent(draft.id);
      return MailSendOutcome.sent(receipt.messageId);
    } on MailException catch (error) {
      await store.markSendFailed(
        draft.id,
        code: error.code,
        message: error.message,
      );
      return MailSendOutcome.failed(code: error.code, message: error.message);
    }
  }

  /// 保存邮箱密码或授权码，并立即尝试连接。
  Future<MailSyncOutcome> saveSecret(MailAccount account, String secret) async {
    await credentials.write(account.userId, account.id, secret);
    return connect(account);
  }

  /// 应用启动时调用：把上次中断的发送降级为可重试。
  Future<int> recoverInterruptedSends() => store.recoverInterruptedSends();

  Future<void> dispose() => _disposeGateway();

  Future<void> _appendToSentQuietly(
    MailGateway gateway,
    MailOutgoing message,
  ) async {
    try {
      await gateway.appendToSent(folderPath: 'Sent', message: message);
    } on MailException {
      // 追加副本失败不影响「已发送」的事实，界面提示用户手动查看即可。
    }
  }

  Future<MailGateway?> _requireGateway(MailAccount account) async {
    if (_gateway != null && _gatewayAccountId == account.id) {
      return _gateway;
    }
    final outcome = await connect(account);
    if (!outcome.isSuccess) {
      return null;
    }
    return _gateway;
  }

  Future<void> _recordFailure(MailAccount account, MailException error) {
    return store.recordConnection(
      accountId: account.id,
      connected: false,
      errorCode: error.code,
      errorMessage: error.message,
    );
  }

  MailSyncOutcome _failureOutcome(MailException error) {
    return MailSyncOutcome.failed(
      state: error.code == MailErrorCodes.authRequired
          ? MailConnectionState.authRequired
          : MailConnectionState.unreachable,
      errorCode: error.code,
      errorMessage: error.message,
    );
  }

  Future<void> _disposeGateway() async {
    final gateway = _gateway;
    _gateway = null;
    _gatewayAccountId = null;
    if (gateway != null) {
      await gateway.disconnect();
    }
  }

  /// 解析收件人文本。支持逗号、分号、换行分隔，允许 `名字 <a@b.c>`。
  static List<String> parseRecipients(String raw) {
    return raw
        .split(RegExp(r'[,;\n]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map((part) {
          final match = RegExp(r'<([^>]+)>').firstMatch(part);
          return (match == null ? part : match.group(1)!).trim();
        })
        .where((address) => address.contains('@'))
        .toList();
  }

  List<String> _parseRecipients(String raw) => parseRecipients(raw);
}

class MailSendOutcome {
  const MailSendOutcome.sent(this.messageId)
    : state = MailSendState.sent,
      code = null,
      message = null;

  const MailSendOutcome.failed({required this.code, required this.message})
    : state = MailSendState.failed,
      messageId = null;

  final MailSendState state;
  final String? messageId;
  final String? code;
  final String? message;

  bool get isSent => state == MailSendState.sent;
}
