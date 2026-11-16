import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_workbench.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/features/content/content_store.dart';

import 'support/chaoxing_test_support.dart';

void main() {
  test(
    'unknown source coverage preserves previously cached material entries',
    () async {
      final harness = await ChaoxingHarness.create();
      final data = buildWorkbenchData(
        database: harness.database,
        userId: 'user-a',
        sessions: harness.sessions,
        http: harness.http,
        campusLogin: harness.context.campusLogin,
        browser: harness.browser,
        now: () => DateTime.utc(2026, 11, 16),
      );
      addTearDown(data.dispose);
      final course = await data.workspace.courses.upsert(
        const SourceCourse(
          source: SourceKind.chaoxing,
          sourceScope: 'default',
          sourceId: '100:200',
          name: '示例课程甲',
        ),
      );
      harness.http
        ..on(baseUrl, entryPage())
        ..on(entryUrl, coursesPage())
        ..on(
          'https://mooc1.chaoxing.com/visit/stucoursemiddle'
          '?courseid=100&clazzid=200&enc=fixture',
          courseLandingPage(),
        )
        ..on(materialsFrameUrl, materialListPage());

      final sourcePage = await data.chaoxingStore.listMaterialChildren(
        courseOfferingId: course.id,
      );
      expect(sourcePage.totalPages, isNull);
      final firstRefresh = await data.contentStore.refreshMaterialChildren(
        data.workspace,
        course,
      );
      expect(firstRefresh, isA<SourceSuccess<MaterialRefreshSummary>>());
      final before = await data.contentStore.loadMaterials(course.id);
      expect(before.map((item) => item.sourceRef.sourceId).toSet(), {
        'folder-1',
        'file-1',
      });
      final previousIds = {
        for (final item in before) item.sourceRef.sourceId: item.id,
      };

      harness.http.routes.removeWhere(
        (route) => route.matches(Uri.parse(materialsFrameUrl)),
      );
      harness.http.on(
        materialsFrameUrl,
        materialFolderPage().replaceFirst(
          '</body>',
          '<div class="pages">第 1 / 2 页</div></body>',
        ),
      );
      final partialPage = await data.chaoxingStore.listMaterialChildren(
        courseOfferingId: course.id,
      );
      expect(partialPage.entries.single.id, 'file-2');
      expect(partialPage.totalPages, isNull);

      final refreshed = await data.contentStore.refreshMaterialChildren(
        data.workspace,
        course,
      );
      expect(refreshed, isA<SourceSuccess<MaterialRefreshSummary>>());
      expect(
        (refreshed as SourceSuccess<MaterialRefreshSummary>).value.storedCount,
        1,
      );
      final cached = await data.contentStore.loadMaterials(course.id);
      expect(cached.map((item) => item.sourceRef.sourceId).toSet(), {
        'folder-1',
        'file-1',
        'file-2',
      });
      for (final item in cached) {
        final previousId = previousIds[item.sourceRef.sourceId];
        if (previousId != null) expect(item.id, previousId);
      }
      expect(
        (await data.contentStore.materialSnapshot(course.id)).lastSuccessAtUtc,
        isNotNull,
      );
    },
  );
}
