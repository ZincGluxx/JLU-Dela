// 页面语义移植自 app/src/shared/jlu-collectors.ts 与 chaoxing-collectors.ts
// （GPL-3.0-or-later）；改为不依赖 WebView 的 Dart 文本解析，不执行脚本、不加载资源。

const _voidTags = <String>{
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

const _skippedTags = <String>{
  'head',
  'noscript',
  'script',
  'style',
  'template',
  'title',
};

const _blockTags = <String>{
  'address',
  'article',
  'aside',
  'blockquote',
  'dd',
  'div',
  'dl',
  'dt',
  'fieldset',
  'figcaption',
  'figure',
  'footer',
  'form',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'hr',
  'li',
  'main',
  'nav',
  'ol',
  'p',
  'pre',
  'section',
  'table',
  'tbody',
  'tfoot',
  'thead',
  'tr',
  'ul',
};

const _cellTags = <String>{'td', 'th'};

const _namedEntities = <String, String>{
  'amp': '&',
  'apos': "'",
  'asymp': '\u2248',
  'bull': '\u2022',
  'cong': '\u2245',
  'copy': '\u00a9',
  'darr': '\u2193',
  'deg': '\u00b0',
  'divide': '\u00f7',
  'emsp': '\u2003',
  'ensp': '\u2002',
  'equiv': '\u2261',
  'frac12': '\u00bd',
  'frac14': '\u00bc',
  'frac34': '\u00be',
  'ge': '\u2265',
  'gt': '>',
  'harr': '\u2194',
  'hellip': '\u2026',
  'infin': '\u221e',
  'int': '\u222b',
  'larr': '\u2190',
  'ldquo': '\u201c',
  'le': '\u2264',
  'lsquo': '\u2018',
  'lt': '<',
  'mdash': '\u2014',
  'micro': '\u00b5',
  'middot': '\u00b7',
  'nbsp': '\u00a0',
  'ndash': '\u2013',
  'ne': '\u2260',
  'para': '\u00b6',
  'plusmn': '\u00b1',
  'prime': '\u2032',
  'prod': '\u220f',
  'quot': '"',
  'radic': '\u221a',
  'rarr': '\u2192',
  'rdquo': '\u201d',
  'reg': '\u00ae',
  'rsquo': '\u2019',
  'sect': '\u00a7',
  'sim': '\u223c',
  'sum': '\u2211',
  'sup2': '\u00b2',
  'sup3': '\u00b3',
  'there4': '\u2234',
  'thinsp': '\u2009',
  'times': '\u00d7',
  'trade': '\u2122',
  'uarr': '\u2191',
};

class HtmlNode {
  HtmlNode._(this.tag, this.attributes, this.text);

  factory HtmlNode.element(String tag, Map<String, String> attributes) =>
      HtmlNode._(tag, attributes, null);

  factory HtmlNode.text(String text) => HtmlNode._(null, const {}, text);

  final String? tag;
  final Map<String, String> attributes;
  final String? text;
  final List<HtmlNode> children = <HtmlNode>[];
  HtmlNode? parent;

  bool get isText => tag == null;

  String? attribute(String name) => attributes[name];

  bool hasClass(String name) {
    final value = attributes['class'];
    if (value == null) return false;
    return value.split(RegExp(r'\s+')).contains(name);
  }

  String get textContent {
    final buffer = StringBuffer();
    _writeTextContent(this, buffer);
    return buffer.toString();
  }

  Iterable<HtmlNode> descendants() sync* {
    for (final child in children) {
      yield child;
      yield* child.descendants();
    }
  }

  HtmlNode? firstByTag(String tag) {
    if (this.tag == tag) return this;
    for (final node in descendants()) {
      if (node.tag == tag) return node;
    }
    return null;
  }

  HtmlNode? firstByClass(String className) {
    if (hasClass(className)) return this;
    for (final node in descendants()) {
      if (node.hasClass(className)) return node;
    }
    return null;
  }

  HtmlNode? firstById(String id) {
    if (attributes['id'] == id) return this;
    for (final node in descendants()) {
      if (node.attributes['id'] == id) return node;
    }
    return null;
  }

  HtmlNode? closestByClass(String className) {
    for (HtmlNode? node = this; node != null; node = node.parent) {
      if (node.hasClass(className)) return node;
    }
    return null;
  }

  HtmlNode? closestByTag(String tag) {
    for (HtmlNode? node = this; node != null; node = node.parent) {
      if (node.tag == tag) return node;
    }
    return null;
  }
}

HtmlNode parseHtml(String source) {
  final root = HtmlNode.element('#document', const {});
  final stack = <HtmlNode>[root];
  var index = 0;
  while (index < source.length) {
    final open = source.indexOf('<', index);
    if (open < 0) {
      _appendText(stack.last, source.substring(index));
      break;
    }
    if (open > index) _appendText(stack.last, source.substring(index, open));
    if (source.startsWith('<!--', open)) {
      final end = source.indexOf('-->', open + 4);
      index = end < 0 ? source.length : end + 3;
      continue;
    }
    final close = _findTagEnd(source, open + 1);
    if (close < 0) {
      _appendText(stack.last, source.substring(open));
      break;
    }
    final inner = source.substring(open + 1, close).trim();
    if (inner.isEmpty || inner.startsWith('!') || inner.startsWith('?')) {
      index = close + 1;
      continue;
    }
    if (inner.startsWith('/')) {
      _closeElement(stack, _tagName(inner.substring(1)));
      index = close + 1;
      continue;
    }
    final selfClosing = inner.endsWith('/');
    final body = selfClosing ? inner.substring(0, inner.length - 1) : inner;
    final nameMatch = RegExp(
      r'^[a-zA-Z][a-zA-Z0-9:-]*',
    ).firstMatch(body.trimLeft());
    if (nameMatch == null) {
      index = close + 1;
      continue;
    }
    final leading = body.length - body.trimLeft().length;
    final name = nameMatch.group(0)!.toLowerCase();
    final node = HtmlNode.element(
      name,
      _parseAttributes(body.substring(leading + nameMatch.end)),
    );
    node.parent = stack.last;
    stack.last.children.add(node);
    index = close + 1;
    if (selfClosing || _voidTags.contains(name)) continue;
    if (name == 'script' || name == 'style') {
      index = _findClosingTag(source, name, index).next;
      continue;
    }
    if (name == 'textarea' || name == 'title') {
      final closing = _findClosingTag(source, name, index);
      if (closing.contentEnd > index) {
        node.children.add(
          HtmlNode.text(
            decodeHtmlEntities(source.substring(index, closing.contentEnd)),
          ),
        );
      }
      index = closing.next;
      continue;
    }
    stack.add(node);
  }
  return root;
}

String htmlToPlainText(String html) => htmlNodeToPlainText(parseHtml(html));

String htmlNodeToPlainText(HtmlNode node) {
  final writer = _PlainTextWriter();
  _writePlainText(node, writer);
  return writer.finish();
}

void _writePlainText(HtmlNode node, _PlainTextWriter writer) {
  final tag = node.tag;
  if (tag == null) {
    writer.text(node.text ?? '');
    return;
  }
  if (_skippedTags.contains(tag)) return;
  if (tag == 'br') {
    writer.newline();
    return;
  }
  if (_blockTags.contains(tag)) {
    writer.newline();
    for (final child in node.children) {
      _writePlainText(child, writer);
    }
    writer.newline();
    return;
  }
  for (final child in node.children) {
    _writePlainText(child, writer);
  }
  if (_cellTags.contains(tag)) writer.space();
}

String decodeHtmlEntities(String value) {
  if (!value.contains('&')) return value;
  return value.replaceAllMapped(
    RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);'),
    (match) {
      final entity = match.group(1)!;
      if (entity.startsWith('#')) {
        final hex = entity.length > 1 && entity[1].toLowerCase() == 'x';
        final digits = hex ? entity.substring(2) : entity.substring(1);
        final code = int.tryParse(digits, radix: hex ? 16 : 10);
        if (code == null || code <= 0 || code > 0x10ffff) {
          return match.group(0)!;
        }
        return String.fromCharCode(code);
      }
      return _namedEntities[entity] ?? match.group(0)!;
    },
  );
}

void _writeTextContent(HtmlNode node, StringBuffer buffer) {
  final tag = node.tag;
  if (tag == null) {
    buffer.write(node.text ?? '');
    return;
  }
  for (final child in node.children) {
    _writeTextContent(child, buffer);
  }
}

void _appendText(HtmlNode node, String raw) {
  if (raw.isEmpty) return;
  final decoded = decodeHtmlEntities(raw);
  if (decoded.isEmpty) return;
  final child = HtmlNode.text(decoded);
  child.parent = node;
  node.children.add(child);
}

String _tagName(String value) {
  final match = RegExp(r'^[a-zA-Z][a-zA-Z0-9:-]*').firstMatch(value.trim());
  return match?.group(0)?.toLowerCase() ?? '';
}

Map<String, String> _parseAttributes(String value) {
  final attributes = <String, String>{};
  for (final match in RegExp(
    r'''([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?''',
  ).allMatches(value)) {
    final name = match.group(1)!.toLowerCase();
    if (name.isEmpty) continue;
    attributes[name] = decodeHtmlEntities(
      match.group(2) ?? match.group(3) ?? match.group(4) ?? '',
    );
  }
  return attributes;
}

int _findTagEnd(String source, int start) {
  String? quote;
  for (var index = start; index < source.length; index++) {
    final char = source[index];
    if (quote != null) {
      if (char == quote) quote = null;
      continue;
    }
    if (char == '"' || char == "'") {
      quote = char;
    } else if (char == '>') {
      return index;
    }
  }
  return -1;
}

({int contentEnd, int next}) _findClosingTag(
  String source,
  String tag,
  int from,
) {
  final pattern = RegExp(
    '</\\s*${RegExp.escape(tag)}\\s*>',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(source.substring(from));
  if (match == null) return (contentEnd: source.length, next: source.length);
  return (contentEnd: from + match.start, next: from + match.end);
}

void _closeElement(List<HtmlNode> stack, String tag) {
  if (tag.isEmpty) return;
  for (var index = stack.length - 1; index > 0; index--) {
    if (stack[index].tag == tag) {
      stack.length = index;
      return;
    }
  }
}

class _PlainTextWriter {
  final StringBuffer _buffer = StringBuffer();
  bool _pendingSpace = false;
  bool _lastIsNewline = true;

  void text(String value) {
    for (final rune in value.runes) {
      if (rune == 0x20 ||
          rune == 0x09 ||
          rune == 0x0a ||
          rune == 0x0d ||
          rune == 0x0c ||
          rune == 0x0b ||
          rune == 0xa0) {
        _pendingSpace = true;
        continue;
      }
      if (_pendingSpace && !_lastIsNewline && _buffer.isNotEmpty) {
        _buffer.write(' ');
      }
      _pendingSpace = false;
      _buffer.writeCharCode(rune);
      _lastIsNewline = false;
    }
  }

  void space() => _pendingSpace = true;

  void newline() {
    _pendingSpace = false;
    if (_buffer.isEmpty || _lastIsNewline) return;
    _buffer.write('\n');
    _lastIsNewline = true;
  }

  String finish() {
    var value = _buffer.toString();
    while (value.startsWith('\n')) {
      value = value.substring(1);
    }
    while (value.endsWith('\n')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}
