import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/material.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/chaoxing_access.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/features/content/materials_page.dart';
import 'package:jlu_dela/features/content/notices_page.dart';

import 'content_test_support.dart';

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(1280, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pumpAndSettle();
}

String _noticeListFixture() {
  return noticeListPage(
    rows: [
      noticeRow(
        id: '1001',
        title: '关于奖学金评审的通知',
        department: '本科生院',
        published: '2026-11-08 09:30',
      ),
      noticeRow(
        id: '1002',
        title: '关于选课工作的通知',
        department: '教务处',
        published: '2026-11-07',
      ),
    ].join(),
    totalPages: 1,
    totalCount: 2,
  );
}

String _noticeDetailFixture() {
  return noticeDetailPage(
    title: '示例通知正文标题',
    metadata: '2026-11-08 09:30 示例单位',
    body: '<p>第一段正文</p><p>第二段正文</p>',
    attachments:
        '<a href="/defaultroot/rd/download/attachdownload.jsp?res=test">'
        '附表</a>',
  );
}

Future<void> _seedNotices(ContentHarness harness) async {
  final store = harness.storeFor('user-a');
  final workspace = harness.workspaceFor('user-a');
  harness.http.handler = (request) async => htmlResponse(_noticeListFixture());
  await store.refreshNotices(workspace);
}

void main() {
  testWidgets('点击课程面包屑从多层目录返回课程根目录', (tester) async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final course = await harness.seedCourse('user-a');
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');
    harness.chaoxing.setListing(course.id, entries: sampleFileEntries());
    await store.refreshMaterialChildren(workspace, course);
    final firstFolder = (await store.loadMaterials(course.id)).first;
    harness.chaoxing.setListing(
      course.id,
      parentSourceId: firstFolder.sourceRef.sourceId,
      entries: const [
        MaterialEntry(
          id: 'nested-folder',
          name: '二级文件夹',
          kind: MaterialKind.folder,
          downloadable: false,
        ),
      ],
    );
    await store.refreshMaterialChildren(workspace, course, parent: firstFolder);

    await _pumpPage(tester, MaterialsPage(workspace: workspace, store: store));
    await tester.tap(find.byKey(const Key('material-folder-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('material-nested-folder')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('materials-crumb-nested-folder')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, '示例学习通课程'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('material-folder-1')), findsOneWidget);
    expect(find.byKey(const Key('material-access-file-1')), findsOneWidget);
    expect(find.byKey(const Key('materials-back')), findsNothing);
    expect(find.byKey(const Key('materials-crumb-folder-1')), findsNothing);
  });

  testWidgets('通知列表展示缓存状态，支持标题搜索与组织筛选', (tester) async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    await _seedNotices(harness);
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');

    await _pumpPage(tester, NoticesPage(workspace: workspace, store: store));

    expect(find.text('校园通知'), findsOneWidget);
    expect(find.byKey(const Key('notices-cache-status')), findsOneWidget);
    expect(find.text('关于奖学金评审的通知'), findsOneWidget);
    expect(find.text('关于选课工作的通知'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('notices-search')), '奖学金');
    await tester.pumpAndSettle();
    expect(find.text('关于奖学金评审的通知'), findsOneWidget);
    expect(find.text('关于选课工作的通知'), findsNothing);

    await tester.enterText(find.byKey(const Key('notices-search')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notices-organization')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('教务处').last);
    await tester.pumpAndSettle();
    expect(find.text('关于选课工作的通知'), findsOneWidget);
    expect(find.text('关于奖学金评审的通知'), findsNothing);
  });

  testWidgets('通知详情展示正文与附件，并可返回列表', (tester) async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    await _seedNotices(harness);
    harness.http.handler = (request) async {
      if (request.uri.path.endsWith('jldxList.action')) {
        return htmlResponse(_noticeListFixture());
      }
      return htmlResponse(_noticeDetailFixture());
    };
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');
    harness.connectSession(SourceKind.jluOa);

    await _pumpPage(tester, NoticesPage(workspace: workspace, store: store));
    await tester.tap(find.byKey(const Key('notice-1001')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notices-detail-title')), findsOneWidget);
    expect(find.text('示例通知正文标题'), findsOneWidget);
    expect(find.textContaining('第一段正文'), findsOneWidget);
    expect(
      find.byKey(const Key('notice-attachment-download:test')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('notice-attachment-download:test')));
    await tester.pumpAndSettle();
    expect(find.text('电子校务 · 来源页面'), findsOneWidget);
    expect(find.textContaining('attachdownload.jsp'), findsOneWidget);

    await tester.tap(find.byKey(const Key('content-access-open')));
    await tester.pumpAndSettle();
    expect(harness.browser.opened, hasLength(1));
    expect(harness.browser.opened.single.source, SourceKind.jluOa);
    expect(
      harness.browser.opened.single.uri.toString(),
      contains('attachdownload.jsp'),
    );

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notices-back')));
    await tester.pumpAndSettle();
    expect(find.text('关于奖学金评审的通知'), findsOneWidget);
  });

  testWidgets('通知刷新失败保留旧缓存并展示来源错误', (tester) async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    await _seedNotices(harness);
    harness.http.handler = (request) async =>
        SourceResponse(statusCode: 503, body: '服务暂时不可用');
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');

    await _pumpPage(tester, NoticesPage(workspace: workspace, store: store));
    await tester.tap(find.byKey(const Key('notices-refresh')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notices-error')), findsOneWidget);
    expect(find.text('关于奖学金评审的通知'), findsOneWidget);
    expect(find.byKey(const Key('notices-cache-status')), findsOneWidget);
  });

  testWidgets('通知空缓存状态提供刷新与来源登录入口', (tester) async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');

    await _pumpPage(tester, NoticesPage(workspace: workspace, store: store));
    expect(find.textContaining('尚未同步通知'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notices-connect')));
    await tester.pumpAndSettle();
    expect(harness.campusLogin.attempted, <SourceKind>[SourceKind.jluOa]);
    expect(find.byKey(const Key('notices-source-message')), findsOneWidget);
  });

  testWidgets('资料页展示课程目录、文件夹导航与访问入口', (tester) async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final course = await harness.seedCourse('user-a');
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');
    harness.connectSession(SourceKind.chaoxing);
    harness.chaoxing.setListing(course.id, entries: sampleFileEntries());
    harness.chaoxing.accesses['file-1'] = SourceAccess(
      uri: Uri.parse(
        'https://mooc1.chaoxing.com/coursedata/downloadData?dataId=file-1',
      ),
      mode: SourceAccessMode.sourcePage,
      requiresSourceSession: true,
    );
    await store.refreshMaterialChildren(workspace, course);

    await _pumpPage(tester, MaterialsPage(workspace: workspace, store: store));
    expect(find.text('课程资料'), findsOneWidget);
    expect(find.text('示例学习通课程'), findsWidgets);
    expect(find.text('示例文件夹'), findsOneWidget);
    expect(find.text('示例资料.pdf'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('material-access-file-2')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('material-access-file-1')));
    await tester.pumpAndSettle();
    expect(find.text('学习通 · 来源页面'), findsOneWidget);
    expect(find.textContaining('mooc1.chaoxing.com'), findsOneWidget);
    await tester.tap(find.byKey(const Key('content-access-open')));
    await tester.pumpAndSettle();
    expect(harness.browser.opened, hasLength(1));
    expect(harness.browser.opened.single.source, SourceKind.chaoxing);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    harness.chaoxing.setListing(
      course.id,
      parentSourceId: 'folder-1',
      entries: const <MaterialEntry>[
        MaterialEntry(
          id: 'child-1',
          name: '子文件.pdf',
          kind: MaterialKind.file,
          downloadable: true,
        ),
      ],
    );
    final folder = (await store.loadMaterials(course.id)).first;
    await store.refreshMaterialChildren(workspace, course, parent: folder);
    await tester.tap(find.text('示例文件夹'));
    await tester.pumpAndSettle();
    expect(find.text('子文件.pdf'), findsOneWidget);
    expect(find.byKey(const Key('materials-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('materials-back')));
    await tester.pumpAndSettle();
    expect(find.text('示例资料.pdf'), findsOneWidget);
  });

  testWidgets('资料页无课程与来源登录状态可区分', (tester) async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');

    await _pumpPage(tester, MaterialsPage(workspace: workspace, store: store));
    expect(find.textContaining('尚未同步学习通课程'), findsWidgets);

    await tester.tap(find.byKey(const Key('materials-connect')));
    await tester.pumpAndSettle();
    expect(harness.campusLogin.attempted, <SourceKind>[SourceKind.chaoxing]);
    expect(find.byKey(const Key('materials-source-message')), findsOneWidget);
  });

  testWidgets('通知与资料页在窄屏下无布局溢出', (tester) async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final course = await harness.seedCourse('user-a');
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');
    await _seedNotices(harness);
    harness.chaoxing.setListing(course.id, entries: sampleFileEntries());
    await store.refreshMaterialChildren(workspace, course);

    await _pumpPage(
      tester,
      NoticesPage(workspace: workspace, store: store),
      size: const Size(390, 844),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('关于奖学金评审的通知'), findsOneWidget);

    await _pumpPage(
      tester,
      MaterialsPage(workspace: workspace, store: store),
      size: const Size(390, 844),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('示例文件夹'), findsOneWidget);
  });
}
