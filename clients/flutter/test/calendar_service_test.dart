import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/core/api/api_failure.dart';
import 'package:jlu_dela/features/planner/calendar_service.dart';
import 'package:jlu_dela_api/api.dart';

CalendarService _service(
  MockClient client, {
  Duration timeout = const Duration(seconds: 2),
  String? Function()? accessToken,
}) {
  return CalendarService(
    apiBaseUri: Uri.parse('http://127.0.0.1:8080'),
    httpClient: client,
    timeout: timeout,
    accessToken: accessToken,
  );
}

http.Response _json(Object payload, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(payload)),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, Object?> _envelope(List<Object?> items) {
  return {
    'data': {
      'from': '2026-11-09',
      'to': '2026-11-16',
      'items': items,
      'sources': [
        {
          'source': 'jlu_iedu',
          'status': 'connected',
          'last_success_at': '2026-11-09T02:00:00Z',
        },
      ],
    },
    'meta': {'request_id': 'req-1'},
  };
}

Map<String, Object?> _lesson() => {
  'kind': 'lesson',
  'id': 'lesson-1',
  'lesson_id': 'l-1',
  'course_offering_id': 'c-1',
  'title': '高等数学',
  'starts_at': '2026-11-10T00:00:00Z',
  'ends_at': '2026-11-10T01:40:00Z',
  'location': '逸夫楼201',
  'period_start': 1,
  'period_end': 2,
};

Map<String, Object?> _assignment() => {
  'kind': 'assignment',
  'id': 'assignment-1',
  'assignment_id': 'a-1',
  'course_offering_id': 'c-1',
  'title': '第三章习题',
  'due_at': '2026-11-12T09:00:00Z',
  'due_kind': 'exact',
  'timing_text': '',
  'source_status': 'pending',
  'read_at': null,
  'muted_at': null,
};

Map<String, Object?> _todo() => {
  'kind': 'todo',
  'id': 'todo-1',
  'todo_id': 't-1',
  'title': '交实验报告',
  'due_kind': 'exact',
  'due_at': '2026-11-12T09:00:00Z',
  'due_date': null,
  'color': 'teal',
  'show_in_calendar': true,
  'completed': false,
};

void main() {
  test('按 YYYY-MM-DD 发日期区间', () async {
    late Uri requested;
    final service = _service(
      MockClient((request) async {
        requested = request.url;
        return _json(_envelope(const []));
      }),
    );

    await service.load(
      from: DateTime.utc(2026, 11, 8, 16),
      to: DateTime.utc(2026, 11, 15, 16),
    );

    expect(requested.path, '/api/v1/calendar');
    expect(requested.queryParameters['from'], '2026-11-09');
    expect(requested.queryParameters['to'], '2026-11-16');
  });

  test('带上会话令牌的 Bearer 头', () async {
    late http.Request captured;
    final service = _service(
      MockClient((request) async {
        captured = request;
        return _json(_envelope(const []));
      }),
      accessToken: () => 'access-token-1',
    );

    await service.load(
      from: DateTime.utc(2026, 11, 8, 16),
      to: DateTime.utc(2026, 11, 15, 16),
    );

    expect(captured.headers['Authorization'], 'Bearer access-token-1');
  });

  test('没有令牌时不伪造 Authorization 头', () async {
    late http.Request captured;
    final service = _service(
      MockClient((request) async {
        captured = request;
        return _json(_envelope(const []));
      }),
    );

    await service.load(
      from: DateTime.utc(2026, 11, 8, 16),
      to: DateTime.utc(2026, 11, 15, 16),
    );

    expect(captured.headers.containsKey('Authorization'), isFalse);
  });

  test('解析三种事项与来源状态', () async {
    final service = _service(
      MockClient((request) async {
        return _json(_envelope([_lesson(), _assignment(), _todo()]));
      }),
    );

    final data = await service.load(
      from: DateTime.utc(2026, 11, 8, 16),
      to: DateTime.utc(2026, 11, 15, 16),
    );

    expect(data.items, hasLength(3));
    final lesson = data.items[0].actualInstance;
    expect(lesson, isA<LessonItem>());
    expect((lesson as LessonItem).title, '高等数学');
    expect(lesson.location.value, '逸夫楼201');
    expect(lesson.startsAt, DateTime.utc(2026, 11, 10));

    final assignment = data.items[1].actualInstance as AssignmentItem;
    expect(assignment.dueKind, AssignmentItemDueKindEnum.exact);
    expect(assignment.dueAt.value, DateTime.utc(2026, 11, 12, 9));

    final todo = data.items[2].actualInstance as TodoItem;
    expect(todo.color.value, TodoItemColorEnum.teal);
    expect(todo.showInCalendar, isTrue);
    expect(todo.completed, isFalse);

    expect(data.sources.single.source_, SourceStatusSource_Enum.jluIedu);
    expect(data.sources.single.status, SourceStatusStatusEnum.connected);
  });

  test('Optional 区分键缺失、显式 null 和值', () async {
    final missing = _todo()..remove('color');
    final explicitNull = _todo()..['color'] = null;
    final service = _service(
      MockClient((request) async {
        return _json(_envelope([missing, explicitNull, _todo()]));
      }),
    );

    final data = await service.load(
      from: DateTime.utc(2026, 11, 8, 16),
      to: DateTime.utc(2026, 11, 15, 16),
    );

    final absent = (data.items[0].actualInstance as TodoItem).color;
    expect(absent.isPresent, isFalse);
    final nulled = (data.items[1].actualInstance as TodoItem).color;
    expect(nulled.isPresent, isTrue);
    expect(nulled.value, isNull);
    final present = (data.items[2].actualInstance as TodoItem).color;
    expect(present.isPresent, isTrue);
    expect(present.value, TodoItemColorEnum.teal);
  });

  test('401 折成可区分的登录失效文案', () async {
    final service = _service(
      MockClient((request) async {
        return _json({
          'error': {
            'code': 'TOKEN_EXPIRED',
            'message': 'The access token has expired.',
            'request_id': 'req-401',
            'retryable': false,
            'fields': <Object?>[],
          },
        }, statusCode: 401);
      }),
    );

    final failure = await service
        .load(
          from: DateTime.utc(2026, 11, 8, 16),
          to: DateTime.utc(2026, 11, 15, 16),
        )
        .then<Object?>((value) => value, onError: (Object error) => error);

    expect(failure, isA<ApiFailure>());
    final apiFailure = failure! as ApiFailure;
    expect(apiFailure.kind, ApiFailureKind.server);
    expect(apiFailure.statusCode, 401);
    expect(apiFailure.code, 'TOKEN_EXPIRED');
    expect(apiFailure.requestId, 'req-401');
    expect(calendarFailureMessage(apiFailure), contains('重新登录'));
  });

  test('422 带上校验失败文案', () async {
    final service = _service(
      MockClient((request) async {
        return _json({
          'error': {
            'code': 'VALIDATION_FAILED',
            'message': 'Request validation failed.',
            'request_id': 'req-422',
            'retryable': false,
            'fields': [
              {'path': 'from', 'code': 'INVALID_FORMAT'},
            ],
          },
        }, statusCode: 422);
      }),
    );

    final failure = await service
        .load(
          from: DateTime.utc(2026, 11, 8, 16),
          to: DateTime.utc(2026, 11, 15, 16),
        )
        .then<Object?>((value) => value, onError: (Object error) => error);

    final apiFailure = failure! as ApiFailure;
    expect(apiFailure.statusCode, 422);
    expect(apiFailure.code, 'VALIDATION_FAILED');
    expect(calendarFailureMessage(apiFailure), contains('日期区间'));
  });

  test('409 提示来源需要重新连接', () async {
    final service = _service(
      MockClient((request) async {
        return _json({
          'error': {
            'code': 'SOURCE_AUTH_REQUIRED',
            'message': 'The chaoxing source needs to be reconnected.',
            'request_id': 'req-409',
            'retryable': false,
            'fields': <Object?>[],
          },
        }, statusCode: 409);
      }),
    );

    final failure = await service
        .load(
          from: DateTime.utc(2026, 11, 8, 16),
          to: DateTime.utc(2026, 11, 15, 16),
        )
        .then<Object?>((value) => value, onError: (Object error) => error);

    final apiFailure = failure! as ApiFailure;
    expect(apiFailure.statusCode, 409);
    expect(calendarFailureMessage(apiFailure), contains('重新连接'));
  });

  test('未知的 kind 折成 protocol', () async {
    final service = _service(
      MockClient((request) async {
        return _json({
          'data': {
            'from': '2026-11-09',
            'to': '2026-11-16',
            'items': [
              {'kind': 'holiday', 'id': 'x'},
            ],
            'sources': <Object?>[],
          },
          'meta': {'request_id': 'req-x'},
        });
      }),
    );

    final failure = await service
        .load(
          from: DateTime.utc(2026, 11, 8, 16),
          to: DateTime.utc(2026, 11, 15, 16),
        )
        .then<Object?>((value) => value, onError: (Object error) => error);

    expect((failure! as ApiFailure).kind, ApiFailureKind.protocol);
  });

  test('超时折成 timeout', () async {
    final service = _service(
      MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return _json(_envelope(const []));
      }),
      timeout: const Duration(milliseconds: 20),
    );

    final failure = await service
        .load(
          from: DateTime.utc(2026, 11, 8, 16),
          to: DateTime.utc(2026, 11, 15, 16),
        )
        .then<Object?>((value) => value, onError: (Object error) => error);

    expect((failure! as ApiFailure).kind, ApiFailureKind.timeout);
  });
}
