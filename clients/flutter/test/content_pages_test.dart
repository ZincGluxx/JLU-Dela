import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/source_session.dart';
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

  testWidgets('通知页在窄屏下无布局溢出', (tester) async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    await _seedNotices(harness);
    await _pumpPage(
      tester,
      NoticesPage(
        workspace: harness.workspaceFor('user-a'),
        store: harness.storeFor('user-a'),
      ),
      size: const Size(390, 844),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('关于奖学金评审的通知'), findsOneWidget);
  });
}
