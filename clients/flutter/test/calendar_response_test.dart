import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela_api/api.dart';

void main() {
  test(
    'mixed calendar response round trips without requiring other branches',
    () {
      final payload = <String, dynamic>{
        'data': {
          'from': '2026-11-11',
          'to': '2026-11-18',
          'items': [
            {
              'kind': 'lesson',
              'id': 'lesson:1:2026-11-11T01:00:00.000Z',
              'lesson_id': '1',
              'course_offering_id': 'course-1',
              'title': 'Math',
              'starts_at': '2026-11-11T01:00:00.000Z',
              'ends_at': '2026-11-11T02:00:00.000Z',
            },
            {
              'kind': 'assignment',
              'id': 'assignment:1',
              'assignment_id': '1',
              'title': 'Reading',
              'due_kind': 'relative',
              'timing_text': '3 days left',
              'due_at': null,
            },
            {
              'kind': 'todo',
              'id': 'todo:ed3297c3-f015-4129-9d2c-95b1fcff2986',
              'todo_id': 'ed3297c3-f015-4129-9d2c-95b1fcff2986',
              'title': 'Review',
              'due_kind': 'date_only',
              'due_date': '2026-11-12',
              'color': null,
              'show_in_calendar': true,
              'completed': false,
            },
          ],
          'sources': [],
        },
        'meta': {'request_id': 'calendar-test'},
      };
      final response = CalendarResponse.fromJson(payload)!;
      expect(response.data.items, hasLength(3));
      expect(response.data.items[0].actualInstance, isA<LessonItem>());
      expect(response.data.items[1].actualInstance, isA<AssignmentItem>());
      expect(response.data.items[2].actualInstance, isA<TodoItem>());
      expect(jsonDecode(jsonEncode(response)), payload);
    },
  );

  test('calendar rejects unknown kinds instead of losing an item', () {
    expect(
      () => CalendarItem.fromJson({'kind': 'other'}),
      throwsFormatException,
    );
  });
}
