import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela_api/api.dart';

Map<String, dynamic> teachingFixture(String name) =>
    jsonDecode(
          File(
            '../../contracts/fixtures/teaching/$name.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  final manifest = teachingFixture('manifest');
  for (final fixture in manifest['fixtures'] as List<dynamic>) {
    final name = (fixture['file'] as String).replaceFirst('.json', '');
    test('generated client preserves the $name response', () {
      final payload = teachingFixture(name);
      final Object response = switch (fixture['schema']) {
        'SemesterListResponse' => SemesterListResponse.fromJson(payload)!,
        'CourseListResponse' => CourseListResponse.fromJson(payload)!,
        'ScheduleListResponse' => ScheduleListResponse.fromJson(payload)!,
        'ErrorResponse' => ErrorResponse.fromJson(payload)!,
        _ => throw StateError('Unregistered fixture schema'),
      };
      expect(jsonDecode(jsonEncode(response)), payload);
    });
  }

  test('unknown semester dates and current semester remain null', () {
    final response = SemesterListResponse.fromJson(
      teachingFixture('semesters.unknown_start'),
    )!;
    expect(response.meta.currentSemesterId, isNull);
    expect(response.data.single.startsOn, isNull);
    expect(response.data.single.endsOn, isNull);
  });

  test('same course names keep distinct source identities', () {
    final response = CourseListResponse.fromJson(
      teachingFixture('courses.multisource'),
    )!;
    expect(response.data[0].name, response.data[1].name);
    expect(response.data[0].id, isNot(response.data[1].id));
    expect(
      response.data.where((course) => course.semesterId == null),
      hasLength(1),
    );
    expect(
      response.data.where((course) => course.semesterId != null),
      hasLength(1),
    );
    final ids = response.data.map((course) => course.id).toList();
    expect(ids, List<String>.of(ids)..sort());
    expect(response.meta.sourceSnapshots, hasLength(2));
  });

  test('empty and never-synced responses retain different states', () {
    final empty = ScheduleListResponse.fromJson(
      teachingFixture('schedule.empty'),
    )!;
    final never = ScheduleListResponse.fromJson(
      teachingFixture('schedule.never_synced'),
    )!;
    expect(empty.data, isEmpty);
    expect(never.data, isEmpty);
    expect(empty.meta.snapshot.status, SnapshotMetaStatusEnum.current);
    expect(never.meta.snapshot.status, SnapshotMetaStatusEnum.neverSynced);
    expect(empty.meta.snapshot.lastSuccessAt, isNotNull);
    expect(never.meta.snapshot.lastSuccessAt, isNull);
  });

  test(
    'source authentication failure preserves a readable cached response',
    () {
      final response = ScheduleListResponse.fromJson(
        teachingFixture('schedule.source_auth_required'),
      )!;
      expect(response.data, hasLength(1));
      expect(response.meta.snapshot.status, SnapshotMetaStatusEnum.stale);
      expect(response.meta.snapshot.lastErrorCode, 'SOURCE_AUTH_REQUIRED');
    },
  );

  test('lesson maps to the existing calendar branch without losing fields', () {
    final payload = teachingFixture('schedule.normal');
    final lesson = ScheduleListResponse.fromJson(payload)!.data.single;
    final item = LessonItem.fromJson({
      ...lesson.toJson(),
      'kind': 'lesson',
      'id': 'lesson:${lesson.id}:${lesson.startsAt.toIso8601String()}',
      'lesson_id': lesson.id,
      'starts_at': lesson.startsAt.toIso8601String(),
      'ends_at': lesson.endsAt.toIso8601String(),
    })!;
    expect(item.lessonId, lesson.id);
    expect(item.courseOfferingId, lesson.courseOfferingId);
    expect(item.startsAt, lesson.startsAt);
    expect(item.endsAt, lesson.endsAt);
    final wire = jsonDecode(jsonEncode(item)) as Map<String, dynamic>;
    expect(wire['location'], lesson.location);
    expect(wire['period_start'], lesson.periodStart);
    expect(wire['period_end'], lesson.periodEnd);
  });

  test('clients ignore additional response fields', () {
    final payload = teachingFixture('schedule.normal');
    payload['future_field'] = 'ignored';
    final response = ScheduleListResponse.fromJson(payload)!;
    expect(response.data, hasLength(1));
    expect(response.toJson(), isNot(contains('future_field')));
  });

  test(
    'schedule sends campus dates, filters and workbench authorization',
    () async {
      final payload = teachingFixture('schedule.normal');
      final semesterId =
          payload['meta']['snapshot']['coverage']['semester_id'] as String;
      final client = ApiClient(
        basePath: 'https://workbench.example',
        authentication: HttpBearerAuth()..accessToken = 'synthetic-token',
      );
      client.client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/schedule');
        expect(request.url.queryParameters, {
          'semester_id': semesterId,
          'from': '2026-11-09',
          'to': '2026-11-16',
          'limit': '25',
          'cursor': 'synthetic+cursor/2=',
        });
        expect(request.headers['authorization'], 'Bearer synthetic-token');
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(client.client.close);
      final response = await TeachingApi(client).getSchedule(
        semesterId,
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 16),
        limit: 25,
        cursor: 'synthetic+cursor/2=',
      );
      expect(response!.data, hasLength(1));
    },
  );
}
