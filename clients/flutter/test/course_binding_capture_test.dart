import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_workbench.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/features/assignments/assignments_page.dart';
import 'package:jlu_dela/features/assignments/course_binding_store.dart';
import 'package:jlu_dela/features/assignments/chaoxing_store.dart';

import 'support/chaoxing_test_support.dart';

const _captureDirectory = String.fromEnvironment('C_BINDING_CAPTURE_DIR');

void main() {
  testWidgets(
    'captures synthetic course mapping and assignment board',
    (tester) async {
      await (FontLoader('HarmonyOS Sans SC')..addFont(
            rootBundle.load('assets/fonts/HarmonyOS_Sans_SC_Regular.ttf'),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final harness = await ChaoxingHarness.create(
        now: () => DateTime.utc(2026, 11, 3, 2),
      );
      configureSingleCourse(harness.http);
      final data = buildWorkbenchData(
        database: harness.database,
        userId: 'user-a',
        sessions: harness.sessions,
        http: harness.http,
        campusLogin: FakeCampusLogin(),
        browser: harness.browser,
        now: () => DateTime.utc(2026, 11, 3, 2),
      );
      addTearDown(data.dispose);
      final store = ChaoxingStore(
        harness.database,
        'user-a',
        data.workspace.sources,
        data.workspace.courses,
        source: data.workspace.source,
        now: () => DateTime.utc(2026, 11, 3, 2),
      );
      await store.refreshAll();
      final platform = (await store.listCourses()).single;
      final target = await data.workspace.courses.upsert(
        const SourceCourse(
          source: SourceKind.jluIedu,
          sourceScope: '2026-2027-1',
          sourceId: 'kb-1',
          semesterId: 'teaching:user-a:2026-2027-1',
          name: '示例教务课程',
          teacher: '示例教师',
        ),
      );
      await CourseBindingStore(
        harness.database,
        'user-a',
        data.workspace.courses,
      ).bind(platformCourseId: platform.id, teachingCourseId: target.id);
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('capture'),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: AssignmentsPage(workspace: data.workspace, store: store),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final name in ['assignments', 'course-binding']) {
        if (name == 'course-binding') {
          await tester.tap(find.byKey(const Key('assignments-manage-courses')));
          await tester.pumpAndSettle();
          expect(find.text('教务：示例教务课程 · 2026-2027-1'), findsWidgets);
        }
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('capture')),
        );
        final image = (await tester.runAsync(
          () => boundary.toImage(pixelRatio: 1),
        ))!;
        final bytes = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png),
        );
        await tester.runAsync(() async {
          final file = File('$_captureDirectory/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
        image.dispose();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: _captureDirectory.isEmpty,
  );
}
