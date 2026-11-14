import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/features/mail/mail_credential_store.dart';

/// 内存版安全存储，模拟平台键值行为。
class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeSecureStorage storage;
  late MailCredentialStore store;

  setUp(() {
    storage = _FakeSecureStorage();
    store = MailCredentialStore(storage: storage);
  });

  test('the key carries both the app user and the mail account', () {
    expect(
      MailCredentialStore.keyFor('user-a', 'account-1'),
      'jlu_dela.mail.user-a.account-1.credential',
    );
  });

  test('a credential is scoped to one user and one account', () async {
    await store.write('user-a', 'account-1', 'secret-a1');
    await store.write('user-a', 'account-2', 'secret-a2');
    await store.write('user-b', 'account-1', 'secret-b1');

    expect(await store.read('user-a', 'account-1'), 'secret-a1');
    expect(await store.read('user-a', 'account-2'), 'secret-a2');
    expect(await store.read('user-b', 'account-1'), 'secret-b1');
    expect(await store.read('user-b', 'account-2'), isNull);
  });

  test('a legacy .secret key is migrated on read and removed', () async {
    storage.values['jlu_dela.mail.user-a.account-1.secret'] = 'old-secret';

    expect(await store.read('user-a', 'account-1'), 'old-secret');
    expect(
      storage.values['jlu_dela.mail.user-a.account-1.credential'],
      'old-secret',
    );
    expect(
      storage.values.containsKey('jlu_dela.mail.user-a.account-1.secret'),
      isFalse,
    );

    // 第二次直接命中新键。
    expect(await store.read('user-a', 'account-1'), 'old-secret');
  });

  test('deleting clears both the current and the legacy key', () async {
    await store.write('user-a', 'account-1', 'current');
    storage.values['jlu_dela.mail.user-a.account-1.secret'] = 'stale';

    await store.delete('user-a', 'account-1');

    expect(await store.read('user-a', 'account-1'), isNull);
    expect(storage.values, isEmpty);
  });

  test('a missing credential reads as null, not an error', () async {
    expect(await store.read('user-a', 'missing'), isNull);
  });
}
