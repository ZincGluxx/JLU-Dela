import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/auth/session_scope.dart';

import 'support/session_test_support.dart';

void main() {
  testWidgets('public context observes the same controller across accounts', (
    tester,
  ) async {
    final gateway = FakeAuthGateway(onFetchMe: (_) async => testUser());
    final session = SessionController(
      gateway: gateway,
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              final shared = SessionScope.of(context);
              expect(identical(shared, session), isTrue);
              return Text(shared.currentUser?.id ?? 'signed-out');
            },
          ),
        ),
      ),
    );
    expect(find.text('signed-out'), findsOneWidget);
    await session.signIn(testCredentials());
    await tester.pump();
    expect(find.text('user-a'), findsOneWidget);
    gateway.onFetchMe = (_) async => testUser(id: 'user-b');
    await session.signIn(testCredentials(accessToken: 'access-b'));
    await tester.pump();
    expect(find.text('user-b'), findsOneWidget);
    await session.invalidateSession();
    await tester.pump();
    expect(find.text('signed-out'), findsOneWidget);
  });
}
