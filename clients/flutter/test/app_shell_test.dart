import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/app/app.dart';
import 'package:jlu_dela/app/app_shell.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/api/diagnostics_service.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';

import 'support/session_test_support.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    Size size = const Size(1280, 900),
    Map<AppDestination, AppPageBuilder> pages = const {},
    AppDestination initial = AppDestination.calendar,
    bool glassEnabled = true,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _ShellHarness(pages: pages, initial: initial, glassEnabled: glassEnabled),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop sidebar reaches every destination', (tester) async {
    await pumpShell(tester);

    expect(find.byKey(const Key('desktop-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('mobile-navigation')), findsNothing);
    for (final destination in AppDestination.values) {
      expect(
        find.byKey(Key('destination-${destination.name}')),
        findsOneWidget,
      );
    }
    expect(find.text('此功能尚未开放'), findsOneWidget);

    await tester.tap(find.byKey(const Key('destination-teaching')));
    await tester.pumpAndSettle();

    expect(_pageTitle(tester), '工作台 / 课表');
    expect(find.text('此功能尚未开放'), findsOneWidget);
  });

  testWidgets('tablet keeps the narrower sidebar', (tester) async {
    await pumpShell(tester, size: const Size(820, 1180));

    expect(find.byKey(const Key('desktop-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('mobile-navigation')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('desktop-sidebar'))).width, 184);

    await pumpShell(tester, size: const Size(1024, 768));

    expect(tester.getSize(find.byKey(const Key('desktop-sidebar'))).width, 184);
  });

  testWidgets('mobile bottom bar and more menu reach secondary destinations', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(390, 844));

    expect(find.byKey(const Key('desktop-sidebar')), findsNothing);
    expect(find.byKey(const Key('mobile-navigation')), findsOneWidget);
    for (final destination in AppShell.mobileDestinations) {
      expect(
        find.byKey(Key('destination-${destination.name}')),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const Key('destination-assignments')));
    await tester.pumpAndSettle();
    expect(_pageTitle(tester), '作业');

    await tester.tap(find.byKey(const Key('mobile-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课程资料'));
    await tester.pumpAndSettle();

    expect(_pageTitle(tester), '课程资料');
    expect(find.text('此功能尚未开放'), findsOneWidget);
    final moreIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('mobile-more')),
        matching: find.byType(Icon),
      ),
    );
    expect(moreIcon.color, AppTheme.primary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a feature module can register its own page', (tester) async {
    await pumpShell(
      tester,
      pages: {
        AppDestination.teaching: (context) =>
            const Center(child: Text('业务模块课表页')),
      },
    );

    await tester.tap(find.byKey(const Key('destination-teaching')));
    await tester.pumpAndSettle();

    expect(find.text('业务模块课表页'), findsOneWidget);
    expect(find.text('此功能尚未开放'), findsNothing);
  });

  testWidgets(
    'the application composes extra pages without changing the shell',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = DiagnosticsService(
        apiBaseUri: Uri.parse('http://127.0.0.1:8080'),
        httpClient: MockClient((request) async => http.Response('', 404)),
        clientVersionLoader: () async => '0.1.0',
      );
      final session = SessionController(
        gateway: FakeAuthGateway(onFetchMe: (_) async => testUser()),
        refreshTokenStore: MemoryRefreshTokenStore(),
      );
      await session.signIn(testCredentials());

      await tester.pumpWidget(
        JluDelaApp(
          diagnosticsService: service,
          session: session,
          pages: {
            AppDestination.calendar: (context) =>
                const Center(child: Text('业务模块日历页')),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('业务模块日历页'), findsOneWidget);
    },
  );

  testWidgets('large text keeps navigation and content reachable', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpShell(tester, size: const Size(390, 844));

    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('mobile-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('校园通知'));
    await tester.pumpAndSettle();
    expect(_pageTitle(tester), '校园通知');
    expect(tester.takeException(), isNull);

    await pumpShell(tester, size: const Size(1280, 900));
    await tester.tap(find.byKey(const Key('destination-settings')));
    await tester.pumpAndSettle();
    expect(_pageTitle(tester), '工作台 / 设置与连接');
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass and solid modes keep the same layout', (tester) async {
    await pumpShell(tester, size: const Size(1280, 900));
    final glassSidebar = tester.getRect(
      find.byKey(const Key('desktop-sidebar')),
    );
    final glassToolbar = tester.getRect(find.byKey(const Key('app-toolbar')));
    final glassPage = tester.getRect(find.byKey(const Key('app-page')));

    await pumpShell(tester, size: const Size(1280, 900), glassEnabled: false);

    expect(
      tester.getRect(find.byKey(const Key('desktop-sidebar'))),
      glassSidebar,
    );
    expect(tester.getRect(find.byKey(const Key('app-toolbar'))), glassToolbar);
    expect(tester.getRect(find.byKey(const Key('app-page'))), glassPage);

    await pumpShell(tester, size: const Size(390, 844));
    final mobileNav = tester.getRect(
      find.byKey(const Key('mobile-navigation')),
    );
    final mobilePage = tester.getRect(find.byKey(const Key('app-page')));

    await pumpShell(tester, size: const Size(390, 844), glassEnabled: false);

    expect(
      tester.getRect(find.byKey(const Key('mobile-navigation'))),
      mobileNav,
    );
    expect(tester.getRect(find.byKey(const Key('app-page'))), mobilePage);
  });

  testWidgets('resizing the window switches layouts', (tester) async {
    await pumpShell(tester);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mobile-navigation')), findsOneWidget);
    expect(find.byKey(const Key('desktop-sidebar')), findsNothing);

    await tester.binding.setSurfaceSize(const Size(820, 1180));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('mobile-navigation')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing across the breakpoint preserves an unsaved draft', (
    tester,
  ) async {
    await pumpShell(
      tester,
      pages: {AppDestination.calendar: (context) => const TextField()},
    );
    await tester.enterText(find.byType(TextField), '未保存的课程笔记');
    final editorState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );

    for (final width in [767.0, 768.0, 390.0, 1280.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpAndSettle();

      expect(find.text('未保存的课程笔记'), findsOneWidget);
      expect(tester.state(find.byType(EditableText)), same(editorState));
      expect(
        find.byKey(Key(width >= 768 ? 'desktop-sidebar' : 'mobile-navigation')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'destinations with the same page type have separate draft state',
    (tester) async {
      await pumpShell(
        tester,
        pages: {
          AppDestination.calendar: (context) => const TextField(),
          AppDestination.teaching: (context) => const TextField(),
        },
      );
      await tester.enterText(find.byType(TextField), '日历草稿');
      final calendarEditor = tester.state(find.byType(EditableText));

      await tester.tap(find.byKey(const Key('destination-teaching')));
      await tester.pumpAndSettle();

      expect(find.text('日历草稿'), findsNothing);
      expect(
        tester.state(find.byType(EditableText)),
        isNot(same(calendarEditor)),
      );
      await tester.enterText(find.byType(TextField), '课表草稿');
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
      expect(find.text('课表草稿'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the selected destination is exposed to semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpShell(tester);

    expect(
      tester
              .getSemantics(find.byKey(const Key('destination-calendar')))
              .flagsCollection
              .isSelected ==
          ui.Tristate.isTrue,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('destination-assignments')));
    await tester.pumpAndSettle();

    expect(
      tester
              .getSemantics(find.byKey(const Key('destination-calendar')))
              .flagsCollection
              .isSelected ==
          ui.Tristate.isFalse,
      isTrue,
    );
    expect(
      tester
              .getSemantics(find.byKey(const Key('destination-assignments')))
              .flagsCollection
              .isSelected ==
          ui.Tristate.isTrue,
      isTrue,
    );
    handle.dispose();
  });
}

String _pageTitle(WidgetTester tester) {
  final text = tester.widget<Text>(find.byKey(const Key('app-page-title')));
  return text.textSpan?.toPlainText() ?? text.data ?? '';
}

class _ShellHarness extends StatefulWidget {
  const _ShellHarness({
    required this.pages,
    required this.initial,
    required this.glassEnabled,
  });

  final Map<AppDestination, AppPageBuilder> pages;
  final AppDestination initial;
  final bool glassEnabled;

  @override
  State<_ShellHarness> createState() => _ShellHarnessState();
}

class _ShellHarnessState extends State<_ShellHarness> {
  late AppDestination _destination = widget.initial;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: AppShell(
        destination: _destination,
        pages: widget.pages,
        glassEnabled: widget.glassEnabled,
        onDestinationSelected: (destination) {
          setState(() => _destination = destination);
        },
      ),
    );
  }
}
