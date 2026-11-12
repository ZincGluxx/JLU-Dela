import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jlu_dela/core/models/material.dart';
import 'package:jlu_dela/core/models/notice.dart';
import 'package:jlu_dela/core/source/chaoxing_access.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/features/content/content_store.dart';

import 'content_test_support.dart';

void main() {
  test('通知刷新保存三种发布时间精度，失败时保留旧缓存', () async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');
    harness.http.handler = (request) async {
      expect(
        request.uri.path,
        '/defaultroot/PortalInformation!jldxList.action',
      );
      expect(request.uri.queryParameters['channelId'], '179577');
      expect(request.uri.queryParameters['startPage'], '1');
      return htmlResponse(
        noticeListPage(
          rows: [
            noticeRow(id: '1001', published: '2026-11-08 09:30'),
            noticeRow(id: '1002', published: '2026-11-07'),
            noticeRow(id: '1003', published: ''),
          ].join(),
          totalPages: 1,
          totalCount: 3,
        ),
      );
    };

    final refreshed = await store.refreshNotices(workspace);
    expect(refreshed, isA<SourceSuccess<NoticeRefreshSummary>>());
    final summary = (refreshed as SourceSuccess<NoticeRefreshSummary>).value;
    expect(summary.complete, isTrue);
    expect(summary.fetchedPages, 1);
    expect(summary.totalPages, 1);
    expect(summary.storedCount, 3);

    final notices = await store.searchNotices();
    expect(notices.map((notice) => notice.sourceRef.sourceId), <String>[
      '1001',
      '1002',
      '1003',
    ]);
    final exact = notices[0];
    expect(exact.publishedAtUtc, DateTime.utc(2026, 11, 8, 1, 30));
    expect(exact.publishedDate, isNull);
    expect(exact.publishedText, '2026-11-08 09:30');
    final dateOnly = notices[1];
    expect(dateOnly.publishedAtUtc, isNull);
    expect(dateOnly.publishedDate?.toIso8601String(), '2026-11-07');
    expect(dateOnly.publishedText, '2026-11-07');
    final unknown = notices[2];
    expect(unknown.publishedAtUtc, isNull);
    expect(unknown.publishedDate, isNull);
    expect(unknown.publishedText, isNull);

    final status = await store.noticeCacheStatus();
    expect(status.coversAllPages, isTrue);
    expect(status.lastSuccessAtUtc, isNotNull);
    expect(status.fetchedPages, 1);

    harness.http.handler = (request) async =>
        throw http.ClientException('offline');
    final failed = await store.refreshNotices(workspace);
    expect(failed, isA<SourceFailed<NoticeRefreshSummary>>());
    final failure = failed as SourceFailed<NoticeRefreshSummary>;
    expect(failure.failure.code, SourceErrorCodes.sourceNetwork);
    expect(failure.hasCachedData, isTrue);

    final cached = await store.searchNotices();
    expect(cached, hasLength(3));
    final afterFailure = await store.noticeCacheStatus();
    expect(afterFailure.lastSuccessAtUtc, status.lastSuccessAtUtc);
    expect(afterFailure.lastErrorCode, SourceErrorCodes.sourceNetwork);
  });

  test('通知搜索只查已同步缓存，不触发网络请求', () async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');
    harness.http.handler = (request) async => htmlResponse(
      noticeListPage(
        rows: [
          noticeRow(id: '1001', title: '关于开展奖学金评审的通知', department: '本科生院'),
          noticeRow(id: '1002', title: '关于选课工作的通知', department: '教务处'),
          noticeRow(id: '1003', title: 'Notice 示例', department: '研究生院'),
        ].join(),
        totalPages: 1,
      ),
    );
    expect(
      await store.refreshNotices(workspace),
      isA<SourceSuccess<NoticeRefreshSummary>>(),
    );
    expect(harness.http.requests, hasLength(1));

    expect(
      (await store.searchNotices(
        query: '奖学金',
      )).map((notice) => notice.sourceRef.sourceId),
      <String>['1001'],
    );
    expect(
      (await store.searchNotices(
        query: 'notice',
      )).map((notice) => notice.sourceRef.sourceId),
      <String>['1003'],
    );
    expect(
      (await store.searchNotices(
        query: '通知',
        organization: '教务处',
      )).map((notice) => notice.sourceRef.sourceId),
      <String>['1002'],
    );
    expect(await store.searchNotices(query: '不存在的关键词'), isEmpty);
    expect((await store.noticeOrganizations()).toSet(), <String>{
      '本科生院',
      '教务处',
      '研究生院',
    });
    expect(harness.http.requests, hasLength(1));
  });

  test('部分分页刷新保留未抓取的旧通知，不删除缓存', () async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');
    harness.http.handler = (request) async => htmlResponse(
      noticeListPage(
        rows: [
          noticeRow(id: '1001', title: '旧通知一'),
          noticeRow(id: '1002', title: '旧通知二'),
        ].join(),
        totalPages: 1,
      ),
    );
    expect(
      await store.refreshNotices(workspace),
      isA<SourceSuccess<NoticeRefreshSummary>>(),
    );
    expect(await store.listNotices(), hasLength(2));

    harness.http.handler = (request) async {
      final page = int.parse(request.uri.queryParameters['startPage']!);
      if (page == 1) {
        return htmlResponse(
          noticeListPage(
            rows: noticeRow(id: '1003', title: '新通知'),
            totalPages: 25,
            totalCount: 750,
          ),
        );
      }
      return htmlResponse(emptyNoticeListPage(totalPages: 25, totalCount: 750));
    };

    final refreshed = await store.refreshNotices(workspace);
    final summary = (refreshed as SourceSuccess<NoticeRefreshSummary>).value;
    expect(summary.complete, isFalse);
    expect(summary.fetchedPages, 20);
    expect(summary.totalPages, 25);

    final notices = await store.searchNotices();
    expect(notices.map((notice) => notice.sourceRef.sourceId).toSet(), <String>{
      '1001',
      '1002',
      '1003',
    });
    final status = await store.noticeCacheStatus();
    expect(status.coversAllPages, isFalse);
    expect(status.fetchedPages, 20);
    expect(status.lastCompleteAtUtc, isNotNull);
  });

  test('通知正文刷新写入附件；失败保留旧正文与旧附件', () async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');
    harness.http.handler = (request) async {
      if (request.uri.path.endsWith('jldxList.action')) {
        return htmlResponse(
          noticeListPage(
            rows: noticeRow(id: '1001', title: '示例通知'),
            totalPages: 1,
          ),
        );
      }
      return htmlResponse(
        noticeDetailPage(
          title: '示例通知正文标题',
          attachments:
              '<a href="/defaultroot/rd/download/attachdownload.jsp?res=test">'
              '附表</a>'
              '<span id="test.pdf" title="示例.pdf" '
              'onclick="downloadthis(this)">示例.pdf</span>',
        ),
      );
    };

    await store.refreshNotices(workspace);
    final notice = (await store.listNotices()).single;
    final refreshed = await store.refreshNoticeDetail(workspace, notice.id);
    expect(refreshed, isA<SourceSuccess<NoticeDetail>>());
    final detail = (refreshed as SourceSuccess<NoticeDetail>).value;
    expect(detail.title, '示例通知正文标题');
    expect(detail.text, '第一段正文\n第二段正文');
    expect(detail.attachments, hasLength(2));
    expect(detail.attachments.first.id, 'download:test');
    expect(detail.attachments.first.downloadable, isTrue);

    final cachedBefore = await store.loadNoticeDetail(notice.id);
    expect(cachedBefore?.text, '第一段正文\n第二段正文');
    expect(cachedBefore?.attachments, hasLength(2));

    harness.http.handler = (request) async =>
        throw http.ClientException('offline');
    final failed = await store.refreshNoticeDetail(workspace, notice.id);
    expect(failed, isA<SourceFailed<NoticeDetail>>());
    expect((failed as SourceFailed<NoticeDetail>).hasCachedData, isTrue);
    final cachedAfter = await store.loadNoticeDetail(notice.id);
    expect(cachedAfter?.text, cachedBefore?.text);
    expect(cachedAfter?.attachments, hasLength(2));
  });

  test('附件访问校验通知归属，返回来源页面且不接受跨来源地址', () async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');
    harness.http.handler = (request) async {
      if (request.uri.path.endsWith('jldxList.action')) {
        return htmlResponse(
          noticeListPage(
            rows: noticeRow(id: '1001', title: '示例通知'),
            totalPages: 1,
          ),
        );
      }
      return htmlResponse(
        noticeDetailPage(
          attachments:
              '<a href="/defaultroot/rd/download/attachdownload.jsp?res=test">'
              '附表</a>'
              '<span id="test.pdf" title="示例.pdf" '
              'onclick="downloadthis(this)">示例.pdf</span>',
        ),
      );
    };
    await store.refreshNotices(workspace);
    final notice = (await store.listNotices()).single;
    await store.refreshNoticeDetail(workspace, notice.id);

    final direct = await store.accessNoticeAttachment(
      workspace,
      notice.id,
      'download:test',
    );
    expect(direct.mode, SourceAccessMode.sourcePage);
    expect(
      direct.uri.toString(),
      'https://oa.jlu.edu.cn/defaultroot/rd/download/attachdownload.jsp'
      '?res=test',
    );
    expect(direct.filename, '附表');
    expect(direct.requiresSourceSession, isTrue);

    final scripted = await store.accessNoticeAttachment(
      workspace,
      notice.id,
      'element:test.pdf',
    );
    expect(
      scripted.uri.toString(),
      'https://oa.jlu.edu.cn/defaultroot/PortalInformation!getInformation.action'
      '?id=1001&channelId=179577',
    );

    await expectLater(
      store.accessNoticeAttachment(
        workspace,
        'missing-notice',
        'download:test',
      ),
      throwsA(isA<ContentAccessException>()),
    );
    await expectLater(
      store.accessNoticeAttachment(workspace, notice.id, 'missing-attachment'),
      throwsA(isA<ContentAccessException>()),
    );

    await store.database.database.update(
      'notice_attachments',
      <String, Object?>{'downloadable': 0},
      where: 'user_id = ? AND notice_id = ? AND id = ?',
      whereArgs: <Object?>['user-a', notice.id, 'download:test'],
    );
    await expectLater(
      store.accessNoticeAttachment(workspace, notice.id, 'download:test'),
      throwsA(isA<ContentAccessException>()),
    );
  });

  test('资料目录按课程与父目录缓存，分页合并且完整刷新才清理', () async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final course = await harness.seedCourse('user-a');
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');
    harness.chaoxing.setListing(course.id, entries: sampleFileEntries());

    final refreshed = await store.refreshMaterialChildren(workspace, course);
    expect(refreshed, isA<SourceSuccess<MaterialRefreshSummary>>());
    final root = await store.loadMaterials(course.id);
    expect(root, hasLength(5));
    expect(root.map((material) => material.sourceRef.sourceId), <String>[
      'folder-1',
      'file-1',
      'file-2',
      'file-signed',
      'file-evil',
    ]);
    expect(root[0].kind, MaterialKind.folder);
    expect(root[1].bytes, 12288);
    expect(root[1].downloadable, isTrue);
    expect(root[2].downloadable, isFalse);
    expect(harness.chaoxing.listed, <FakeMaterialRequest>[
      (courseOfferingId: course.id, parentSourceId: null, page: 1),
    ]);

    final folder = root.first;
    harness.chaoxing.setListing(
      course.id,
      parentSourceId: 'folder-1',
      entries: const <MaterialEntry>[
        MaterialEntry(
          id: 'child-1',
          name: '子文件一.pdf',
          kind: MaterialKind.file,
          bytes: 2048,
          downloadable: true,
        ),
      ],
    );
    expect(
      await store.refreshMaterialChildren(workspace, course, parent: folder),
      isA<SourceSuccess<MaterialRefreshSummary>>(),
    );
    expect(
      (await store.loadMaterials(course.id, parentId: folder.id)).single.name,
      '子文件一.pdf',
    );

    harness.chaoxing.setListing(
      course.id,
      parentSourceId: 'folder-1',
      entries: const <MaterialEntry>[
        MaterialEntry(
          id: 'child-2',
          name: '子文件二.pdf',
          kind: MaterialKind.file,
          downloadable: false,
        ),
      ],
      totalPages: 2,
      page: 1,
    );
    harness.chaoxing.setListing(
      course.id,
      parentSourceId: 'folder-1',
      entries: const <MaterialEntry>[
        MaterialEntry(
          id: 'child-3',
          name: '子文件三.pdf',
          kind: MaterialKind.file,
          downloadable: true,
        ),
      ],
      totalPages: 2,
      page: 2,
    );
    expect(
      await store.refreshMaterialChildren(workspace, course, parent: folder),
      isA<SourceSuccess<MaterialRefreshSummary>>(),
    );
    final pagedChildren = await store.loadMaterials(
      course.id,
      parentId: folder.id,
    );
    expect(
      pagedChildren.map((material) => material.sourceRef.sourceId),
      <String>['child-2', 'child-3'],
    );

    harness.chaoxing.setListing(
      course.id,
      entries: const <MaterialEntry>[
        MaterialEntry(
          id: 'file-1',
          name: '仅剩的资料.pdf',
          kind: MaterialKind.file,
          downloadable: true,
        ),
      ],
    );
    expect(
      await store.refreshMaterialChildren(workspace, course),
      isA<SourceSuccess<MaterialRefreshSummary>>(),
    );
    expect(await store.loadMaterials(course.id), hasLength(5));
    expect(
      await store.loadMaterials(course.id, parentId: folder.id),
      hasLength(2),
    );

    harness.chaoxing.setListing(
      course.id,
      entries: const <MaterialEntry>[
        MaterialEntry(
          id: 'file-1',
          name: '仅剩的资料.pdf',
          kind: MaterialKind.file,
          downloadable: true,
        ),
      ],
      totalPages: 1,
    );
    expect(
      await store.refreshMaterialChildren(workspace, course),
      isA<SourceSuccess<MaterialRefreshSummary>>(),
    );
    final locked = await store.loadMaterials(course.id);
    expect(locked, hasLength(1));
    expect(locked.single.sourceRef.sourceId, 'file-1');
    expect(await store.loadMaterials(course.id, parentId: folder.id), isEmpty);
  });

  test('资料刷新失败保留旧缓存，来源会话错误可见', () async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final course = await harness.seedCourse('user-a');
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');
    harness.chaoxing.setListing(course.id, entries: sampleFileEntries());
    await store.refreshMaterialChildren(workspace, course);

    harness.chaoxing.removeListing(course.id);
    final failed = await store.refreshMaterialChildren(workspace, course);
    expect(failed, isA<SourceFailed<MaterialRefreshSummary>>());
    final failure = failed as SourceFailed<MaterialRefreshSummary>;
    expect(failure.failure.code, SourceErrorCodes.sourceAuthRequired);
    expect(failure.hasCachedData, isTrue);
    expect(await store.loadMaterials(course.id), hasLength(5));
  });

  test('资料访问校验归属、文件夹与可下载性，并只接受来源地址', () async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final course = await harness.seedCourse('user-a');
    final store = harness.storeFor('user-a');
    final workspace = harness.workspaceFor('user-a');
    harness.chaoxing.setListing(course.id, entries: sampleFileEntries());
    await store.refreshMaterialChildren(workspace, course);
    final materials = await store.loadMaterials(course.id);
    final folder = materials[0];
    final file = materials[1];
    final signed = materials[3];
    final evil = materials[4];

    harness.chaoxing.accesses['file-1'] = SourceAccess(
      uri: Uri.parse(
        'https://mooc1.chaoxing.com/coursedata/downloadData?dataId=file-1',
      ),
      mode: SourceAccessMode.sourcePage,
      requiresSourceSession: true,
      filename: '示例资料.pdf',
    );
    harness.chaoxing.accesses['file-signed'] = SourceAccess(
      uri: Uri.parse('https://mooc1.chaoxing.com/coursedata/signedData'),
      mode: SourceAccessMode.signedUrl,
      requiresSourceSession: false,
      expiresAtUtc: DateTime.utc(2026, 11, 8, 5),
    );
    harness.chaoxing.accesses['file-evil'] = SourceAccess(
      uri: Uri.parse('https://evil.example/download'),
      mode: SourceAccessMode.sourcePage,
      requiresSourceSession: true,
    );

    final access = await store.accessMaterial(workspace, file.id);
    expect(access.mode, SourceAccessMode.sourcePage);
    expect(access.filename, '示例资料.pdf');
    expect(access.requiresSourceSession, isTrue);
    expect(access.uri.host, 'mooc1.chaoxing.com');
    expect(harness.chaoxing.accessed, <String>['file-1']);

    final signedAccess = await store.accessMaterial(workspace, signed.id);
    expect(signedAccess.mode, SourceAccessMode.signedUrl);
    expect(signedAccess.requiresSourceSession, isFalse);
    expect(signedAccess.expiresAtUtc, DateTime.utc(2026, 11, 8, 5));

    await expectLater(
      store.accessMaterial(workspace, folder.id),
      throwsA(isA<ContentAccessException>()),
    );
    await expectLater(
      store.accessMaterial(workspace, materials[2].id),
      throwsA(isA<ContentAccessException>()),
    );
    await expectLater(
      store.accessMaterial(workspace, evil.id),
      throwsA(isA<ContentAccessException>()),
    );
  });

  test('跨用户隔离：通知、资料与访问入口互不可见', () async {
    final harness = await ContentHarness.open();
    addTearDown(harness.close);
    final courseA = await harness.seedCourse('user-a');
    final storeA = harness.storeFor('user-a');
    final workspaceA = harness.workspaceFor('user-a');
    harness.http.handler = (request) async {
      if (request.uri.path.endsWith('jldxList.action')) {
        return htmlResponse(
          noticeListPage(
            rows: noticeRow(id: '1001', title: '甲用户通知'),
            totalPages: 1,
          ),
        );
      }
      return htmlResponse(
        noticeDetailPage(
          attachments:
              '<a href="/defaultroot/rd/download/attachdownload.jsp?res=test">'
              '附件</a>',
        ),
      );
    };
    harness.chaoxing.setListing(courseA.id, entries: sampleFileEntries());

    await storeA.refreshNotices(workspaceA);
    final noticeA = (await storeA.listNotices()).single;
    await storeA.refreshNoticeDetail(workspaceA, noticeA.id);
    await storeA.refreshMaterialChildren(workspaceA, courseA);

    final storeB = harness.storeFor('user-b');
    final workspaceB = harness.workspaceFor('user-b');
    expect(await storeB.listNotices(), isEmpty);
    expect(await storeB.loadNoticeDetail(noticeA.id), isNull);
    await expectLater(
      storeB.accessNoticeAttachment(workspaceB, noticeA.id, 'download:test'),
      throwsA(isA<ContentAccessException>()),
    );
    expect(await storeB.loadMaterials(courseA.id), isEmpty);
    final materialA = (await storeA.loadMaterials(courseA.id)).first;
    await expectLater(
      storeB.accessMaterial(workspaceB, materialA.id),
      throwsA(isA<ContentAccessException>()),
    );

    expect(await harness.countRows('notices', 'user-a'), 1);
    expect(await harness.countRows('notices', 'user-b'), 0);
    expect(await harness.countRows('materials', 'user-a'), 5);
    expect(await harness.countRows('materials', 'user-b'), 0);
  });
}
