import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_workbench.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_portal.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/features/teaching/teaching_page.dart';

import 'support/local_database_test_support.dart';
import 'teaching_test_support.dart';

final DateTime _now = DateTime.utc(2026, 9, 16, 12);

T _value<T>(SourceResult<T> result) {
  return switch (result) {
    SourceSuccess<T>(:final value) => value,
    SourceFailed<T>(:final failure) => fail(
      'unexpected source failure: ${failure.code} ${failure.message}',
    ),
  };
}

({Widget widget, WorkbenchData data}) _harness(
  LocalDatabase database, {
  SourceHttpClient? http,
  CampusLogin? campusLogin,
  double textScale = 1,
}) {
  final sessions = SourceSessionRegistry();
  final data = buildWorkbenchData(
    database: database,
    userId: 'user-a',
    sessions: sessions,
    http: http ?? teachingHttp(),
    campusLogin: campusLogin ?? FakeCampusLogin(),
    browser: const UnsupportedSourcePageOpener(),
    now: () => _now,
  );
  addTearDown(data.dispose);
  return (
    widget: MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: TeachingPage(
          workspace: data.workspace,
          store: data.teachingStore,
        ),
      ),
    ),
    data: data,
  );
}

Finder _gridLessonBlocks() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('teaching-lesson-grid-');
  });
}

Finder _listLessonBlocks() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('teaching-lesson-list-');
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('HarmonyOS Sans SC')
      ..addFont(rootBundle.load('assets/fonts/HarmonyOS_Sans_SC_Regular.ttf'));
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  late LocalDatabase database;

  for (final width in [390.0, 1280.0]) {
    testWidgets('teaching responsive capture $width and 2x text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final harness = _harness(database);
      _value(await harness.data.teachingStore.syncCurrentSemester());
      _value(
        await harness.data.teachingStore.refreshSemester(
          semesterCode: '2026-2027-1',
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(key: const Key('capture'), child: harness.widget),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture')),
      );
      final image = (await tester.runAsync(() => boundary.toImage()))!;
      final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      final file = File('../../.local/research/teaching-${width.toInt()}.png');
      await tester.runAsync(() async {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(_harness(database, textScale: 2).widget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  setUp(() async {
    database = await openTestDatabase();
  });

  tearDown(() => database.close());

  testWidgets('shows an honest empty state before the first sync', (
    tester,
  ) async {
    final harness = _harness(database);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(find.text('还没有本地课表'), findsOneWidget);
    expect(find.byKey(const Key('teaching-sync-empty')), findsOneWidget);
    expect(find.byKey(const Key('teaching-login')), findsOneWidget);
    expect(find.textContaining('来源未连接'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('syncs the current semester and renders the desktop grid', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = _harness(database);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teaching-sync-empty')));
    await tester.pumpAndSettle();

    expect(find.text('2026-2027 秋季学期'), findsWidgets);
    expect(find.text('示例课程'), findsOneWidget);
    expect(find.textContaining('上次成功'), findsOneWidget);
    expect(_gridLessonBlocks(), findsOneWidget);
    expect(_listLessonBlocks(), findsNothing);
    expect(find.text('教务课表 · 第 1 / 20 周'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the daily list on a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = _harness(database);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teaching-sync-empty')));
    await tester.pumpAndSettle();

    expect(_listLessonBlocks(), findsOneWidget);
    expect(_gridLessonBlocks(), findsNothing);
    expect(find.text('示例课程'), findsOneWidget);
    expect(find.textContaining('示例教室'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigates teaching weeks without fabricating lessons', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = _harness(database);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('teaching-sync-empty')));
    await tester.pumpAndSettle();

    expect(find.text('教务课表 · 第 1 / 20 周'), findsOneWidget);
    await tester.tap(find.byKey(const Key('teaching-week-next')));
    await tester.pumpAndSettle();

    expect(find.text('教务课表 · 第 2 / 20 周'), findsOneWidget);
    expect(find.byKey(const Key('teaching-empty-week')), findsOneWidget);
    expect(find.text('第 2 周暂无课程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows the campus login result without signing the workbench out',
    (tester) async {
      final harness = _harness(
        database,
        campusLogin: FakeCampusLogin(connected: false, message: '校园登录未接入'),
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('teaching-login')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('teaching-login-message')), findsOneWidget);
      expect(find.text('校园登录未接入'), findsOneWidget);
      expect(find.text('还没有本地课表'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows an auth-required error while keeping the empty local state',
    (tester) async {
      final harness = _harness(
        database,
        http: teachingHttp(unauthorized: true),
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('teaching-sync-empty')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('teaching-error')), findsOneWidget);
      expect(find.textContaining('教务登录已失效'), findsOneWidget);
      expect(find.textContaining('重新登录教务来源'), findsOneWidget);
      expect(find.byKey(const Key('teaching-empty-week')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switches between stored semesters', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = _harness(database);
    final store = harness.data.teachingStore;
    final autumn = teachingHttp(
      courses: <Map<String, Object?>>[teachingCourse(name: '秋季课程')],
    );
    _value(await store.syncCurrentSemester(http: autumn));
    _value(
      await store.refreshSemester(http: autumn, semesterCode: '2026-2027-1'),
    );
    final spring = teachingHttp(
      semesterCode: '2026-2027-2',
      courses: <Map<String, Object?>>[teachingCourse(name: '春季课程')],
      calendar: teachingCalendar(startsOn: '2027-02-22 00:00:00'),
    );
    _value(await store.syncCurrentSemester(http: spring));
    _value(
      await store.refreshSemester(http: spring, semesterCode: '2026-2027-2'),
    );

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(find.text('2026-2027 春季学期'), findsWidgets);
    expect(find.text('春季课程'), findsOneWidget);
    expect(find.byKey(const Key('teaching-semester')), findsOneWidget);

    await tester.tap(find.byKey(const Key('teaching-semester')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-2027 秋季学期').last);
    await tester.pumpAndSettle();

    expect(find.text('2026-2027 秋季学期'), findsWidgets);
    expect(find.text('秋季课程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
