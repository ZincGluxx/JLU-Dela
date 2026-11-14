import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 邮箱凭据的读写边界。
///
/// 上层只依赖这个接口，测试可以注入内存实现；生产实现是
/// [MailCredentialStore]，落在平台安全存储里。
abstract interface class MailSecretStore {
  Future<String?> read(String userId, String accountId);

  Future<void> write(String userId, String accountId, String secret);

  Future<void> delete(String userId, String accountId);
}

/// 邮箱凭据的安全存储边界。
///
/// 只保存邮箱密码 / 授权码，不进入 SQLite、不进日志、不上传服务端，
/// 也不进入个人备份（见 `docs/local-data.md` 与 `开发完整内容.md` 的授权原则）。
///
/// 键格式 `jlu_dela.mail.<userId>.<accountId>.credential`：带应用用户 ID，
/// 切号后读不到上一账号的凭据；带邮箱账号 ID，同一应用账号下的多个邮箱
/// 各自独立。单独用 `jlu_dela.mail.<account>` 无法表达应用账号隔离。
class MailCredentialStore implements MailSecretStore {
  MailCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'jlu_dela.mail';
  static const _suffix = 'credential';

  /// 首版合并进 main 时用的后缀。读取时兜底迁移，见 [read]。
  static const _legacySuffix = 'secret';

  final FlutterSecureStorage _storage;

  /// 当前键格式，公开出来便于运维核对与测试断言。
  static String keyFor(String userId, String accountId) =>
      '$_prefix.$userId.$accountId.$_suffix';

  String _key(String userId, String accountId) => keyFor(userId, accountId);

  String _legacyKey(String userId, String accountId) =>
      '$_prefix.$userId.$accountId.$_legacySuffix';

  /// 读取凭据。旧键（`.secret`）有值时顺手迁移到新键并删除旧键。
  ///
  /// 迁移是幂等的：搬完旧键就没了，下次直接命中新键。
  @override
  Future<String?> read(String userId, String accountId) async {
    final current = await _storage.read(key: _key(userId, accountId));
    if (current != null) {
      return current;
    }
    final legacyKey = _legacyKey(userId, accountId);
    final legacy = await _storage.read(key: legacyKey);
    if (legacy == null) {
      return null;
    }
    await _storage.write(key: _key(userId, accountId), value: legacy);
    await _storage.delete(key: legacyKey);
    return legacy;
  }

  @override
  Future<void> write(String userId, String accountId, String secret) =>
      _storage.write(key: _key(userId, accountId), value: secret);

  /// 删除凭据。新旧两个键都清，避免迁移残留读到旧值。
  @override
  Future<void> delete(String userId, String accountId) async {
    await _storage.delete(key: _key(userId, accountId));
    await _storage.delete(key: _legacyKey(userId, accountId));
  }
}
