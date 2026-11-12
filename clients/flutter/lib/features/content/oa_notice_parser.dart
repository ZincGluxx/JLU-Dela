// 来源：app/src/shared/jlu-collectors.ts、app/src/main/jlu/api.ts 的电子校务通知解析语义
// （GPL-3.0-or-later）；改为 Dart 纯解析，发布时间保留来源精度，不伪造缺失的日期或时刻。

import 'content_html.dart';

const _oaNoticeOrigin = 'https://oa.jlu.edu.cn';
const defaultOaNoticeChannel = '179577';

final _digits = RegExp(r'^\d+$');
final _safeIdentifier = RegExp(r'^[A-Za-z0-9_.-]{1,160}$');
final _downloadHref = RegExp(r'attachdownload|download', caseSensitive: false);
final _pagesPattern = RegExp(r'第\s*(\d+)\s*/\s*(\d+)\s*页');
final _recordCountPattern = RegExp(r'共\s*(\d+)\s*条记录');
final _zeroRecordPattern = RegExp(r'共\s*0\s*条记录');
final _pinnedPrefixPattern = RegExp(r'^\[置顶\]\s*');
final _absolutePublishedPattern = RegExp(
  r'^(\d{4})\s*[-/.年]\s*(\d{1,2})\s*[-/.月]\s*(\d{1,2})\s*日?'
  r'(?:\s*(\d{1,2})\s*[:：]\s*(\d{2})(?:\s*[:：]\s*(\d{2}))?)?',
);
final _relativePublishedPattern = RegExp(r'^(今天|昨天)\s*');
final _timePattern = RegExp(
  r'^(\d{1,2})\s*[:：]\s*(\d{2})(?:\s*[:：]\s*(\d{2}))?',
);
final _publishedLabelPattern = RegExp(r'^(?:发布时间|发布日期|时间)\s*[:：]\s*');

enum OaNoticePublishedPrecision { exact, dateOnly, unknown }

class OaPublishedTime {
  const OaPublishedTime._({this.text, this.atUtc, this.date});

  const OaPublishedTime.unknown() : this._();

  factory OaPublishedTime.parse(String? raw, {required DateTime nowUtc}) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return const OaPublishedTime.unknown();
    final match = _matchPublishedAtStart(text, nowUtc);
    return match ?? OaPublishedTime._(text: text);
  }

  final String? text;
  final DateTime? atUtc;
  final String? date;

  OaNoticePublishedPrecision get precision {
    if (atUtc != null) return OaNoticePublishedPrecision.exact;
    if (date != null) return OaNoticePublishedPrecision.dateOnly;
    return OaNoticePublishedPrecision.unknown;
  }

  DateTime? get sortKeyUtc {
    final exact = atUtc;
    if (exact != null) return exact;
    final dateOnly = date;
    if (dateOnly == null) return null;
    final parts = dateOnly.split('-');
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    ).subtract(const Duration(hours: 8));
  }
}

class OaNoticeSummary {
  const OaNoticeSummary({
    required this.id,
    required this.channel,
    required this.title,
    required this.sourceUrl,
    required this.published,
    this.department,
    this.pinned = false,
  });

  final String id;
  final String channel;
  final String title;
  final String? department;
  final bool pinned;
  final OaPublishedTime published;
  final String sourceUrl;

  DateTime? get publishedAtUtc => published.atUtc;
  String? get publishedDate => published.date;
  String? get publishedText => published.text;
  OaNoticePublishedPrecision get publishedPrecision => published.precision;
}

class OaNoticeAttachment {
  const OaNoticeAttachment({
    required this.id,
    required this.name,
    required this.downloadable,
    this.elementId,
    this.sourcePath,
  });

  final String id;
  final String name;
  final bool downloadable;
  final String? elementId;
  final String? sourcePath;
}

class OaNoticeDetail {
  const OaNoticeDetail({
    required this.id,
    required this.channel,
    required this.title,
    required this.sourceUrl,
    required this.metadataText,
    required this.published,
    required this.text,
    required this.attachments,
  });

  final String id;
  final String channel;
  final String title;
  final String sourceUrl;
  final String metadataText;
  final OaPublishedTime published;
  final String text;
  final List<OaNoticeAttachment> attachments;
}

class OaNoticeListPage {
  const OaNoticeListPage({
    required this.channel,
    required this.page,
    required this.totalPages,
    required this.totalCount,
    required this.items,
  });

  final String channel;
  final int page;
  final int? totalPages;
  final int? totalCount;
  final List<OaNoticeSummary> items;

  bool get isEmpty => items.isEmpty;

  bool get hasNextPage => totalPages != null && page < totalPages!;

  bool get isScopeComplete => totalPages != null && page >= totalPages!;
}

class OaNoticeLayoutException implements Exception {
  const OaNoticeLayoutException(this.message);

  final String message;

  @override
  String toString() => 'OaNoticeLayoutException: $message';
}

class OaNoticeParser {
  const OaNoticeParser({this.channel = defaultOaNoticeChannel});

  final String channel;

  OaNoticeListPage parseList(
    String html, {
    required DateTime nowUtc,
    int page = 1,
  }) {
    if (page < 1) {
      throw ArgumentError.value(page, 'page', '通知页码从 1 开始');
    }
    final root = parseHtml(html);
    final container = root.firstById('itemContainer');
    if (container == null) {
      throw const OaNoticeLayoutException('通知列表缺少 itemContainer');
    }
    final body = root.firstByTag('body') ?? root;
    final pagination = _readPagination(body.textContent);
    final anchors = container
        .descendants()
        .where((node) => node.tag == 'a' && node.hasClass('font14'))
        .toList(growable: false);
    if (anchors.isEmpty) {
      final searchForm = root.firstById('gjzForm2');
      final hasSearchForm =
          searchForm != null &&
          searchForm.firstById('searchnr') != null &&
          searchForm.firstById('searchlx') != null;
      final hasZeroRecord = _zeroRecordPattern.hasMatch(body.textContent);
      if (!hasSearchForm && !hasZeroRecord) {
        throw const OaNoticeLayoutException('通知列表为空且缺少来源空结果标记');
      }
      return OaNoticeListPage(
        channel: channel,
        page: page,
        totalPages: pagination.totalPages ?? 1,
        totalCount: pagination.totalCount ?? 0,
        items: const <OaNoticeSummary>[],
      );
    }
    return OaNoticeListPage(
      channel: channel,
      page: page,
      totalPages: pagination.totalPages,
      totalCount: pagination.totalCount,
      items: anchors
          .map((anchor) => _parseSummary(anchor, nowUtc))
          .toList(growable: false),
    );
  }

  OaNoticeDetail parseDetail(
    String html, {
    required String id,
    required DateTime nowUtc,
    String? channel,
  }) {
    if (!_digits.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', '通知标识应为数字');
    }
    final detailChannel = channel ?? this.channel;
    if (!_digits.hasMatch(detailChannel)) {
      throw ArgumentError.value(detailChannel, 'channel', '通知频道应为数字');
    }
    final root = parseHtml(html);
    final titleNode = root.firstByClass('content_t');
    final bodyNode = root.firstByClass('content_font');
    final title = titleNode?.textContent.trim() ?? '';
    if (title.isEmpty || bodyNode == null) {
      throw const OaNoticeLayoutException('通知正文缺少标题或正文');
    }
    final metadata =
        root.firstByClass('content_time')?.textContent.trim() ?? '';
    final published = _matchPublishedAtStart(
      metadata.replaceFirst(_publishedLabelPattern, ''),
      nowUtc,
    );
    return OaNoticeDetail(
      id: id,
      channel: detailChannel,
      title: title,
      sourceUrl: _detailUrl(id, detailChannel),
      metadataText: metadata,
      published: published ?? const OaPublishedTime.unknown(),
      text: htmlNodeToPlainText(bodyNode),
      attachments: _parseAttachments(root),
    );
  }

  OaNoticeSummary _parseSummary(HtmlNode anchor, DateTime nowUtc) {
    final id = _queryValue(anchor.attribute('href'), 'id');
    final channel = _queryValue(anchor.attribute('href'), 'channelId');
    if (id == null || channel == null) {
      throw const OaNoticeLayoutException('通知条目缺少来源标识');
    }
    var title = anchor.textContent.trim();
    final pinned =
        anchor.descendants().any((node) => node.tag == 'font') ||
        title.startsWith('[置顶]');
    title = title.replaceFirst(_pinnedPrefixPattern, '').trim();
    if (title.isEmpty) {
      throw const OaNoticeLayoutException('通知条目缺少标题');
    }
    final row = anchor.closestByClass('li');
    final department = row?.firstByClass('column')?.textContent.trim() ?? '';
    final publishedText = row?.firstByClass('time')?.textContent.trim() ?? '';
    return OaNoticeSummary(
      id: id,
      channel: channel,
      title: title,
      department: department.isEmpty ? null : department,
      pinned: pinned,
      published: OaPublishedTime.parse(publishedText, nowUtc: nowUtc),
      sourceUrl: _detailUrl(id, channel),
    );
  }

  List<OaNoticeAttachment> _parseAttachments(HtmlNode root) {
    final attachments = <OaNoticeAttachment>[];
    for (final node in root.descendants()) {
      if (node.tag != 'a') continue;
      final href = node.attribute('href');
      if (href == null || !_downloadHref.hasMatch(href)) continue;
      final resolved = _resolveOaUri(href);
      if (resolved == null) {
        throw const OaNoticeLayoutException('附件地址不属于电子校务来源');
      }
      attachments.add(
        OaNoticeAttachment(
          id: _downloadId(resolved, attachments.length),
          name: _attachmentName(node),
          downloadable: true,
          sourcePath: resolved.hasQuery
              ? '${resolved.path}?${resolved.query}'
              : resolved.path,
        ),
      );
    }
    for (final node in root.descendants()) {
      if (node.tag != 'span' ||
          node.attribute('onclick')?.trim() != 'downloadthis(this)') {
        continue;
      }
      final elementId = node.attribute('id')?.trim() ?? '';
      if (!_safeIdentifier.hasMatch(elementId)) {
        throw const OaNoticeLayoutException('附件入口缺少稳定标识');
      }
      attachments.add(
        OaNoticeAttachment(
          id: 'element:$elementId',
          name: _titledAttachmentName(node),
          downloadable: true,
          elementId: elementId,
        ),
      );
    }
    return List<OaNoticeAttachment>.unmodifiable(attachments);
  }
}

List<OaNoticeSummary> filterOaNotices(
  Iterable<OaNoticeSummary> notices, {
  String query = '',
  String organization = '',
}) {
  final keyword = query.trim();
  if (keyword.length > 200) {
    throw ArgumentError.value(query, 'query', '通知标题关键词最多 200 个字符');
  }
  final department = organization.trim();
  final lowered = keyword.toLowerCase();
  return notices
      .where((notice) {
        if (department.isNotEmpty && notice.department != department) {
          return false;
        }
        if (lowered.isNotEmpty &&
            !notice.title.toLowerCase().contains(lowered)) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
}

List<OaNoticeSummary> sortOaNotices(Iterable<OaNoticeSummary> notices) {
  final sorted = notices.toList();
  sorted.sort(compareOaNotices);
  return sorted;
}

int compareOaNotices(OaNoticeSummary a, OaNoticeSummary b) {
  final aKey = a.published.sortKeyUtc;
  final bKey = b.published.sortKeyUtc;
  if (aKey == null && bKey != null) return 1;
  if (aKey != null && bKey == null) return -1;
  if (aKey != null && bKey != null) {
    final order = bKey.compareTo(aKey);
    if (order != 0) return order;
  }
  return a.id.compareTo(b.id);
}

List<String> oaNoticeOrganizations(Iterable<OaNoticeSummary> notices) {
  final organizations = <String>{};
  for (final notice in notices) {
    final department = notice.department?.trim() ?? '';
    if (department.isNotEmpty) organizations.add(department);
  }
  final sorted = organizations.toList()..sort();
  return List<String>.unmodifiable(sorted);
}

bool oaNoticeRangeComplete({
  required int fetchedThroughPage,
  required int? totalPages,
}) {
  if (totalPages == null || totalPages < 1) return false;
  return fetchedThroughPage >= totalPages;
}

String _detailUrl(String id, String channel) {
  final uri = Uri.parse(_oaNoticeOrigin).replace(
    path: '/defaultroot/PortalInformation!getInformation.action',
    queryParameters: <String, String>{'id': id, 'channelId': channel},
  );
  return uri.toString();
}

String? _queryValue(String? href, String key) {
  if (href == null) return null;
  final uri = Uri.tryParse(href.trim());
  final value = uri?.queryParameters[key]?.trim();
  if (value == null || !_digits.hasMatch(value)) return null;
  return value;
}

Uri? _resolveOaUri(String href) {
  final value = href.trim();
  if (value.isEmpty) return null;
  final direct = Uri.tryParse(value);
  if (direct == null) return null;
  final resolved = direct.hasScheme
      ? direct
      : Uri.parse('$_oaNoticeOrigin/').resolveUri(direct);
  if (resolved.scheme != 'https' ||
      resolved.host != 'oa.jlu.edu.cn' ||
      resolved.userInfo.isNotEmpty) {
    return null;
  }
  return resolved;
}

String _downloadId(Uri uri, int index) {
  for (final key in const <String>['res', 'fileid', 'fileId', 'id', 'dataId']) {
    final value = uri.queryParameters[key]?.trim();
    if (value != null && _safeIdentifier.hasMatch(value)) {
      return 'download:$value';
    }
  }
  return 'index:$index';
}

String _attachmentName(HtmlNode node) {
  final name = node.textContent.trim();
  if (name.isNotEmpty) return name;
  final title = node.attribute('title')?.trim() ?? '';
  return title.isEmpty ? '附件' : title;
}

String _titledAttachmentName(HtmlNode node) {
  final title = node.attribute('title')?.trim() ?? '';
  if (title.isNotEmpty) return title;
  return _attachmentName(node);
}

({int? totalPages, int? totalCount}) _readPagination(String text) {
  final pages = _pagesPattern.firstMatch(text);
  final totalCount = _recordCountPattern.firstMatch(text);
  return (
    totalPages: pages == null ? null : int.tryParse(pages.group(2)!),
    totalCount: totalCount == null ? null : int.tryParse(totalCount.group(1)!),
  );
}

OaPublishedTime? _matchPublishedAtStart(String raw, DateTime nowUtc) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final relative = _relativePublishedPattern.firstMatch(text);
  if (relative != null) {
    final today = _shanghaiDate(nowUtc);
    final date = relative.group(1) == '昨天'
        ? today.subtract(const Duration(days: 1))
        : today;
    final dateText = _formatDate(date);
    final time = _timePattern.firstMatch(text.substring(relative.end));
    if (time != null) {
      final hour = int.parse(time.group(1)!);
      final minute = int.parse(time.group(2)!);
      final second = time.group(3) == null ? 0 : int.parse(time.group(3)!);
      if (_validTime(hour, minute, second)) {
        final end = relative.end + time.end;
        return OaPublishedTime._(
          text: text.substring(0, end).trim(),
          atUtc: _utcFromShanghai(date, hour, minute, second),
        );
      }
    }
    return OaPublishedTime._(
      text: text.substring(0, relative.end).trim(),
      date: dateText,
    );
  }
  final absolute = _absolutePublishedPattern.firstMatch(text);
  if (absolute == null) return null;
  final year = int.parse(absolute.group(1)!);
  final month = int.parse(absolute.group(2)!);
  final day = int.parse(absolute.group(3)!);
  if (!_validDate(year, month, day)) return null;
  final dateText = _formatDate(DateTime.utc(year, month, day));
  final hourGroup = absolute.group(4);
  if (hourGroup != null) {
    final hour = int.parse(hourGroup);
    final minute = int.parse(absolute.group(5)!);
    final second = absolute.group(6) == null
        ? 0
        : int.parse(absolute.group(6)!);
    if (_validTime(hour, minute, second)) {
      return OaPublishedTime._(
        text: text.substring(0, absolute.end).trim(),
        atUtc: _utcFromShanghai(
          DateTime.utc(year, month, day),
          hour,
          minute,
          second,
        ),
      );
    }
  }
  return OaPublishedTime._(
    text: text.substring(0, absolute.end).trim(),
    date: dateText,
  );
}

DateTime _shanghaiDate(DateTime nowUtc) {
  final shanghai = nowUtc.toUtc().add(const Duration(hours: 8));
  return DateTime.utc(shanghai.year, shanghai.month, shanghai.day);
}

DateTime _utcFromShanghai(DateTime date, int hour, int minute, int second) {
  return DateTime.utc(
    date.year,
    date.month,
    date.day,
    hour,
    minute,
    second,
  ).subtract(const Duration(hours: 8));
}

bool _validDate(int year, int month, int day) {
  if (year < 2000 || year > 2099) return false;
  final value = DateTime.utc(year, month, day);
  return value.year == year && value.month == month && value.day == day;
}

bool _validTime(int hour, int minute, int second) {
  return hour >= 0 &&
      hour < 24 &&
      minute >= 0 &&
      minute < 60 &&
      second >= 0 &&
      second < 60;
}

String _formatDate(DateTime date) {
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${pad(date.month)}-${pad(date.day)}';
}
