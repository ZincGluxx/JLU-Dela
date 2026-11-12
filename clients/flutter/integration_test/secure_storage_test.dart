import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jlu_dela/core/auth/refresh_token_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('round-trips the refresh token through secure storage', (
    tester,
  ) async {
    final store = SecureRefreshTokenStore();
    addTearDown(store.clear);

    await store.clear();
    expect(await store.read(), isNull);

    await store.write('integration-test-refresh-token');
    expect(await store.read(), 'integration-test-refresh-token');

    await store.clear();
    expect(await store.read(), isNull);
  });
}
