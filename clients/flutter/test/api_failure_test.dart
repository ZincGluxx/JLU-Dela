import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/api/api_failure.dart';

Map<String, Object?> todoJson({int revision = 3}) => {
  'id': '6f1b1c1e-0000-4000-8000-000000000001',
  'title': '服务端最新版本',
  'notes': '',
  'due_kind': 'none',
  'due_date': null,
  'due_at': null,
  'color': null,
  'completed': false,
  'show_in_calendar': true,
  'revision': revision,
  'created_at': '2026-11-12T00:00:00Z',
  'updated_at': '2026-11-12T00:00:00Z',
};

Map<String, Object?> errorBody({
  required String code,
  Map<String, Object?>? current,
}) => {
  'error': {
    'code': code,
    'message': 'conflict',
    'request_id': 'req-1',
    'retryable': false,
    'fields': <Object?>[],
    'current': ?current,
  },
};

void main() {
  test('keeps the current todo of a revision conflict', () {
    final failure = apiFailureFromErrorBody(
      409,
      jsonEncode(errorBody(code: 'REVISION_CONFLICT', current: todoJson())),
    );

    expect(failure.code, 'REVISION_CONFLICT');
    expect(failure.statusCode, 409);
    expect(failure.current, isNotNull);
    expect(failure.current!.title, '服务端最新版本');
    expect(failure.current!.revision, 3);
  });

  test('maps a revision conflict without current without throwing', () {
    final failure = apiFailureFromErrorBody(
      409,
      jsonEncode(errorBody(code: 'REVISION_CONFLICT')),
    );

    expect(failure.current, isNull);
    expect(failure.code, 'REVISION_CONFLICT');
    expect(failure.statusCode, 409);
  });

  test('maps a validation failure without current', () {
    final failure = apiFailureFromErrorBody(
      422,
      jsonEncode(errorBody(code: 'VALIDATION_FAILED')),
    );

    expect(failure.current, isNull);
    expect(failure.code, 'VALIDATION_FAILED');
    expect(failure.statusCode, 422);
  });

  test('falls back to the generic server failure for a non json body', () {
    final failure = apiFailureFromErrorBody(500, 'upstream exploded');

    expect(failure.kind, ApiFailureKind.server);
    expect(failure.statusCode, 500);
    expect(failure.code, isNull);
    expect(failure.current, isNull);
  });
}
