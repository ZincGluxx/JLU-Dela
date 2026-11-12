import 'package:flutter/widgets.dart';

import '../models/source.dart';
import 'source.dart';

abstract interface class SourcePageOpener {
  Future<void> openPage(
    BuildContext context, {
    required SourceKind source,
    required Uri uri,
  });
}

class UnsupportedSourcePageOpener implements SourcePageOpener {
  const UnsupportedSourcePageOpener();

  @override
  Future<void> openPage(
    BuildContext context, {
    required SourceKind source,
    required Uri uri,
  }) async {
    throw SourceException(
      SourceFailure(
        code: SourceErrorCodes.sourceUnavailable,
        message: '来源原网页尚未接入',
        source: source,
      ),
    );
  }
}
