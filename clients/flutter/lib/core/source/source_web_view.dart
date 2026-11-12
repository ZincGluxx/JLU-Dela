import 'package:flutter/widgets.dart';

import 'source_session.dart';

abstract interface class SourceWebViewController {
  Future<void> load(Uri uri);

  Future<List<SourceCookie>> readCookies(Iterable<Uri> uris);

  Future<void> setCookies(Iterable<SourceCookie> cookies);

  Future<void> clearCookies();
}

abstract interface class SourceWebView {
  Widget build({
    required bool Function(Uri uri) isAllowed,
    required ValueChanged<SourceWebViewController> onCreated,
    Uri? initialUri,
    ValueChanged<Uri>? onPageChanged,
    ValueChanged<String>? onBlockedNavigation,
    ValueChanged<String>? onLoadError,
    ValueChanged<double>? onProgress,
  });
}
