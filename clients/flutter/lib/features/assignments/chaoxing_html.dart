/// 学习通页面解析用的极简 HTML 文档树。
///
/// 只覆盖课程、作业页面实际用到的标签、属性与选择器；不执行脚本，不加载外部
/// 资源。行为对应旧版 `chaoxing-collectors.ts` 在页面内执行的 DOM 查询。
library;

class HtmlNode {
  HtmlNode(this.tag, {this.attributes = const {}, this.parent, this.order = 0});

  final String tag;
  final Map<String, String> attributes;
  final HtmlNode? parent;

  /// 文档顺序（前序遍历序号）。
  final int order;

  final List<HtmlNode> children = [];
  final List<Object> _content = [];

  String? attr(String name) => attributes[name];

  bool hasAttr(String name) => attributes.containsKey(name);

  bool hasClass(String name) => (attributes['class'] ?? '')
      .split(_whitespace)
      .any((value) => value == name);

  Iterable<HtmlNode> get ancestors sync* {
    var current = parent;
    while (current != null) {
      yield current;
      current = current.parent;
    }
  }

  String get text {
    final buffer = StringBuffer();
    _writeText(buffer);
    return buffer.toString();
  }

  void _writeText(StringBuffer buffer) {
    for (final item in _content) {
      if (item is String) {
        buffer.write(item);
      } else if (item is HtmlNode) {
        item._writeText(buffer);
      }
    }
  }

  List<HtmlNode> querySelectorAll(String selector) {
    final groups = _selectorGroups(selector);
    final matches = <HtmlNode>[];
    _visit((node) {
      if (groups.any((chain) => _matchesChain(node, chain))) matches.add(node);
    });
    matches.sort((left, right) => left.order.compareTo(right.order));
    return matches;
  }

  HtmlNode? querySelector(String selector) {
    final matches = querySelectorAll(selector);
    return matches.isEmpty ? null : matches.first;
  }

  bool matches(String selector) =>
      _selectorGroups(selector).any((chain) => _matchesChain(this, chain));

  void _visit(void Function(HtmlNode node) visit) {
    for (final child in children) {
      visit(child);
      child._visit(visit);
    }
  }
}

abstract final class HtmlParser {
  static HtmlNode parse(String html) {
    final root = HtmlNode('#document');
    final stack = <HtmlNode>[root];
    var order = 0;
    var index = 0;
    while (index < html.length) {
      final tagStart = html.indexOf('<', index);
      if (tagStart < 0) {
        _appendText(stack.last, html.substring(index));
        break;
      }
      if (tagStart > index) {
        _appendText(stack.last, html.substring(index, tagStart));
      }
      if (html.startsWith('<!--', tagStart)) {
        final commentEnd = html.indexOf('-->', tagStart + 4);
        index = commentEnd < 0 ? html.length : commentEnd + 3;
        continue;
      }
      if (html.startsWith('<!', tagStart) || html.startsWith('<?', tagStart)) {
        final declarationEnd = html.indexOf('>', tagStart + 2);
        index = declarationEnd < 0 ? html.length : declarationEnd + 1;
        continue;
      }
      if (html.startsWith('</', tagStart)) {
        final closeEnd = html.indexOf('>', tagStart + 2);
        if (closeEnd < 0) break;
        _close(stack, _tagName(html.substring(tagStart + 2, closeEnd)));
        index = closeEnd + 1;
        continue;
      }
      final openEnd = html.indexOf('>', tagStart + 1);
      if (openEnd < 0) break;
      var tagBody = html.substring(tagStart + 1, openEnd);
      var selfClosing = false;
      if (tagBody.trimRight().endsWith('/')) {
        selfClosing = true;
        tagBody = tagBody.trimRight();
        tagBody = tagBody.substring(0, tagBody.length - 1);
      }
      final nameMatch = RegExp(r'^[a-zA-Z][a-zA-Z0-9:-]*').firstMatch(tagBody);
      if (nameMatch == null) {
        index = openEnd + 1;
        continue;
      }
      final name = nameMatch.group(0)!.toLowerCase();
      final node = HtmlNode(
        name,
        attributes: _parseAttributes(tagBody.substring(nameMatch.end)),
        parent: stack.last,
        order: order++,
      );
      stack.last._content.add(node);
      stack.last.children.add(node);
      index = openEnd + 1;
      if (_rawTextTags.contains(name)) {
        final closing = _indexOfClosingTag(html, name, index);
        final rawEnd = closing < 0 ? html.length : closing;
        final raw = html.substring(index, rawEnd);
        if (raw.isNotEmpty) node._content.add(raw);
        index = closing < 0 ? html.length : closing;
        continue;
      }
      if (!selfClosing && !_voidTags.contains(name)) stack.add(node);
    }
    return root;
  }

  static void _appendText(HtmlNode node, String raw) {
    final decoded = decodeHtmlEntities(raw);
    if (decoded.isNotEmpty) node._content.add(decoded);
  }

  static void _close(List<HtmlNode> stack, String name) {
    for (var index = stack.length - 1; index > 0; index--) {
      if (stack[index].tag == name) {
        stack.removeRange(index, stack.length);
        return;
      }
    }
  }

  static String _tagName(String raw) =>
      raw.trim().split(_tagBoundary).first.toLowerCase();

  static int _indexOfClosingTag(String html, String name, int from) {
    final lower = html.toLowerCase();
    final closing = lower.indexOf('</$name', from);
    return closing;
  }

  static Map<String, String> _parseAttributes(String source) {
    final attributes = <String, String>{};
    for (final match in _attributeSyntax.allMatches(source)) {
      final name = match.group(1)!.toLowerCase();
      final value = match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
      attributes[name] = decodeHtmlEntities(value);
    }
    return attributes;
  }

  static const Set<String> _voidTags = {
    'area',
    'base',
    'br',
    'col',
    'embed',
    'hr',
    'img',
    'input',
    'link',
    'meta',
    'param',
    'source',
    'track',
    'wbr',
  };

  static const Set<String> _rawTextTags = {'script', 'style', 'textarea'};
}

final RegExp _tagBoundary = RegExp(r'[\s/>]');
final RegExp _whitespace = RegExp(r'\s+');
final RegExp _attributeSyntax = RegExp(
  r'''([a-zA-Z_:][-a-zA-Z0-9_:.]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?''',
);

final Map<String, String> _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00a0',
  'hellip': '…',
  'mdash': '—',
  'ndash': '–',
  'middot': '·',
  'ldquo': '“',
  'rdquo': '”',
  'lsquo': '‘',
  'rsquo': '’',
  'times': '×',
  'divide': '÷',
  'rarr': '→',
  'larr': '←',
  'copy': '©',
  'reg': '®',
  'trade': '™',
};

String decodeHtmlEntities(String value) {
  if (!value.contains('&')) return value;
  return value.replaceAllMapped(_entitySyntax, (match) {
    final entity = match.group(1)!;
    if (entity.startsWith('#')) {
      final isHex = entity.length > 1 && (entity[1] == 'x' || entity[1] == 'X');
      final code = int.tryParse(
        entity.substring(isHex ? 2 : 1),
        radix: isHex ? 16 : 10,
      );
      if (code == null || code <= 0 || code > 0x10ffff) return match.group(0)!;
      return String.fromCharCode(code);
    }
    return _namedEntities[entity.toLowerCase()] ?? match.group(0)!;
  });
}

final RegExp _entitySyntax = RegExp(
  r'&(#[xX][0-9a-fA-F]+|#\d+|[a-zA-Z][a-zA-Z0-9]+);?',
);

List<List<_SimpleSelector>> _selectorGroups(String selector) {
  return selector
      .split(',')
      .map(
        (group) => group
            .trim()
            .split(_whitespace)
            .where((token) => token.isNotEmpty)
            .map(_parseSimpleSelector)
            .toList(growable: false),
      )
      .toList(growable: false);
}

_SimpleSelector _parseSimpleSelector(String token) {
  final firstSpecial = token.indexOf(RegExp('[.#]'));
  final String tagPart;
  final String rest;
  if (firstSpecial < 0) {
    tagPart = token;
    rest = '';
  } else if (firstSpecial == 0) {
    tagPart = '';
    rest = token;
  } else {
    tagPart = token.substring(0, firstSpecial);
    rest = token.substring(firstSpecial);
  }
  String? id;
  final classes = <String>[];
  for (final match in _classOrId.allMatches(rest)) {
    if (match.group(1) == '#') {
      id = match.group(2);
    } else {
      classes.add(match.group(2)!);
    }
  }
  return _SimpleSelector(
    tag: tagPart.isEmpty ? null : tagPart.toLowerCase(),
    id: id,
    classes: classes,
  );
}

final RegExp _classOrId = RegExp(r'([.#])([A-Za-z0-9_-]+)');

class _SimpleSelector {
  const _SimpleSelector({this.tag, this.id, required this.classes});

  final String? tag;
  final String? id;
  final List<String> classes;

  bool matches(HtmlNode node) {
    if (tag != null && node.tag != tag) return false;
    if (id != null && node.attributes['id'] != id) return false;
    for (final name in classes) {
      if (!node.hasClass(name)) return false;
    }
    return true;
  }
}

bool _matchesChain(HtmlNode node, List<_SimpleSelector> chain) {
  if (chain.isEmpty || !chain.last.matches(node)) return false;
  var position = chain.length - 2;
  var ancestor = node.parent;
  while (position >= 0 && ancestor != null) {
    if (chain[position].matches(ancestor)) position -= 1;
    ancestor = ancestor.parent;
  }
  return position < 0;
}
