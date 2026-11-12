import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/api/diagnostics_service.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/source_context.dart';
import 'package:jlu_dela/core/source/source_portal.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/features/settings/settings_page.dart';
import 'package:jlu_dela/features/settings/source_connection_card.dart';

import 'source_fakes.dart';
import 'support/session_test_support.dart';

SourceContext _sourceContext(
  SourceSessionRegistry sessions, {
  CampusLogin? campusLogin,
}) {
  return SourceContext(
    sessions: sessions,
    http: StubSourceHttpClient(),
    campusLogin: campusLogin ?? RecordingCampusLogin(sessions: sessions),
    browser: const UnsupportedSourcePageOpener(),
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  SourceConnectionController? controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SourceConnectionCard(controller: controller),
        ),
      ),
    ),
  );
}

String _statusText(WidgetTester tester, SourceKind source) {
  final text = tester.widget<Text>(
    find.byKey(Key('source-status-${source.databaseValue}')),
  );
  return text.data ?? '';
}

void main() {
  testWidgets('explains that a workbench login is required', (tester) async {
    await _pumpCard(tester, null);

    expect(find.text('登录工作台后可连接校园来源；未登录时不会建立或保留来源会话。'), findsOneWidget);
    expect(find.byKey(const Key('source-connect-jlu_iedu')), findsNothing);
  });

  testWidgets('connects and disconnects through the shared source context', (
    tester,
  ) async {
    final sessions = SourceSessionRegistry();
    final login = RecordingCampusLogin(sessions: sessions);
    await _pumpCard(
      tester,
      SourceConnectionController(
        source: _sourceContext(sessions, campusLogin: login),
      ),
    );

    expect(_statusText(tester, SourceKind.jluIedu), '未连接');
    await tester.tap(find.byKey(const Key('source-connect-jlu_iedu')));
    await tester.pumpAndSettle();

    expect(login.attempted, [SourceKind.jluIedu]);
    expect(_statusText(tester, SourceKind.jluIedu), '已连接');
    expect(_statusText(tester, SourceKind.jluOa), '已连接');
    expect(_statusText(tester, SourceKind.chaoxing), '未连接');
    expect(find.text('已连接教务系统'), findsOneWidget);

    await tester.tap(find.byKey(const Key('source-disconnect-jlu_iedu')));
    await tester.pumpAndSettle();

    expect(_statusText(tester, SourceKind.jluIedu), '未连接');
    expect(_statusText(tester, SourceKind.jluOa), '未连接');
    expect(_statusText(tester, SourceKind.chaoxing), '未连接');
    expect(find.text('已断开教务系统的校园来源会话'), findsOneWidget);
  });

  testWidgets('shows the readable failure message from the login', (
    tester,
  ) async {
    final sessions = SourceSessionRegistry();
    final login = RecordingCampusLogin(
      result: const CampusLoginResult(
        connected: false,
        message: '未能确认学习通登录状态，请完成学校登录后重试',
      ),
    );
    await _pumpCard(
      tester,
      SourceConnectionController(
        source: _sourceContext(sessions, campusLogin: login),
      ),
    );

    await tester.tap(find.byKey(const Key('source-connect-chaoxing')));
    await tester.pumpAndSettle();

    expect(find.text('未能确认学习通登录状态，请完成学校登录后重试'), findsOneWidget);
    expect(_statusText(tester, SourceKind.chaoxing), '未连接');
  });

  testWidgets('keeps the card disabled while the workbench is unavailable', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      SourceConnectionController(
        source: _sourceContext(SourceSessionRegistry()),
        enabled: false,
      ),
    );

    expect(find.byKey(const Key('source-connect-jlu_iedu')), findsNothing);
    expect(find.text('登录工作台后可连接校园来源；未登录时不会建立或保留来源会话。'), findsOneWidget);
  });

  testWidgets('renders inside the settings page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SessionController(
      gateway: FakeAuthGateway(),
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(session.dispose);
    final sessions = SourceSessionRegistry();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SettingsPage(
            diagnosticsService: DiagnosticsService(
              apiBaseUri: Uri.parse('http://127.0.0.1:8080'),
              httpClient: MockClient((request) async => http.Response('', 404)),
              clientVersionLoader: () async => '0.1.0',
              timeout: const Duration(seconds: 1),
            ),
            session: session,
            glassEnabled: true,
            onGlassEnabledChanged: (_) {},
            sourceConnections: SourceConnectionController(
              source: _sourceContext(sessions),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('source-connection-card')), findsOneWidget);
    expect(find.byKey(const Key('source-connect-jlu_iedu')), findsOneWidget);
  });
}
