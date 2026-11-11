import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela_api/api.dart';

/// 断言最终发到线上的 JSON 文本，而不是中间 map：`jsonEncode` 会调用每个
/// 模型的 `toJson()`，与 `ApiClient` 实际发送的字节一致。
Map<String, dynamic> wireJson(Map<String, dynamic> body) =>
    jsonDecode(jsonEncode(body)) as Map<String, dynamic>;

void main() {
  group('UpdateTodoRequest', () {
    test('sends only the fields the caller set', () {
      final patch = UpdateTodoRequest(
        revision: 1,
        completed: const Optional.present(true),
      );

      expect(wireJson(patch.toJson()), <String, dynamic>{
        'revision': 1,
        'completed': true,
      });
    });

    test('keeps an unspecified colour out of the request', () {
      final patch = UpdateTodoRequest(
        revision: 2,
        completed: const Optional.present(false),
      );

      expect(wireJson(patch.toJson()).containsKey('color'), isFalse);
      expect(wireJson(patch.toJson()).containsKey('title'), isFalse);
      expect(wireJson(patch.toJson()).containsKey('notes'), isFalse);
      expect(wireJson(patch.toJson()).containsKey('due_kind'), isFalse);
      expect(wireJson(patch.toJson()).containsKey('due_date'), isFalse);
      expect(wireJson(patch.toJson()).containsKey('due_at'), isFalse);
    });

    test('sends an explicit null colour to restore the default', () {
      final patch = UpdateTodoRequest(
        revision: 3,
        color: const Optional.present(null),
      );

      final json = wireJson(patch.toJson());
      expect(json.containsKey('color'), isTrue);
      expect(json['color'], isNull);
      expect(json, <String, dynamic>{'revision': 3, 'color': null});
    });

    test('sends a colour value when one is chosen', () {
      final patch = UpdateTodoRequest(
        revision: 4,
        color: const Optional.present(UpdateTodoRequestColorEnum.teal),
      );

      expect(wireJson(patch.toJson())['color'], 'teal');
    });

    test('replaces the due group when the kind is sent', () {
      final patch = UpdateTodoRequest(
        revision: 5,
        dueKind: const Optional.present(UpdateTodoRequestDueKindEnum.none),
      );

      expect(wireJson(patch.toJson()), <String, dynamic>{
        'revision': 5,
        'due_kind': 'none',
      });
    });

    test('sends both the kind and its date for a date_only deadline', () {
      final patch = UpdateTodoRequest(
        revision: 6,
        dueKind: const Optional.present(UpdateTodoRequestDueKindEnum.dateOnly),
        dueDate: Optional.present(DateTime.utc(2026, 11, 13)),
      );

      expect(wireJson(patch.toJson()), <String, dynamic>{
        'revision': 6,
        'due_kind': 'date_only',
        'due_date': '2026-11-13',
      });
    });
  });

  group('CreateTodoRequest', () {
    test('omits an unset deadline instead of sending nulls', () {
      final create = CreateTodoRequest(title: '交第三章作业');

      final json = wireJson(create.toJson());
      expect(json['title'], '交第三章作业');
      expect(json.containsKey('due_kind'), isFalse);
      expect(json.containsKey('due_date'), isFalse);
      expect(json.containsKey('due_at'), isFalse);
      expect(json.containsKey('color'), isFalse);
    });

    test('sends an exact deadline as UTC RFC 3339', () {
      final create = CreateTodoRequest(
        title: '周五 17:00 前交',
        dueKind: const Optional.present(CreateTodoRequestDueKindEnum.exact),
        dueAt: Optional.present(DateTime.utc(2026, 11, 13, 9)),
      );

      final json = wireJson(create.toJson());
      expect(json['due_at'], '2026-11-13T09:00:00.000Z');
      expect(json.containsKey('due_date'), isFalse);
    });
  });
}
