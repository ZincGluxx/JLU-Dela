import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/features/content/chaoxing_material_parser.dart';

const _parser = ChaoxingMaterialParser();

String materialRow(String attributes, {String inner = ''}) =>
    '<ul class="dataBody_td" $attributes>$inner</ul>';

String materialPage({
  String rows = '',
  String bodyText = '',
  String pages = '',
  bool downloadDomain = true,
  String extra = '',
}) =>
    '<html><body>'
    '${downloadDomain ? '<input id="downloadDomain" value="https://mooc1.chaoxing.com">' : ''}'
    '<input id="cpi" value="3"><input id="classId" value="2">'
    '<input id="courseId" value="1">'
    '<div class="dataBody">$bodyText$rows</div>$pages$extra'
    '</body></html>';

void main() {
  group('资料目录解析', () {
    test('区分文件夹、可下载文件与未适配的教师课件', () {
      final listing = _parser.parseListing(
        materialPage(
          rows:
              materialRow('id="f1" type="afolder" dataname="课件"') +
              materialRow(
                'id="d1" type="pdf" dataname="示例.pdf" isdown="1"',
                inner: '<li class="dataBody_size_stu">12KB</li>',
              ) +
              materialRow(
                'type="tch-courseware"',
                inner: '<li class="dataBody_name_stu">教师课件</li>',
              ),
        ),
      );

      expect(listing.page, 1);
      expect(listing.totalPages, isNull);
      expect(listing.hasNextPage, isFalse);
      expect(listing.isScopeComplete, isFalse);
      expect(listing.items, hasLength(3));

      final folder = listing.items[0];
      expect(folder.id, 'f1');
      expect(folder.name, '课件');
      expect(folder.kind, ChaoxingMaterialKind.folder);
      expect(folder.sourceType, 'afolder');
      expect(folder.bytes, isNull);
      expect(folder.downloadable, isFalse);

      final file = listing.items[1];
      expect(file.id, 'd1');
      expect(file.name, '示例.pdf');
      expect(file.kind, ChaoxingMaterialKind.file);
      expect(file.bytes, 12 * 1024);
      expect(file.downloadable, isTrue);

      final courseware = listing.items[2];
      expect(courseware.id, 'teacher-courseware');
      expect(courseware.name, '教师课件');
      expect(courseware.kind, ChaoxingMaterialKind.file);
      expect(courseware.downloadable, isFalse);
    });

    test('可下载只由来源标记决定，不信任行内任意链接', () {
      final listing = _parser.parseListing(
        materialPage(
          downloadDomain: false,
          rows:
              materialRow(
                'id="d1" type="pdf" dataname="示例.pdf" isdown="1" '
                'href="https://evil.example/download"',
              ) +
              materialRow(
                'id="d2" type="pdf" dataname="附表.pdf" '
                'downloadurl="https://evil.example/download"',
              ),
        ),
      );

      expect(listing.items.map((row) => row.downloadable), [false, false]);
      final withDomain = _parser.parseListing(
        materialPage(
          rows: materialRow(
            'id="d3" type="pdf" dataname="可下载.pdf" isdown="1" '
            'href="https://evil.example/download"',
          ),
        ),
      );
      expect(withDomain.items.single.downloadable, isTrue);
    });

    test('文件大小支持常见单位，未知大小保持为空', () {
      expect(parseChaoxingMaterialBytes('12KB'), 12 * 1024);
      expect(parseChaoxingMaterialBytes('1.2 MB'), 1258291);
      expect(parseChaoxingMaterialBytes('0B'), 0);
      expect(parseChaoxingMaterialBytes('2 GB'), 2 * 1024 * 1024 * 1024);
      expect(parseChaoxingMaterialBytes('12 kb'), 12 * 1024);
      expect(parseChaoxingMaterialBytes(''), isNull);
      expect(parseChaoxingMaterialBytes(null), isNull);
      expect(parseChaoxingMaterialBytes('未知'), isNull);
      expect(parseChaoxingMaterialBytes('12'), isNull);

      final listing = _parser.parseListing(
        materialPage(
          rows:
              materialRow(
                'id="d1" type="pdf" dataname="示例.pdf"',
                inner: '<li class="dataBody_size_stu">未知</li>',
              ) +
              materialRow(
                'id="f1" type="afolder" dataname="子目录"',
                inner: '<li class="dataBody_size_stu">1MB</li>',
              ),
        ),
      );
      expect(listing.items.first.bytes, isNull);
      expect(listing.items.last.bytes, isNull);
    });

    test('子目录分页只在来源给出总页数时判定完整', () {
      final pageOne = _parser.parseListing(
        materialPage(
          rows: materialRow('id="f2" type="afolder" dataname="子目录"'),
          pages: '<div class="pages">第 1 / 3 页</div>',
        ),
      );
      expect(pageOne.page, 1);
      expect(pageOne.totalPages, 3);
      expect(pageOne.hasNextPage, isTrue);
      expect(pageOne.isScopeComplete, isFalse);

      final pageTwo = _parser.parseListing(
        materialPage(
          rows: materialRow('id="f2" type="afolder" dataname="子目录"'),
          pages: '<div class="pages">第 2 / 3 页</div>',
        ),
        page: 2,
      );
      expect(pageTwo.totalPages, 3);
      expect(pageTwo.hasNextPage, isTrue);
      expect(pageTwo.isScopeComplete, isFalse);

      final pageThree = _parser.parseListing(
        materialPage(
          rows: materialRow('id="f2" type="afolder" dataname="子目录"'),
          pages: '<div class="pages">第 3 / 3 页</div>',
        ),
        page: 3,
      );
      expect(pageThree.hasNextPage, isFalse);
      expect(pageThree.isScopeComplete, isTrue);

      final totalOnly = _parser.parseListing(
        materialPage(
          rows: materialRow('id="f3" type="afolder" dataname="子目录"'),
          pages: '<div class="pages">共 4 页</div>',
        ),
      );
      expect(totalOnly.totalPages, 4);

      final attribute = _parser.parseListing(
        materialPage(
          rows: materialRow('id="f4" type="afolder" dataname="子目录"'),
          pages: '<div class="pages" data-total-page="2"></div>',
        ),
      );
      expect(attribute.totalPages, 2);
    });

    test('识别来源认可的空目录，未知空页与失效页拒绝解析', () {
      final empty = _parser.parseListing(materialPage(bodyText: '暂无资料'));
      expect(empty.items, isEmpty);
      expect(empty.totalPages, 1);
      expect(empty.isScopeComplete, isTrue);

      expect(
        () => _parser.parseListing(materialPage()),
        throwsA(isA<ChaoxingMaterialLayoutException>()),
      );
      expect(
        () => _parser.parseListing('<html><body><h1>服务维护</h1></body></html>'),
        throwsA(isA<ChaoxingMaterialLayoutException>()),
      );
      expect(
        () => _parser.parseListing(
          '<html><body><h1>服务维护</h1><div class="dataBody"></div>'
          '</body></html>',
        ),
        throwsA(isA<ChaoxingMaterialLayoutException>()),
      );
    });

    test('登录页返回明确的来源失效错误而不是空目录', () {
      expect(
        () => _parser.parseListing(
          '<html><body><input id="phone"><input id="pwd" type="password">'
          '<div class="dataBody"></div></body></html>',
        ),
        throwsA(isA<ChaoxingMaterialAuthException>()),
      );
      expect(
        () => _parser.parseListing(
          '<html><body><input type="password" name="pass">'
          '<div class="dataBody"></div></body></html>',
        ),
        throwsA(isA<ChaoxingMaterialAuthException>()),
      );
    });

    test('资料行缺少稳定标识或名称时拒绝解析', () {
      expect(
        () => _parser.parseListing(
          materialPage(rows: materialRow('type="pdf" dataname="示例.pdf"')),
        ),
        throwsA(isA<ChaoxingMaterialLayoutException>()),
      );
      expect(
        () => _parser.parseListing(
          materialPage(rows: materialRow('id="d1" type="pdf"')),
        ),
        throwsA(isA<ChaoxingMaterialLayoutException>()),
      );
    });
  });
}
