import '../models/source.dart';
import 'source_session.dart';

const Set<String> sourceAllowedHosts = {
  'cas.jlu.edu.cn',
  'iedu.jlu.edu.cn',
  'oa.jlu.edu.cn',
  'i.chaoxing.com',
  'passport2.chaoxing.com',
  'mooc1.chaoxing.com',
  'mooc1-1.chaoxing.com',
  'mooc2-ans.chaoxing.com',
};

const Set<String> _chaoxingHosts = {
  'i.chaoxing.com',
  'passport2.chaoxing.com',
  'mooc1.chaoxing.com',
  'mooc1-1.chaoxing.com',
  'mooc2-ans.chaoxing.com',
};

bool isAllowedSourceUri(Uri uri) {
  if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return false;
  }
  if (uri.hasPort && uri.port != 443) {
    return false;
  }
  return sourceAllowedHosts.contains(uri.host.toLowerCase());
}

SourceKind? sourceForAllowedUri(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host == 'cas.jlu.edu.cn' || host == 'iedu.jlu.edu.cn') {
    return SourceKind.jluIedu;
  }
  if (host == 'oa.jlu.edu.cn') {
    return SourceKind.jluOa;
  }
  return _chaoxingHosts.contains(host) ? SourceKind.chaoxing : null;
}

bool isSourceLoginUri(Uri uri) {
  if (!isAllowedSourceUri(uri)) {
    return false;
  }
  final host = uri.host.toLowerCase();
  if (host == 'cas.jlu.edu.cn') {
    return RegExp(r'^/tpass/login(?:[/.;]|$)').hasMatch(uri.path);
  }
  if (host == 'passport2.chaoxing.com') {
    return RegExp(r'^/(?:login|mlogin|fanyalogin)').hasMatch(uri.path);
  }
  return false;
}

class CampusSourceEndpoints {
  const CampusSourceEndpoints._({
    required this.source,
    required this.loginEntryUri,
    required this.cookieUris,
    required this.probeUri,
    required this.loginPageMarkers,
  });

  factory CampusSourceEndpoints.forSource(SourceKind source) {
    return switch (source) {
      SourceKind.jluIedu => _jluIedu,
      SourceKind.jluOa => _jluOa,
      SourceKind.chaoxing => _chaoxing,
    };
  }

  final SourceKind source;
  final Uri loginEntryUri;
  final List<Uri> cookieUris;
  final Uri probeUri;
  final List<RegExp> loginPageMarkers;

  bool looksLikeLoginPage(SourceResponse response) {
    final finalUri = response.finalUri;
    if (finalUri != null && isSourceLoginUri(finalUri)) {
      return true;
    }
    return loginPageMarkers.any((marker) => marker.hasMatch(response.body));
  }

  bool indicatesAuthenticated(SourceResponse response) {
    if (!response.isSuccess) {
      return false;
    }
    final finalUri = response.finalUri;
    if (finalUri != null) {
      if (!isAllowedSourceUri(finalUri)) {
        return false;
      }
      final finalKind = sourceForAllowedUri(finalUri);
      if (finalKind == null ||
          sourceAuthGroup(finalKind) != sourceAuthGroup(source)) {
        return false;
      }
    }
    return !looksLikeLoginPage(response);
  }

  static final _jluIedu = CampusSourceEndpoints._(
    source: SourceKind.jluIedu,
    loginEntryUri: Uri.parse(
      'https://iedu.jlu.edu.cn/jwapp/sys/emaphome/portal/index.do',
    ),
    cookieUris: List.unmodifiable([
      Uri.parse('https://iedu.jlu.edu.cn/'),
      Uri.parse('https://cas.jlu.edu.cn/'),
      Uri.parse('https://oa.jlu.edu.cn/'),
    ]),
    probeUri: Uri.parse(
      'https://iedu.jlu.edu.cn/jwapp/sys/emaphome/portal/index.do',
    ),
    loginPageMarkers: _jluLoginMarkers,
  );

  static final _jluOa = CampusSourceEndpoints._(
    source: SourceKind.jluOa,
    loginEntryUri: Uri.parse(
      'https://oa.jlu.edu.cn/defaultroot/login.jsp?access=oa',
    ),
    cookieUris: List.unmodifiable([
      Uri.parse('https://oa.jlu.edu.cn/'),
      Uri.parse('https://cas.jlu.edu.cn/'),
      Uri.parse('https://iedu.jlu.edu.cn/'),
    ]),
    probeUri: Uri.parse(
      'https://oa.jlu.edu.cn/defaultroot/login.jsp?access=oa',
    ),
    loginPageMarkers: _jluLoginMarkers,
  );

  static final _chaoxing = CampusSourceEndpoints._(
    source: SourceKind.chaoxing,
    loginEntryUri: Uri.parse(
      'https://passport2.chaoxing.com/login?fid=&refer=https%3A%2F%2Fi.chaoxing.com%2Fbase',
    ),
    cookieUris: List.unmodifiable([
      Uri.parse('https://i.chaoxing.com/'),
      Uri.parse('https://passport2.chaoxing.com/'),
      Uri.parse('https://mooc1.chaoxing.com/'),
      Uri.parse('https://mooc1-1.chaoxing.com/'),
      Uri.parse('https://mooc2-ans.chaoxing.com/'),
    ]),
    probeUri: Uri.parse('https://i.chaoxing.com/base'),
    loginPageMarkers: List.unmodifiable([
      RegExp(r'''id\s*=\s*["']?(?:phone|pwd)["']?''', caseSensitive: false),
      RegExp(r'fanyalogin', caseSensitive: false),
      RegExp(r'passport2\.chaoxing\.com/login', caseSensitive: false),
    ]),
  );

  static final _jluLoginMarkers = List<RegExp>.unmodifiable([
    RegExp(r'''<form[^>]*id\s*=\s*["']?loginForm''', caseSensitive: false),
    RegExp(r'''name\s*=\s*["']WxCode["']''', caseSensitive: false),
    RegExp(r'''type\s*=\s*["']password["']''', caseSensitive: false),
  ]);
}
