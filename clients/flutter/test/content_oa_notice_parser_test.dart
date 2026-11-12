import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/features/content/content_html.dart';
import 'package:jlu_dela/features/content/oa_notice_parser.dart';

const _channel = '179577';
final _nowUtc = DateTime.utc(2026, 11, 8, 4);

String noticeRow({
  required String id,
  String channel = _channel,
  String title = '示例通知',
  String department = '示例单位',
  String published = '2026-11-06',
  bool pinned = false,
  String? href,
}) {
  final pinnedMarkup = pinned ? '<font>[置顶]</font>' : '';
  final link =
      href ??
      'PortalInformation!getInformation.action?id=$id&channelId=$channel';
  return '<div class="li"><a class="font14" href="$link">$pinnedMarkup$title</a>'
      '<a class="column">$department</a>'
      '<span class="time">$published</span></div>';
}

String listPage({
  required String rows,
  String footer = '',
  String extra = '',
}) =>
    '<html><body><div id="itemContainer">$rows</div>$footer$extra</body></html>';

String detailPage({
  String title = '关于示例工作的通知',
  String metadata = '2026-10-30 09:30 示例单位',
  String body = '<p>正文</p>',
  String attachments = '',
}) =>
    '<html><body><div class="content_t">$title</div>'
    '<div class="content_time">$metadata</div>'
    '<div class="content_font">$body</div>$attachments</body></html>';

OaNoticeSummary singleNotice(String published, {bool pinned = false}) {
  final page = const OaNoticeParser().parseList(
    listPage(
      rows: noticeRow(id: '1001', published: published, pinned: pinned),
    ),
    nowUtc: _nowUtc,
  );
  return page.items.single;
}

OaNoticeSummary summary(String id, String title, String? department) {
  return OaNoticeSummary(
    id: id,
    channel: _channel,
    title: title,
    department: department,
    sourceUrl:
        'https://oa.jlu.edu.cn/defaultroot/PortalInformation!getInformation.action'
        '?id=$id&channelId=$_channel',
    published: OaPublishedTime.parse('2026-11-06', nowUtc: _nowUtc),
  );
}

void main() {
  group('通知列表', () {
    test('解析来源标识、标题、组织、置顶与分页', () {
      final page = const OaNoticeParser().parseList(
        listPage(
          rows:
              noticeRow(id: '1001', pinned: true) +
              noticeRow(id: '1002', department: '教务处', published: '2026-11-07'),
          footer: '<div class="pages">第 1 /25 页 共 750 条记录</div>',
        ),
        nowUtc: _nowUtc,
      );

      expect(page.page, 1);
      expect(page.totalPages, 25);
      expect(page.totalCount, 750);
      expect(page.hasNextPage, isTrue);
      expect(page.isScopeComplete, isFalse);
      expect(page.items, hasLength(2));

      final first = page.items.first;
      expect(first.id, '1001');
      expect(first.channel, _channel);
      expect(first.title, '示例通知');
      expect(first.pinned, isTrue);
      expect(first.department, '示例单位');
      expect(
        first.sourceUrl,
        'https://oa.jlu.edu.cn/defaultroot/PortalInformation!getInformation.action'
        '?id=1001&channelId=179577',
      );

      expect(page.items.last.id, '1002');
      expect(page.items.last.department, '教务处');
      expect(page.items.last.pinned, isFalse);
    });

    test('同一页支持重复解析且请求页与总页数分离', () {
      const parser = OaNoticeParser();
      final html = listPage(
        rows: noticeRow(id: '1001'),
        footer: '<div class="pages">第 2 / 5 页</div>',
      );

      final second = parser.parseList(html, nowUtc: _nowUtc, page: 2);
      expect(second.page, 2);
      expect(second.totalPages, 5);
      expect(second.hasNextPage, isTrue);

      final fifth = parser.parseList(html, nowUtc: _nowUtc, page: 5);
      expect(fifth.isScopeComplete, isTrue);
      expect(fifth.hasNextPage, isFalse);
    });

    test('识别来源认可的两种空结果，拒绝未知空列表', () {
      const parser = OaNoticeParser();
      final searchEmpty = parser.parseList(
        '<html><body><form id="gjzForm2"><input id="searchnr">'
        '<select id="searchlx"></select><div id="itemContainer">\n\t</div>'
        '</form></body></html>',
        nowUtc: _nowUtc,
      );
      expect(searchEmpty.items, isEmpty);
      expect(searchEmpty.totalPages, 1);
      expect(searchEmpty.totalCount, 0);
      expect(searchEmpty.isScopeComplete, isTrue);

      final zeroRecords = parser.parseList(
        '<html><body><div id="itemContainer"></div>'
        '<div>共 0 条记录</div></body></html>',
        nowUtc: _nowUtc,
      );
      expect(zeroRecords.items, isEmpty);
      expect(zeroRecords.totalPages, 1);

      expect(
        () => parser.parseList(
          listPage(rows: '', footer: '<div>没有找到相关记录</div>'),
          nowUtc: _nowUtc,
        ),
        throwsA(isA<OaNoticeLayoutException>()),
      );
      expect(
        () => parser.parseList(
          '<html><body><h1>服务维护</h1></body></html>',
          nowUtc: _nowUtc,
        ),
        throwsA(isA<OaNoticeLayoutException>()),
      );
    });

    test('缺少条目标识或标题时拒绝解析，不用占位数据补全', () {
      const parser = OaNoticeParser();
      expect(
        () => parser.parseList(
          listPage(
            rows:
                '<div class="li"><a class="font14" href="?id=abc">示例</a>'
                '</div>',
          ),
          nowUtc: _nowUtc,
        ),
        throwsA(isA<OaNoticeLayoutException>()),
      );
      expect(
        () => parser.parseList(
          listPage(
            rows:
                '<div class="li"><a class="font14" '
                'href="?id=1001&channelId=179577"></a></div>',
          ),
          nowUtc: _nowUtc,
        ),
        throwsA(isA<OaNoticeLayoutException>()),
      );
    });
  });

  group('发布时间三精度', () {
    test('明确日期时刻转为 UTC，日期与原文保留', () {
      final notice = singleNotice('2026-10-30 09:30');
      expect(notice.publishedPrecision, OaNoticePublishedPrecision.exact);
      expect(notice.publishedAtUtc, DateTime.utc(2026, 10, 30, 1, 30));
      expect(notice.publishedDate, isNull);
      expect(notice.publishedText, '2026-10-30 09:30');
    });

    test('只有日期时保留 published_date 与 published_text', () {
      final notice = singleNotice('2026-10-30');
      expect(notice.publishedPrecision, OaNoticePublishedPrecision.dateOnly);
      expect(notice.publishedAtUtc, isNull);
      expect(notice.publishedDate, '2026-10-30');
      expect(notice.publishedText, '2026-10-30');
    });

    test('缺少可识别时间时保留原文，不伪造日期或时刻', () {
      final empty = singleNotice('');
      expect(empty.publishedPrecision, OaNoticePublishedPrecision.unknown);
      expect(empty.publishedAtUtc, isNull);
      expect(empty.publishedDate, isNull);
      expect(empty.publishedText, isNull);

      final textOnly = singleNotice('服务维护');
      expect(textOnly.publishedPrecision, OaNoticePublishedPrecision.unknown);
      expect(textOnly.publishedText, '服务维护');

      final yearless = singleNotice('10-30');
      expect(yearless.publishedPrecision, OaNoticePublishedPrecision.unknown);
      expect(yearless.publishedDate, isNull);
      expect(yearless.publishedText, '10-30');

      final invalid = singleNotice('2026-02-31');
      expect(invalid.publishedPrecision, OaNoticePublishedPrecision.unknown);
      expect(invalid.publishedDate, isNull);
    });

    test('今天/昨天按校园时区解析，保留来源原文', () {
      final today = singleNotice('今天 09:30');
      expect(today.publishedPrecision, OaNoticePublishedPrecision.exact);
      expect(today.publishedAtUtc, DateTime.utc(2026, 11, 8, 1, 30));
      expect(today.publishedText, '今天 09:30');

      final yesterday = singleNotice('昨天');
      expect(yesterday.publishedPrecision, OaNoticePublishedPrecision.dateOnly);
      expect(yesterday.publishedDate, '2026-11-07');
      expect(yesterday.publishedText, '昨天');
    });

    test('跨校园零点时今天指向上海的当天', () {
      final lateNightUtc = DateTime.utc(2026, 10, 30, 17);
      final page = const OaNoticeParser().parseList(
        listPage(
          rows: noticeRow(id: '1001', published: '今天 09:30'),
        ),
        nowUtc: lateNightUtc,
      );
      expect(page.items.single.publishedDate, isNull);
      expect(
        page.items.single.publishedAtUtc,
        DateTime.utc(2026, 10, 31, 1, 30),
      );
    });
  });

  group('搜索、组织筛选与排序', () {
    final notices = <OaNoticeSummary>[
      summary('1001', '关于开展奖学金评审的通知', '本科生院'),
      summary('1002', '关于选课工作的通知', '教务处'),
      summary('1003', '奖学金公示 Notice', '研究生院'),
      summary('1004', '示例通知', null),
    ];

    test('标题关键词不区分大小写，组合组织为精确匹配', () {
      expect(filterOaNotices(notices, query: '奖学金').map((row) => row.id), [
        '1001',
        '1003',
      ]);
      expect(filterOaNotices(notices, query: 'notice').map((row) => row.id), [
        '1003',
      ]);
      expect(
        filterOaNotices(
          notices,
          query: '奖学金',
          organization: '本科生院',
        ).map((row) => row.id),
        ['1001'],
      );
      expect(
        filterOaNotices(notices, query: '选课', organization: '研究生院'),
        isEmpty,
      );
    });

    test('空条件返回全部同步缓存，超长关键词拒绝', () {
      expect(filterOaNotices(notices), hasLength(4));
      expect(filterOaNotices(notices, query: '   '), hasLength(4));
      expect(
        () => filterOaNotices(notices, query: 'a' * 201),
        throwsArgumentError,
      );
    });

    test('按发布时间降序，未知时间排最后，同时间按 id', () {
      OaNoticeSummary timed(String id, String published) => OaNoticeSummary(
        id: id,
        channel: _channel,
        title: '通知$id',
        sourceUrl: 'https://oa.jlu.edu.cn/notice/$id',
        published: OaPublishedTime.parse(published, nowUtc: _nowUtc),
      );

      final sorted = sortOaNotices(<OaNoticeSummary>[
        timed('3', '2026-11-01'),
        timed('1', ''),
        timed('2', '2026-11-08 10:00'),
        timed('0', '2026-11-09'),
        timed('4', '2026-11-06'),
      ]);
      expect(sorted.map((row) => row.id), ['0', '2', '4', '3', '1']);

      final tied = sortOaNotices(<OaNoticeSummary>[
        timed('b', '2026-11-06'),
        timed('a', '2026-11-06'),
      ]);
      expect(tied.map((row) => row.id), ['a', 'b']);
    });

    test('组织选项去重并保持稳定排序', () {
      final organizations = oaNoticeOrganizations(notices);
      expect(organizations.toSet().length, organizations.length);
      expect(organizations, unorderedEquals(<String>['本科生院', '教务处', '研究生院']));
    });

    test('分页范围完整性只在取到总页数后成立', () {
      expect(
        oaNoticeRangeComplete(fetchedThroughPage: 24, totalPages: 25),
        isFalse,
      );
      expect(
        oaNoticeRangeComplete(fetchedThroughPage: 25, totalPages: 25),
        isTrue,
      );
      expect(
        oaNoticeRangeComplete(fetchedThroughPage: 1, totalPages: null),
        isFalse,
      );
    });
  });

  group('通知正文与附件', () {
    test('清洗 HTML 为纯文本并保留组织与发布时间', () {
      final detail = const OaNoticeParser().parseDetail(
        detailPage(
          body:
              '<p>第一段&nbsp;正文&amp;说明</p>'
              '<script>ignored()</script><p>第二段&nbsp; 续</p>',
        ),
        id: '1001',
        nowUtc: _nowUtc,
      );

      expect(detail.title, '关于示例工作的通知');
      expect(detail.metadataText, '2026-10-30 09:30 示例单位');
      expect(detail.published.precision, OaNoticePublishedPrecision.exact);
      expect(detail.published.atUtc, DateTime.utc(2026, 10, 30, 1, 30));
      expect(detail.text, '第一段 正文&说明\n第二段 续');
      expect(
        detail.sourceUrl,
        'https://oa.jlu.edu.cn/defaultroot/PortalInformation!getInformation.action'
        '?id=1001&channelId=179577',
      );
      expect(detail.attachments, isEmpty);
    });

    test('正文缺失或附件来源异常时拒绝整条通知', () {
      const parser = OaNoticeParser();
      expect(
        () => parser.parseDetail(
          '<html><body><div class="content_font">正文</div></body></html>',
          id: '1001',
          nowUtc: _nowUtc,
        ),
        throwsA(isA<OaNoticeLayoutException>()),
      );
      expect(
        () => parser.parseDetail(
          detailPage(attachments: '<a href="javascript:download(1)">附件</a>'),
          id: '1001',
          nowUtc: _nowUtc,
        ),
        throwsA(isA<OaNoticeLayoutException>()),
      );
      expect(
        () => parser.parseDetail(
          detailPage(
            attachments: '<a href="https://evil.example/download?res=1">附件</a>',
          ),
          id: '1001',
          nowUtc: _nowUtc,
        ),
        throwsA(isA<OaNoticeLayoutException>()),
      );
      expect(
        () => parser.parseDetail(
          detailPage(
            attachments: '<span onclick="downloadthis(this)">附件</span>',
          ),
          id: '1001',
          nowUtc: _nowUtc,
        ),
        throwsA(isA<OaNoticeLayoutException>()),
      );
    });

    test('解析普通下载链接与学校脚本附件入口，id 稳定', () {
      final detail = const OaNoticeParser().parseDetail(
        detailPage(
          attachments:
              '<a href="/defaultroot/rd/download/attachdownload.jsp'
              '?res=test">附表</a>'
              '<span id="test.pdf" title="示例.pdf" '
              'onclick="downloadthis(this)">示例.pdf</span>',
        ),
        id: '1001',
        nowUtc: _nowUtc,
      );

      expect(detail.attachments, hasLength(2));
      final download = detail.attachments.first;
      expect(download.id, 'download:test');
      expect(download.name, '附表');
      expect(download.downloadable, isTrue);
      expect(
        download.sourcePath,
        '/defaultroot/rd/download/attachdownload.jsp?res=test',
      );
      expect(download.elementId, isNull);

      final scripted = detail.attachments.last;
      expect(scripted.id, 'element:test.pdf');
      expect(scripted.name, '示例.pdf');
      expect(scripted.downloadable, isTrue);
      expect(scripted.elementId, 'test.pdf');
      expect(scripted.sourcePath, isNull);
    });

    test('附件只来自当前通知正文，不跨通知复用', () {
      const parser = OaNoticeParser();
      final first = parser.parseDetail(
        detailPage(
          title: '通知一',
          attachments:
              '<a href="/download/attachdownload.jsp?res=first">附件一</a>',
        ),
        id: '1001',
        nowUtc: _nowUtc,
      );
      final second = parser.parseDetail(
        detailPage(title: '通知二', metadata: '2026-10-31', body: '<p>正文</p>'),
        id: '1002',
        nowUtc: _nowUtc,
      );

      expect(first.attachments.map((row) => row.id), ['download:first']);
      expect(second.attachments, isEmpty);
      expect(first.sourceUrl, isNot(second.sourceUrl));
      expect(first.id, isNot(second.id));
    });

    test('只有图片的正文不产出 OCR 文本', () {
      final detail = const OaNoticeParser().parseDetail(
        detailPage(
          title: '扫描件通知',
          metadata: '',
          body: '<img src="notice.png" alt="扫描正文">',
        ),
        id: '1001',
        nowUtc: _nowUtc,
      );
      expect(detail.text, isEmpty);
    });
  });

  group('HTML 清洗', () {
    test('解码常见实体与数字实体', () {
      expect(
        htmlToPlainText('<p>标题&nbsp;A &amp; B &lt;标签&gt; &#39;引号&#x4E2D;文</p>'),
        "标题 A & B <标签> '引号中文",
      );
      expect(
        htmlToPlainText('<p>&ldquo;通知&rdquo;&hellip;&mdash;示例</p>'),
        '\u201c通知\u201d\u2026\u2014示例',
      );
      expect(htmlToPlainText('<p>未知 &unknown; 保留</p>'), '未知 &unknown; 保留');
    });

    test('块级元素分段、脚本与样式不计入正文', () {
      expect(htmlToPlainText('<div>第一行</div><div>第二行</div>'), '第一行\n第二行');
      expect(htmlToPlainText('<p>正文<script>ignored()</script></p>'), '正文');
      expect(htmlToPlainText('<style>.x{}</style><p>正文</p>'), '正文');
      expect(
        htmlToPlainText('<table><tr><td>甲</td><td>乙</td></tr></table>'),
        '甲 乙',
      );
    });
  });
}
