import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 邮箱凭据的安全存储边界。
///
/// 只保存邮箱密码 / 授权码，不进入 SQLite、不进日志、不上传服务端，
/// 也不进入个人备份（见 `docs/local-data.md` 与 `开发完整内容.md` 的授权原则）。
/// key 带 userId，避免切号后读到上一账号的凭据。
class MailCredentialStore {
  MailCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'jlu_dela.mail';

  final FlutterSecureStorage _storage;

  String _key(String userId, String accountId) =>
      '$_prefix.$userId.$accountId.secret';

  Future<String?> read(String userId, String accountId) =>
      _storage.read(key: _key(userId, accountId));

  Future<void> write(String userId, String accountId, String secret) =>
      _storage.write(key: _key(userId, accountId), value: secret);

  Future<void> delete(String userId, String accountId) =>
      _storage.delete(key: _key(userId, accountId));
}
