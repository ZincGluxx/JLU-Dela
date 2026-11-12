import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/features/planner/calendar_service.dart';
import 'package:jlu_dela/features/planner/planner_page.dart';

final DateTime _clock = DateTime.utc(2026, 11, 10, 2);

http.Response _json(Object payload, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(payload)),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, Object?> _envelope(List<Object?> items) => {
  'data': {
    'from': '2026-11-09',
    'to': '2026-11-16',
    'items': items,
    'sources': <Object?>[],
  },
  'meta': {'request_id': 'req-1'},
};

Map<String, Object?> _lesson() => {
  'kind': 'lesson',
  'id': 'lesson-1',
  'lesson_id': 'l-1',
  'course_offering_id': 'c-1',
  'title': '高等数学',
  'starts_at': '2026-11-10T00:00:00Z',
  'ends_at': '2026-11-10T01:40:00Z',
  'location': '逸夫楼201',
};

Map<String, Object?> _assignment() => {
  'kind': 'assignment',
  'id': 'assignment-1',
  'assignment_id': 'a-1',
  'title': '第三章习题',
  'due_at': null,
  'due_kind': 'relative',
  'timing_text': '3 天后截止',
  'source_status': 'pending',
};

Map<String, Object?> _todo() => {
  'kind': 'todo',
  'id': 'todo-1',
  'todo_id': 't-1',
  'title': '交实验报告',
  'due_kind': 'exact',
  'due_at': '2026-11-12T09:00:00Z',
  'color': 'teal',
  'show_in_calendar': true,
  'completed': false,
};

Widget _harness(CalendarService service) {
  return MaterialApp(
    home: Scaffold(
      body: PlannerPage(service: service, clock: () => _clock),
    ),
  );
}

CalendarService _service(MockClient client) => CalendarService(
  apiBaseUri: Uri.parse('http://127.0.0.1:8080'),
  httpClient: client,
  timeout: const Duration(seconds: 2),
);

void main() {
  setUp(() {
    // 每个用例都从桌面宽度开始，窄屏用例自己缩小画布。
  });

  testWidgets('加载态之后渲染卡片', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _service(
      MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _json(_envelope([_lesson(), _assignment(), _todo()]));
      }),
    );

    await tester.pumpWidget(_harness(service));
    expect(find.byKey(const Key('planner-loading')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump();

    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('08:00–09:40 · 逸夫楼201'), findsOneWidget);
    expect(find.text('交实验报告'), findsOneWidget);
    expect(find.text('17:00 · 还剩 2 天'), findsOneWidget);
    expect(find.text('第三章习题'), findsOneWidget);
    expect(find.text('3 天后截止'), findsOneWidget);
    expect(find.text('2026年11月9日 – 11月15日'), findsOneWidget);
  });

  testWidgets('宽屏排成日列网格', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _service(
      MockClient((request) async {
        return _json(_envelope([_lesson()]));
      }),
    );

    await tester.pumpWidget(_harness(service));
    await tester.pump();
    await tester.pump();

    expect(find.text('周一 11/9'), findsOneWidget);
    expect(find.text('周日 11/15'), findsOneWidget);
    expect(find.text('08:00'), findsWidgets);
  });

  testWidgets('窄屏退化成按日列表', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _service(
      MockClient((request) async {
        return _json(_envelope([_lesson()]));
      }),
    );

    await tester.pumpWidget(_harness(service));
    await tester.pump();
    await tester.pump();

    expect(find.text('周一 11月9日'), findsOneWidget);
    expect(find.text('周二 11月10日'), findsOneWidget);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('没有安排'), findsWidgets);
  });

  testWidgets('空周显示文案', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _service(
      MockClient((request) async {
        return _json(_envelope(const []));
      }),
    );

    await tester.pumpWidget(_harness(service));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('planner-empty')), findsOneWidget);
    expect(find.text('本周没有安排'), findsOneWidget);
  });

  testWidgets('date_only 作业占整天，不编造时刻', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _service(
      MockClient((request) async {
        return _json(
          _envelope([
            {
              'kind': 'assignment',
              'id': 'assignment-2',
              'assignment_id': 'a-2',
              'title': '实验预习',
              'due_at': '2026-11-11T16:00:00Z',
              'due_kind': 'date_only',
              'timing_text': '',
              'source_status': 'pending',
            },
          ]),
        );
      }),
    );

    await tester.pumpWidget(_harness(service));
    await tester.pump();
    await tester.pump();

    expect(find.text('实验预习'), findsOneWidget);
    expect(find.bySemanticsLabel('作业：实验预习，全天'), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
  });

  testWidgets('卡片带语义标签', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final semantics = tester.ensureSemantics();

    final service = _service(
      MockClient((request) async {
        return _json(_envelope([_lesson()]));
      }),
    );

    await tester.pumpWidget(_harness(service));
    await tester.pump();
    await tester.pump();

    expect(
      find.bySemanticsLabel('课程：高等数学，08:00–09:40 · 逸夫楼201'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('失败后可以重试', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var calls = 0;
    final service = _service(
      MockClient((request) async {
        calls += 1;
        if (calls == 1) {
          return _json({
            'error': {
              'code': 'SOURCE_AUTH_REQUIRED',
              'message': 'The chaoxing source needs to be reconnected.',
              'request_id': 'req-409',
              'retryable': false,
              'fields': <Object?>[],
            },
          }, statusCode: 409);
        }
        return _json(_envelope([_lesson()]));
      }),
    );

    await tester.pumpWidget(_harness(service));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('planner-error')), findsOneWidget);
    expect(find.textContaining('重新连接'), findsOneWidget);

    await tester.tap(find.byKey(const Key('planner-retry')));
    await tester.pump();
    await tester.pump();

    expect(calls, 2);
    expect(find.text('高等数学'), findsOneWidget);
  });

  testWidgets('周导航翻到下一周再回到本周', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final requested = <String>[];
    final service = _service(
      MockClient((request) async {
        requested.add(request.url.queryParameters['from'] ?? '');
        return _json(_envelope([_lesson()]));
      }),
    );

    await tester.pumpWidget(_harness(service));
    await tester.pump();
    await tester.pump();
    expect(requested, ['2026-11-09']);

    await tester.tap(find.byKey(const Key('planner-next')));
    await tester.pump();
    await tester.pump();
    expect(requested.last, '2026-11-16');
    expect(find.text('2026年11月16日 – 11月22日'), findsOneWidget);

    await tester.tap(find.byKey(const Key('planner-today')));
    await tester.pump();
    await tester.pump();
    expect(requested.last, '2026-11-09');
  });
}
