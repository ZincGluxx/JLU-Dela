import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/app/widgets/academic_calendar_status.dart';
import 'package:jlu_dela/app/widgets/teaching_timeline.dart';
import 'package:jlu_dela/app/teaching_calendar_data.dart';
import 'package:jlu_dela/core/academic/academic_calendar_cache.dart';
import 'package:jlu_dela/core/academic/academic_calendar_service.dart';
import 'package:jlu_dela/core/models/local_date.dart';

class _MemoryCache implements AcademicCalendarCache {
  @override
  Future<String?> read(String year) async => null;
  @override
  Future<void> write(String year, String contents) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('HarmonyOS Sans SC')..addFont(
          rootBundle.load('assets/fonts/HarmonyOS_Sans_SC_Regular.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  late Directory captures;
  setUp(() async {
    captures = await Directory.systemTemp.createTemp('academic-calendar-test-');
  });
  tearDown(() async => captures.delete(recursive: true));

  testWidgets('date navigation and detail year selection stay independent', (
    tester,
  ) async {
    final current = File(
      'test/fixtures/official_calendar_2026_2027.json',
    ).readAsStringSync();
    final historical = jsonDecode(current) as Map<String, dynamic>;
    final data = historical['data'] as Map<String, dynamic>;
    data['academic_year'] = '2025-2026';
    data['terms'] = [
      {
        'id': '2025-2026-2',
        'name': '第二学期',
        'start_date': '2026-03-09',
        'end_date': '2026-06-28',
        'teaching_weeks': 16,
      },
    ];
    data['events'] = [];
    final service = AcademicCalendarService(
      apiBaseUri: Uri.parse('https://example.test'),
      httpClient: MockClient(
        (request) async => http.Response(
          request.url.queryParameters['academic_year'] == '2025-2026'
              ? jsonEncode(historical)
              : current,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
      cache: _MemoryCache(),
    );
    addTearDown(service.dispose);
    for (final year in AcademicCalendarService.publishedAcademicYears) {
      await tester.runAsync(() => service.ensureLoaded(year));
    }
    var date = LocalDate(2026, 11, 12);
    late StateSetter changeDate;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              changeDate = setState;
              return AcademicCalendarStatus(
                service: service,
                date: date,
                personalPeriods: const [],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-2027 · 第一学期 · 第 10 教学周'), findsOneWidget);
    changeDate(() => date = LocalDate(2026, 3, 9));
    await tester.pumpAndSettle();
    expect(find.textContaining('2025-2026 · 第二学期 · 第 1 教学周'), findsOneWidget);
    changeDate(() => date = LocalDate(2026, 11, 12));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('academic-calendar-details')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '2025-2026'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-03-09–2026-06-28'), findsOneWidget);
    expect(find.textContaining('2026-2027 · 第一学期 · 第 10 教学周'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-2027 · 第一学期 · 第 10 教学周'), findsOneWidget);
    changeDate(() => date = LocalDate(2030, 3, 9));
    await tester.pumpAndSettle();
    expect(find.text('该日期暂无已发布校历'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets('official calendar details and twelve periods $width', (
      tester,
    ) async {
      final raw = File(
        'test/fixtures/official_calendar_2026_2027.json',
      ).readAsStringSync();
      final service = AcademicCalendarService(
        apiBaseUri: Uri.parse('https://example.test'),
        httpClient: MockClient(
          (_) async => http.Response(
            raw,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        cache: _MemoryCache(),
      );
      addTearDown(service.dispose);
      await tester.runAsync(() => service.load());
      expect(service.snapshot.error, isNull);
      expect(service.currentCalendar!.periods, hasLength(12));
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    AcademicCalendarStatus(
                      service: service,
                      date: LocalDate(2026, 11, 12),
                      personalPeriods: const [],
                    ),
                    TeachingTimelineGrid(
                      days: [
                        for (var i = 0; i < 7; i++)
                          LocalDate(2026, 11, 9).addDays(i),
                      ],
                      today: LocalDate(2026, 11, 12),
                      periods: effectiveTeachingPeriods([], service),
                      lessons: const [],
                      lessonBuilder: (_) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('第 10 教学周'), findsOneWidget);
      expect(find.textContaining('个人教务同步'), findsNothing);
      if (width == 390) {
        await tester.tap(find.byKey(const Key('academic-calendar-details')));
        await tester.pumpAndSettle();
        expect(find.textContaining('考试'), findsWidgets);
        expect(find.textContaining('寒假'), findsWidgets);
        expect(find.byType(SelectableText), findsOneWidget);
      }
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture')),
      );
      final image = (await tester.runAsync(() => boundary.toImage()))!;
      final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      await tester.runAsync(
        () => File(
          '${captures.path}/official-calendar-${width.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List()),
      );
      image.dispose();
      if (width == 390) {
        await tester.ensureVisible(find.byType(SelectableText));
        await tester.pumpAndSettle();
        final bottomImage = (await tester.runAsync(() => boundary.toImage()))!;
        final bottomBytes = await tester.runAsync(
          () => bottomImage.toByteData(format: ui.ImageByteFormat.png),
        );
        await tester.runAsync(
          () => File(
            '${captures.path}/official-calendar-390-source.png',
          ).writeAsBytes(bottomBytes!.buffer.asUint8List()),
        );
        bottomImage.dispose();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
