/// 学习通课程资料目录的解析结果。
///
/// 行为移植自 `app/src/shared/chaoxing-collectors.ts` 的文件列表脚本
/// （GPL-3.0-or-later）。下载/目录入口只在内存中使用，不写入本地数据库。
library;

import 'package:jlu_dela/features/assignments/chaoxing_html.dart';
import 'package:jlu_dela/features/assignments/chaoxing_parse.dart';

enum ChaoxingMaterialKind { folder, file }

class ChaoxingMaterial {
  const ChaoxingMaterial({
    required this.id,
    required this.name,
    required this.kind,
    this.downloadable = false,
    this.folderUri,
    this.downloadUri,
  });

  /// 来源资料标识（列表行的 dataId）。
  final String id;
  final String name;
  final ChaoxingMaterialKind kind;
  final bool downloadable;
  final Uri? folderUri;
  final Uri? downloadUri;
}

final RegExp _emptyMaterialList = RegExp('暂无|没有|无资料|无文件');

List<ChaoxingMaterial> parseMaterialListPage(
  String html, {
  required Uri pageUrl,
}) {
  final document = HtmlParser.parse(html);
  final body = document.querySelector('.dataBody');
  if (body == null) throw const ChaoxingPageFormatException();
  final rows = body.querySelectorAll('.dataBody_td');
  if (rows.isEmpty && !_emptyMaterialList.hasMatch(body.text)) {
    throw const ChaoxingPageFormatException();
  }
  return rows
      .map((row) => _materialFromRow(row, document, pageUrl))
      .toList(growable: false);
}

ChaoxingMaterial _materialFromRow(
  HtmlNode row,
  HtmlNode document,
  Uri pageUrl,
) {
  final id = (row.attr('id') ?? '').trim();
  final title = (row.attr('dataname') ?? '').trim();
  final name = title.isNotEmpty
      ? title
      : row.querySelector('.dataBody_name_stu')?.text.trim() ?? '';
  if (id.isEmpty || name.isEmpty) throw const ChaoxingPageFormatException();
  if (row.attr('type') == 'afolder') {
    return ChaoxingMaterial(
      id: id,
      name: name,
      kind: ChaoxingMaterialKind.folder,
      folderUri: _folderUri(row, document, pageUrl, id, name),
    );
  }
  final downloadUri = row.attr('isdown') == '1'
      ? _downloadUri(document, id)
      : null;
  return ChaoxingMaterial(
    id: id,
    name: name,
    kind: ChaoxingMaterialKind.file,
    downloadable: downloadUri != null,
    downloadUri: downloadUri,
  );
}

Uri? _folderUri(
  HtmlNode row,
  HtmlNode document,
  Uri pageUrl,
  String id,
  String name,
) {
  final subtitles = document
      .querySelectorAll('.subtitleId')
      .map((node) => node.attr('id') ?? '')
      .join(',');
  final parameters = <String, String>{
    ...pageUrl.queryParameters,
    'dataId': id,
    'dataName': name,
    'type': '1',
    'parent': subtitles,
    'flag': '0',
    'enc': _fieldValue(document, 'enc'),
    'cpi': _fieldValue(document, 'cpi'),
    'ut': _fieldValue(document, 'ut').isEmpty
        ? 's'
        : _fieldValue(document, 'ut'),
    'microTopicId': _fieldValue(document, 'microTopicId'),
  };
  return _validated(pageUrl.replace(queryParameters: parameters));
}

Uri? _downloadUri(HtmlNode document, String id) {
  final domain = _fieldValue(document, 'downloadDomain');
  if (domain.isEmpty) return null;
  final base = Uri.tryParse('$domain/coursedata/downloadData');
  if (base == null) return null;
  final uri = base.replace(
    queryParameters: {
      'dataId': id,
      'classId': _fieldValue(document, 'classId'),
      'cpi': _fieldValue(document, 'cpi'),
      'courseId': _fieldValue(document, 'courseId'),
      'ut': 's',
    },
  );
  return _validated(uri);
}

String _fieldValue(HtmlNode document, String id) {
  return document.querySelector('#$id')?.attr('value')?.trim() ?? '';
}

/// 学习通资源只接受 https 的 chaoxing.com 主机，拒绝任意 URL。
Uri? _validated(Uri? uri) {
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (host != 'chaoxing.com' && !host.endsWith('.chaoxing.com')) return null;
  return uri;
}
