import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/local_database.dart';
import 'mail_models.dart';

/// 邮箱本地缓存与草稿存储。
///
/// 只负责本机 SQLite：账户参数、文件夹、邮件摘要与正文、草稿。
/// 网络收发由 `MailGateway` 实现，本类不建立任何连接。
/// 所有查询强制带 `user_id`，切号后读不到上一账号的数据。
class MailStore extends ChangeNotifier {
  MailStore(LocalDatabase database, this.userId, {DateTime Function()? now})
    : _database = database.database,
      _now = now ?? DateTime.now;

  static const int maxSubjectLength = 500;
  static const int maxBodyLength = 2000000;
  static const int maxRecipientTextLength = 20000;
  static const _uuid = Uuid();

  final Database _database;
  final String userId;
  final DateTime Function() _now;

  // ---------------------------------------------------------------- accounts

  Future<List<MailAccount>> listAccounts() async {
    final rows = await _database.query(
      'mail_accounts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'address',
    );
    return rows.map(_accountFromRow).toList();
  }

  Future<MailAccount?> accountByAddress(String address) async {
    final rows = await _database.query(
      'mail_accounts',
      where: 'user_id = ? AND address = ?',
      whereArgs: [userId, address],
      limit: 1,
    );
    return rows.isEmpty ? null : _accountFromRow(rows.first);
  }

  Future<MailAccount?> accountById(String id) async {
    final rows = await _database.query(
      'mail_accounts',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : _accountFromRow(rows.first);
  }

  /// 保存账户连接参数。凭据不在这里，见 `MailCredentialStore`。
  Future<MailAccount> upsertAccount({
    required String address,
    String? displayName,
    MailServerConfig server = jluStudentMailServer,
  }) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      throw const MailException(MailErrorCodes.protocol, '邮箱地址不能为空');
    }
    final timestamp = _now().toUtc();
    final existing = await accountByAddress(trimmed);
    if (existing != null) {
      await _database.update(
        'mail_accounts',
        {
          'display_name': displayName,
          'imap_host': server.imapHost,
          'imap_port': server.imapPort,
          'smtp_host': server.smtpHost,
          'smtp_port': server.smtpPort,
          'updated_at_utc': _millisecondsOf(timestamp),
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [existing.id, userId],
      );
      notifyListeners();
      return (await accountById(existing.id))!;
    }
    final account = MailAccount(
      id: _uuid.v4(),
      userId: userId,
      address: trimmed,
      displayName: displayName,
      server: server,
      createdAtUtc: timestamp,
      updatedAtUtc: timestamp,
    );
    await _database.insert('mail_accounts', {
      'id': account.id,
      'user_id': userId,
      'address': account.address,
      'display_name': account.displayName,
      'imap_host': server.imapHost,
      'imap_port': server.imapPort,
      'smtp_host': server.smtpHost,
      'smtp_port': server.smtpPort,
      'created_at_utc': _millisecondsOf(timestamp),
      'updated_at_utc': _millisecondsOf(timestamp),
    });
    notifyListeners();
    return account;
  }

  /// 记录一次连接结果。成功清空上次错误；失败保留旧的成功时间。
  Future<void> recordConnection({
    required String accountId,
    required bool connected,
    String? errorCode,
    String? errorMessage,
  }) async {
    final timestamp = _millisecondsOf(_now().toUtc());
    await _database.update(
      'mail_accounts',
      connected
          ? {
              'last_connected_at_utc': timestamp,
              'last_error_code': null,
              'last_error_message': null,
              'updated_at_utc': timestamp,
            }
          : {
              'last_error_code': errorCode ?? MailErrorCodes.protocol,
              'last_error_message': errorMessage,
              'updated_at_utc': timestamp,
            },
      where: 'id = ? AND user_id = ?',
      whereArgs: [accountId, userId],
    );
    notifyListeners();
  }

  Future<void> deleteAccount(String accountId) async {
    await _database.delete(
      'mail_accounts',
      where: 'id = ? AND user_id = ?',
      whereArgs: [accountId, userId],
    );
    notifyListeners();
  }

  // ----------------------------------------------------------------- folders

  Future<List<MailFolder>> listFolders(String accountId) async {
    final rows = await _database.query(
      'mail_folders',
      where: 'user_id = ? AND account_id = ?',
      whereArgs: [userId, accountId],
      orderBy: 'path',
    );
    return rows.map(_folderFromRow).toList();
  }

  Future<MailFolder?> folderByPath(String accountId, String path) async {
    final rows = await _database.query(
      'mail_folders',
      where: 'user_id = ? AND account_id = ? AND path = ?',
      whereArgs: [userId, accountId, path],
      limit: 1,
    );
    return rows.isEmpty ? null : _folderFromRow(rows.first);
  }

  /// 同步文件夹列表。完整读取时删除本 account 下未出现的文件夹。
  ///
  /// 部分读取不得标记为完整：传 `complete: false` 时只做 upsert。
  ///
  /// 若某文件夹的 UIDVALIDITY 与本地不同，说明服务端重建了 UID 空间：
  /// 在同一事务内清空该文件夹的邮件缓存。否则旧邮件会留在新 UID 空间里，
  /// 而 [upsertSummary] 只更新摘要、保留正文，界面上就会出现
  /// 「新标题 + 上一 UID 空间的旧正文」。
  Future<void> replaceFolders(
    String accountId,
    List<MailFolderSnapshot> snapshots, {
    required bool complete,
  }) async {
    final timestamp = _millisecondsOf(_now().toUtc());
    await _database.transaction((txn) async {
      final kept = <String>[];
      for (final snapshot in snapshots) {
        final existing = await txn.query(
          'mail_folders',
          where: 'user_id = ? AND account_id = ? AND path = ?',
          whereArgs: [userId, accountId, snapshot.path],
          limit: 1,
        );
        final id = existing.isEmpty
            ? _uuid.v4()
            : existing.first['id'] as String;
        kept.add(id);
        if (existing.isNotEmpty) {
          final previous = existing.first['uid_validity'] as String?;
          if (uidValidityChanged(previous, snapshot.uidValidity)) {
            await txn.delete(
              'mail_messages',
              where: 'user_id = ? AND folder_id = ?',
              whereArgs: [userId, id],
            );
          }
        }
        // 快照没带 UIDVALIDITY 时保留原值。
        //
        // 写空值会把已知基准抹掉：下一次头部同步拿到真实值时，本地是 null，
        // 会被当成首次同步而跳过清理，于是新摘要盖在旧正文上。
        // 只有拿到明确的新值才更新，没有就保持原样。
        final nextUidValidity =
            (snapshot.uidValidity == null || snapshot.uidValidity!.isEmpty)
            ? (existing.isEmpty
                  ? null
                  : existing.first['uid_validity'] as String?)
            : snapshot.uidValidity;
        final values = {
          'id': id,
          'user_id': userId,
          'account_id': accountId,
          'path': snapshot.path,
          'name': snapshot.name,
          'special_use': snapshot.specialUse,
          'uid_validity': nextUidValidity,
          'total': snapshot.total,
          'unread': snapshot.unread,
          'synced_at_utc': timestamp,
        };
        if (existing.isEmpty) {
          await txn.insert('mail_folders', values);
        } else {
          await txn.update(
            'mail_folders',
            values,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      if (complete) {
        // 完整快照语义：没出现在这次结果里的文件夹就是不存在了。
        // 空列表同样是有效快照——服务端把文件夹全删了，本地必须跟着清。
        if (kept.isEmpty) {
          await txn.delete(
            'mail_folders',
            where: 'user_id = ? AND account_id = ?',
            whereArgs: [userId, accountId],
          );
        } else {
          final placeholders = List.filled(kept.length, '?').join(',');
          await txn.delete(
            'mail_folders',
            where:
                'user_id = ? AND account_id = ? AND id NOT IN ($placeholders)',
            whereArgs: [userId, accountId, ...kept],
          );
        }
      }
    });
    notifyListeners();
  }

  /// 两个 UIDVALIDITY 是否构成「服务端重建了 UID 空间」。
  ///
  /// 任一方为空时无法判断，按未变化处理：宁可多留缓存，
  /// 也不能因为服务端没报 UIDVALIDITY 就误删用户的邮件。
  static bool uidValidityChanged(String? previous, String? next) {
    if (previous == null || next == null) {
      return false;
    }
    if (previous.isEmpty || next.isEmpty) {
      return false;
    }
    return previous != next;
  }

  /// 记录文件夹新的 UIDVALIDITY。
  ///
  /// 与 [replaceFolders] 分开，是因为头部同步只拿到 UIDVALIDITY、
  /// 拿不到完整的文件夹元数据；不记录的话下次同步会重复判定为变化。
  Future<void> updateFolderUidValidity(
    String folderId,
    String uidValidity,
  ) async {
    await _database.update(
      'mail_folders',
      {'uid_validity': uidValidity},
      where: 'id = ? AND user_id = ?',
      whereArgs: [folderId, userId],
    );
  }

  // ---------------------------------------------------------------- messages

  /// 列表页只读摘要，不加载正文。
  Future<List<MailMessageSummary>> listMessages({
    required String folderId,
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _database.query(
      'mail_messages',
      columns: [
        'id',
        'account_id',
        'folder_id',
        'uid',
        'message_id',
        'subject',
        'sender_name',
        'sender_address',
        'sent_at_utc',
        'seen',
        'flagged',
        'has_attachments',
        'snippet',
        'size',
        'observed_at_utc',
      ],
      where: 'user_id = ? AND folder_id = ?',
      whereArgs: [userId, folderId],
      orderBy: 'sent_at_utc DESC, uid DESC',
      limit: limit,
      offset: offset,
    );
    final folder = await _folderPathById(folderId);
    return rows.map((row) => _summaryFromRow(row, folderPath: folder)).toList();
  }

  Future<MailMessageDetail?> messageById(String id) async {
    final rows = await _database.rawQuery(
      '''
SELECT m.*, f.path AS folder_path
FROM mail_messages m
JOIN mail_folders f ON f.id = m.folder_id
WHERE m.id = ? AND m.user_id = ?
LIMIT 1
''',
      [id, userId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _detailFromRow(rows.first);
  }

  Future<MailMessageDetail?> messageByUid({
    required String folderId,
    required int uid,
  }) async {
    final rows = await _database.rawQuery(
      '''
SELECT m.*, f.path AS folder_path
FROM mail_messages m
JOIN mail_folders f ON f.id = m.folder_id
WHERE m.user_id = ? AND m.folder_id = ? AND m.uid = ?
LIMIT 1
''',
      [userId, folderId, uid],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _detailFromRow(rows.first);
  }

  /// 写入邮件摘要。正文留空，打开邮件时再写 [saveBody]。
  Future<MailMessageSummary> upsertSummary(MailMessageSummary summary) async {
    if (summary.accountId.isEmpty) {
      throw const MailException(MailErrorCodes.protocol, '缺少账户标识');
    }
    final timestamp = _millisecondsOf(_now().toUtc());
    final existing = await _database.query(
      'mail_messages',
      columns: ['id'],
      where: 'user_id = ? AND folder_id = ? AND uid = ?',
      whereArgs: [userId, summary.folderId, summary.uid],
      limit: 1,
    );
    final values = {
      'id': existing.isEmpty
          ? (summary.id.isEmpty ? _uuid.v4() : summary.id)
          : existing.first['id'] as String,
      'user_id': userId,
      'account_id': summary.accountId,
      'folder_id': summary.folderId,
      'uid': summary.uid,
      'message_id': summary.messageId,
      'subject': summary.subject,
      'sender_name': summary.sender?.name,
      'sender_address': summary.sender?.address,
      'sent_at_utc': _nullableMillisecondsOf(summary.sentAtUtc),
      'seen': summary.seen ? 1 : 0,
      'flagged': summary.flagged ? 1 : 0,
      'has_attachments': summary.hasAttachments ? 1 : 0,
      'snippet': summary.snippet,
      'size': summary.size,
      'observed_at_utc': timestamp,
    };
    if (existing.isEmpty) {
      await _database.insert('mail_messages', values);
    } else {
      await _database.update(
        'mail_messages',
        values,
        where: 'id = ?',
        whereArgs: [values['id']],
      );
    }
    notifyListeners();
    final saved = await messageByUid(
      folderId: summary.folderId,
      uid: summary.uid,
    );
    return saved ?? summary;
  }

  /// 保存已下载的正文与附件清单。
  Future<void> saveBody({
    required String messageId,
    String? bodyText,
    String? bodyHtml,
    List<MailAddress> to = const [],
    List<MailAddress> cc = const [],
    List<MailAttachmentInfo> attachments = const [],
  }) async {
    final timestamp = _millisecondsOf(_now().toUtc());
    final changed = await _database.update(
      'mail_messages',
      {
        'body_text': bodyText,
        'body_html': bodyHtml,
        'to_addresses': jsonEncode(to.map((a) => a.toJson()).toList()),
        'cc_addresses': jsonEncode(cc.map((a) => a.toJson()).toList()),
        'attachments': jsonEncode(attachments.map((a) => a.toJson()).toList()),
        'has_attachments': attachments.isEmpty ? 0 : 1,
        'body_fetched_at_utc': timestamp,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [messageId, userId],
    );
    if (changed == 0) {
      throw const MailException(MailErrorCodes.protocol, '邮件不存在');
    }
    notifyListeners();
  }

  Future<void> setSeen(String messageId, {required bool seen}) async {
    await _database.update(
      'mail_messages',
      {'seen': seen ? 1 : 0},
      where: 'id = ? AND user_id = ?',
      whereArgs: [messageId, userId],
    );
    notifyListeners();
  }

  /// 从本地缓存删除邮件。只删本机副本，不动服务器。
  Future<void> deleteMessage(String messageId) async {
    await _database.delete(
      'mail_messages',
      where: 'id = ? AND user_id = ?',
      whereArgs: [messageId, userId],
    );
    notifyListeners();
  }

  /// 清空一个文件夹的本地邮件缓存。
  ///
  /// 服务端 UIDVALIDITY 变化时 UID 空间整体重建，旧缓存全部作废；
  /// 保留摘要会让界面把不同邮件显示成同一封。
  Future<int> clearFolderMessages(String folderId) async {
    final changed = await _database.delete(
      'mail_messages',
      where: 'user_id = ? AND folder_id = ?',
      whereArgs: [userId, folderId],
    );
    if (changed > 0) {
      notifyListeners();
    }
    return changed;
  }

  /// 文件夹里已缓存的最大 UID，用于增量同步的起点。
  Future<int> highestUid(String folderId) async {
    final rows = await _database.rawQuery(
      'SELECT MAX(uid) AS uid FROM mail_messages WHERE user_id = ? AND folder_id = ?',
      [userId, folderId],
    );
    final value = rows.isEmpty ? null : rows.first['uid'];
    return value is int ? value : 0;
  }

  // ------------------------------------------------------------------ drafts

  Future<List<MailDraft>> listDrafts({String? accountId}) async {
    final rows = await _database.query(
      'mail_drafts',
      where: accountId == null
          ? 'user_id = ?'
          : 'user_id = ? AND account_id = ?',
      whereArgs: accountId == null ? [userId] : [userId, accountId],
      orderBy: 'updated_at_utc DESC',
    );
    return rows.map(_draftFromRow).toList();
  }

  Future<MailDraft?> draftById(String id) async {
    final rows = await _database.query(
      'mail_drafts',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : _draftFromRow(rows.first);
  }

  /// 新建草稿。空草稿不落库，返回内存对象。
  Future<MailDraft> createDraft({
    required String accountId,
    String recipientText = '',
    String subject = '',
    String bodyText = '',
    String bodyHtml = '',
    String? inReplyTo,
    List<MailDraftAttachment> attachments = const [],
  }) async {
    final timestamp = _now().toUtc();
    final draft = MailDraft(
      id: _uuid.v4(),
      userId: userId,
      accountId: accountId,
      recipientText: recipientText,
      subject: subject,
      bodyText: bodyText,
      bodyHtml: bodyHtml,
      inReplyTo: inReplyTo,
      attachments: attachments,
      createdAtUtc: timestamp,
      updatedAtUtc: timestamp,
    );
    return draft;
  }

  /// 保存草稿。`editing`/`failed` 状态都会持久化，重开时可继续编辑。
  Future<MailDraft> saveDraft(MailDraft draft) async {
    _validateDraft(draft);
    if (draft.userId != userId) {
      throw const MailException(MailErrorCodes.protocol, '不能保存其他用户的草稿');
    }
    final timestamp = _millisecondsOf(_now().toUtc());
    final values = {
      'id': draft.id,
      'user_id': userId,
      'account_id': draft.accountId,
      'recipient_text': draft.recipientText,
      'subject': draft.subject,
      'body_text': draft.bodyText,
      'body_html': draft.bodyHtml,
      'in_reply_to': draft.inReplyTo,
      'attachments': jsonEncode(
        draft.attachments.map((a) => a.toJson()).toList(),
      ),
      'send_state': draft.sendState.name,
      'last_error_code': draft.lastErrorCode,
      'last_error_message': draft.lastErrorMessage,
      'created_at_utc': _millisecondsOf(draft.createdAtUtc),
      'updated_at_utc': timestamp,
    };
    final existing = await draftById(draft.id);
    if (existing == null) {
      await _database.insert('mail_drafts', values);
    } else {
      await _database.update(
        'mail_drafts',
        values,
        where: 'id = ? AND user_id = ?',
        whereArgs: [draft.id, userId],
      );
    }
    notifyListeners();
    return (await draftById(draft.id))!;
  }

  /// 标记发送中。发送前先落库，崩溃后可恢复为 `failed`。
  Future<void> markSending(String draftId) async {
    await _updateDraftState(draftId, MailSendState.sending);
  }

  /// 发送失败：保留正文与附件选择，只记录错误。
  ///
  /// 这是验收里「发送失败保留编辑内容和附件选择」的落点。
  Future<void> markSendFailed(
    String draftId, {
    required String code,
    required String message,
  }) async {
    await _database.update(
      'mail_drafts',
      {
        'send_state': MailSendState.failed.name,
        'last_error_code': code,
        'last_error_message': message,
        'updated_at_utc': _millisecondsOf(_now().toUtc()),
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [draftId, userId],
    );
    notifyListeners();
  }

  Future<void> markSent(String draftId) async {
    await _updateDraftState(draftId, MailSendState.sent);
  }

  /// 启动时把遗留的 `sending` 恢复成 `failed`。
  ///
  /// 上次进程在发送中被杀掉时，草稿会卡在 `sending`；重开应用后
  /// 既不能重试也无法判断是否已发出，这里统一降级为可重试状态并说明原因。
  Future<int> recoverInterruptedSends() async {
    final changed = await _database.update(
      'mail_drafts',
      {
        'send_state': MailSendState.failed.name,
        'last_error_code': MailErrorCodes.unavailable,
        'last_error_message': '上次发送被中断，请确认后重新发送',
        'updated_at_utc': _millisecondsOf(_now().toUtc()),
      },
      where: 'user_id = ? AND send_state = ?',
      whereArgs: [userId, MailSendState.sending.name],
    );
    if (changed > 0) {
      notifyListeners();
    }
    return changed;
  }

  Future<void> deleteDraft(String draftId) async {
    await _database.delete(
      'mail_drafts',
      where: 'id = ? AND user_id = ?',
      whereArgs: [draftId, userId],
    );
    notifyListeners();
  }

  // ----------------------------------------------------------------- helpers

  Future<void> _updateDraftState(String draftId, MailSendState state) async {
    final changed = await _database.update(
      'mail_drafts',
      {
        'send_state': state.name,
        'updated_at_utc': _millisecondsOf(_now().toUtc()),
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [draftId, userId],
    );
    if (changed == 0) {
      throw const MailException(MailErrorCodes.protocol, '草稿不存在');
    }
    notifyListeners();
  }

  void _validateDraft(MailDraft draft) {
    if (draft.subject.runes.length > maxSubjectLength) {
      throw const MailException(MailErrorCodes.draftTooLarge, '主题不能超过 500 个字符');
    }
    if (draft.recipientText.runes.length > maxRecipientTextLength) {
      throw const MailException(
        MailErrorCodes.draftTooLarge,
        '收件人不能超过 20000 个字符',
      );
    }
    if (draft.bodyText.runes.length > maxBodyLength ||
        draft.bodyHtml.runes.length > maxBodyLength) {
      throw const MailException(
        MailErrorCodes.draftTooLarge,
        '正文不能超过 2000000 个字符',
      );
    }
  }

  Future<String> _folderPathById(String folderId) async {
    final rows = await _database.query(
      'mail_folders',
      columns: ['path'],
      where: 'id = ? AND user_id = ?',
      whereArgs: [folderId, userId],
      limit: 1,
    );
    return rows.isEmpty ? '' : rows.first['path'] as String;
  }

  MailAccount _accountFromRow(Map<String, Object?> row) {
    return MailAccount(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      address: row['address'] as String,
      displayName: row['display_name'] as String?,
      server: MailServerConfig(
        imapHost: row['imap_host'] as String,
        imapPort: row['imap_port'] as int,
        smtpHost: row['smtp_host'] as String,
        smtpPort: row['smtp_port'] as int,
      ),
      createdAtUtc: _dateTimeOf(row['created_at_utc'] as int),
      updatedAtUtc: _dateTimeOf(row['updated_at_utc'] as int),
      lastConnectedAtUtc: _nullableDateTimeOf(row['last_connected_at_utc']),
      lastErrorCode: row['last_error_code'] as String?,
      lastErrorMessage: row['last_error_message'] as String?,
    );
  }

  MailFolder _folderFromRow(Map<String, Object?> row) {
    return MailFolder(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      accountId: row['account_id'] as String,
      path: row['path'] as String,
      name: row['name'] as String,
      specialUse: row['special_use'] as String?,
      uidValidity: row['uid_validity'] as String?,
      total: row['total'] as int?,
      unread: row['unread'] as int?,
      syncedAtUtc: _nullableDateTimeOf(row['synced_at_utc']),
    );
  }

  MailMessageSummary _summaryFromRow(
    Map<String, Object?> row, {
    required String folderPath,
  }) {
    final name = row['sender_name'] as String?;
    final address = row['sender_address'] as String?;
    return MailMessageSummary(
      id: row['id'] as String,
      accountId: row['account_id'] as String,
      folderId: row['folder_id'] as String,
      folderPath: folderPath,
      uid: row['uid'] as int,
      messageId: row['message_id'] as String?,
      subject: row['subject'] as String?,
      sender: (name == null && address == null)
          ? null
          : MailAddress(name: name, address: address),
      sentAtUtc: _nullableDateTimeOf(row['sent_at_utc']),
      seen: (row['seen'] as int) != 0,
      flagged: (row['flagged'] as int) != 0,
      hasAttachments: (row['has_attachments'] as int) != 0,
      snippet: row['snippet'] as String?,
      size: row['size'] as int?,
      observedAtUtc: _dateTimeOf(row['observed_at_utc'] as int),
    );
  }

  MailMessageDetail _detailFromRow(Map<String, Object?> row) {
    final name = row['sender_name'] as String?;
    final address = row['sender_address'] as String?;
    return MailMessageDetail(
      id: row['id'] as String,
      accountId: row['account_id'] as String,
      folderId: row['folder_id'] as String,
      folderPath: row['folder_path'] as String? ?? '',
      uid: row['uid'] as int,
      messageId: row['message_id'] as String?,
      subject: row['subject'] as String?,
      sender: (name == null && address == null)
          ? null
          : MailAddress(name: name, address: address),
      sentAtUtc: _nullableDateTimeOf(row['sent_at_utc']),
      seen: (row['seen'] as int) != 0,
      flagged: (row['flagged'] as int) != 0,
      hasAttachments: (row['has_attachments'] as int) != 0,
      snippet: row['snippet'] as String?,
      size: row['size'] as int?,
      observedAtUtc: _dateTimeOf(row['observed_at_utc'] as int),
      to: _addressListOf(row['to_addresses']),
      cc: _addressListOf(row['cc_addresses']),
      bodyText: row['body_text'] as String?,
      bodyHtml: row['body_html'] as String?,
      attachments: _attachmentListOf(row['attachments']),
      bodyFetchedAtUtc: _nullableDateTimeOf(row['body_fetched_at_utc']),
    );
  }

  MailDraft _draftFromRow(Map<String, Object?> row) {
    return MailDraft(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      accountId: row['account_id'] as String,
      recipientText: row['recipient_text'] as String,
      subject: row['subject'] as String,
      bodyText: row['body_text'] as String,
      bodyHtml: row['body_html'] as String,
      inReplyTo: row['in_reply_to'] as String?,
      attachments: _draftAttachmentListOf(row['attachments']),
      sendState: MailSendState.values.firstWhere(
        (state) => state.name == row['send_state'],
        orElse: () => MailSendState.editing,
      ),
      lastErrorCode: row['last_error_code'] as String?,
      lastErrorMessage: row['last_error_message'] as String?,
      createdAtUtc: _dateTimeOf(row['created_at_utc'] as int),
      updatedAtUtc: _dateTimeOf(row['updated_at_utc'] as int),
    );
  }

  List<MailAddress> _addressListOf(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(MailAddress.fromJson)
        .toList();
  }

  List<MailAttachmentInfo> _attachmentListOf(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(MailAttachmentInfo.fromJson)
        .toList();
  }

  List<MailDraftAttachment> _draftAttachmentListOf(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(MailDraftAttachment.fromJson)
        .toList();
  }

  static int _millisecondsOf(DateTime value) =>
      value.toUtc().millisecondsSinceEpoch;

  static int? _nullableMillisecondsOf(DateTime? value) =>
      value == null ? null : _millisecondsOf(value);

  static DateTime _dateTimeOf(int value) =>
      DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);

  static DateTime? _nullableDateTimeOf(Object? value) =>
      value is int ? _dateTimeOf(value) : null;
}
