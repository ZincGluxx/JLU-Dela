// 来源：app/src/shared/chaoxing-collectors.ts 的 chaoxingFilesScript 与
// app/src/main/chaoxing/api.ts 的资料目录语义（GPL-3.0-or-later）；
// 改为 Dart 纯解析，只保留来源标识与下载能力，不接收或保存任意 URL。

import 'content_html.dart';

final _safeMaterialId = RegExp(r'^[A-Za-z0-9:_-]{1,180}$');
final _byteSizePattern = RegExp(
  r'^(\d+(?:\.\d+)?)\s*(B|KB|MB|GB|TB)$',
  caseSensitive: false,
);
final _listingPagesPattern = RegExp(r'第\s*(\d+)\s*/\s*(\d+)\s*页');
final _listingTotalPagesPattern = RegExp(r'共\s*(\d+)\s*页');
final _emptyListingPattern = RegExp(r'暂无|没有|无资料|无文件');
const _byteMultipliers = <String, int>{
  'B': 1,
  'KB': 1024,
  'MB': 1024 * 1024,
  'GB': 1024 * 1024 * 1024,
  'TB': 1024 * 1024 * 1024 * 1024,
};

enum ChaoxingMaterialKind { folder, file }

class ChaoxingMaterialEntry {
  const ChaoxingMaterialEntry({
    required this.id,
    required this.name,
    required this.kind,
    required this.sourceType,
    required this.downloadable,
    this.bytes,
  });

  final String id;
  final String name;
  final ChaoxingMaterialKind kind;
  final String sourceType;
  final int? bytes;
  final bool downloadable;
}

class ChaoxingMaterialListing {
  const ChaoxingMaterialListing({
    required this.page,
    required this.totalPages,
    required this.items,
  });

  final int page;
  final int? totalPages;
  final List<ChaoxingMaterialEntry> items;

  bool get isEmpty => items.isEmpty;

  bool get hasNextPage => totalPages != null && page < totalPages!;

  bool get isScopeComplete => totalPages != null && page >= totalPages!;
}

class ChaoxingMaterialException implements Exception {
  const ChaoxingMaterialException(this.message);

  final String message;

  @override
  String toString() => 'ChaoxingMaterialException: $message';
}

class ChaoxingMaterialLayoutException extends ChaoxingMaterialException {
  const ChaoxingMaterialLayoutException(super.message);
}

class ChaoxingMaterialAuthException extends ChaoxingMaterialException {
  const ChaoxingMaterialAuthException(super.message);
}

class ChaoxingMaterialParser {
  const ChaoxingMaterialParser();

  ChaoxingMaterialListing parseListing(String html, {int page = 1}) {
    if (page < 1) {
      throw ArgumentError.value(page, 'page', '资料页码从 1 开始');
    }
    final root = parseHtml(html);
    if (_looksLikeLoginPage(root)) {
      throw const ChaoxingMaterialAuthException('学习通需要重新登录');
    }
    final body = root.firstByClass('dataBody');
    if (body == null) {
      throw const ChaoxingMaterialLayoutException('资料目录缺少 dataBody');
    }
    final totalPages = _readTotalPages(root);
    final rows = body
        .descendants()
        .where((node) => node.hasClass('dataBody_td'))
        .toList(growable: false);
    if (rows.isEmpty) {
      if (!_emptyListingPattern.hasMatch(body.textContent)) {
        throw const ChaoxingMaterialLayoutException('资料目录为空且缺少来源空列表标记');
      }
      return ChaoxingMaterialListing(
        page: page,
        totalPages: totalPages ?? 1,
        items: const <ChaoxingMaterialEntry>[],
      );
    }
    final downloadDomain =
        root.firstById('downloadDomain')?.attribute('value')?.trim() ?? '';
    return ChaoxingMaterialListing(
      page: page,
      totalPages: totalPages,
      items: rows
          .map((row) => _parseEntry(row, downloadDomain))
          .toList(growable: false),
    );
  }

  ChaoxingMaterialEntry _parseEntry(HtmlNode row, String downloadDomain) {
    final sourceType = row.attribute('type')?.trim() ?? '';
    final kind = sourceType.toLowerCase() == 'afolder'
        ? ChaoxingMaterialKind.folder
        : ChaoxingMaterialKind.file;
    var id = row.attribute('id')?.trim() ?? '';
    if (id.isEmpty) {
      if (sourceType.toLowerCase() == 'tch-courseware') {
        id = 'teacher-courseware';
      } else {
        throw const ChaoxingMaterialLayoutException('资料行缺少稳定标识');
      }
    }
    if (!_safeMaterialId.hasMatch(id)) {
      throw const ChaoxingMaterialLayoutException('资料标识包含不支持的字符');
    }
    var name = row.attribute('dataname')?.trim() ?? '';
    if (name.isEmpty) {
      name = row.firstByClass('dataBody_name_stu')?.textContent.trim() ?? '';
    }
    if (name.isEmpty) {
      throw const ChaoxingMaterialLayoutException('资料行缺少名称');
    }
    final sizeText = row.firstByClass('dataBody_size_stu')?.textContent.trim();
    return ChaoxingMaterialEntry(
      id: id,
      name: name,
      kind: kind,
      sourceType: sourceType,
      bytes: kind == ChaoxingMaterialKind.folder
          ? null
          : parseChaoxingMaterialBytes(sizeText),
      downloadable:
          kind == ChaoxingMaterialKind.file &&
          row.attribute('isdown')?.trim() == '1' &&
          downloadDomain.isNotEmpty,
    );
  }
}

int? parseChaoxingMaterialBytes(String? raw) {
  final text = (raw ?? '')
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty) return null;
  final match = _byteSizePattern.firstMatch(text);
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!);
  final multiplier = _byteMultipliers[match.group(2)!.toUpperCase()];
  if (value == null || multiplier == null) return null;
  return (value * multiplier).round();
}

bool _looksLikeLoginPage(HtmlNode root) {
  if (root.firstById('phone') != null || root.firstById('pwd') != null) {
    return true;
  }
  for (final node in root.descendants()) {
    if (node.tag == 'input' &&
        node.attribute('type')?.trim().toLowerCase() == 'password') {
      return true;
    }
  }
  return false;
}

int? _readTotalPages(HtmlNode root) {
  final pages = root.firstByClass('pages')?.textContent ?? '';
  final range = _listingPagesPattern.firstMatch(pages);
  if (range != null) return int.tryParse(range.group(2)!);
  final total = _listingTotalPagesPattern.firstMatch(pages);
  if (total != null) return int.tryParse(total.group(1)!);
  for (final node in root.descendants()) {
    final value = node.attribute('data-total-page')?.trim();
    if (value == null) continue;
    final parsed = int.tryParse(value);
    if (parsed != null && parsed >= 1) return parsed;
  }
  return null;
}
