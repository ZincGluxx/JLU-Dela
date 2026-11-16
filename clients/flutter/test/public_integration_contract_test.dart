import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/core/auth/account_gateway.dart';
import 'package:jlu_dela_api/api.dart';
import 'package:uuid/uuid.dart';

Map<String, Object?> teachingPayload() {
  const reference = {
    'source': 'jlu_iedu',
    'source_scope': '2026-2027-1',
    'source_id': 'synthetic-course',
  };
  return {
    'format': 'jlu_dela_teaching_backup',
    'format_version': 1,
    'exported_at_utc': '2026-11-16T00:00:00.000Z',
    'timetables': [
      {
        'semester_code': '2026-2027-1',
        'name': '合成学期',
        'is_current': true,
        'starts_on': '2026-08-24',
        'total_weeks': 20,
        'observed_at_utc': '2026-11-15T00:00:00.000Z',
        'courses': [
          {'course_ref': reference, 'name': '合成课程', 'teacher': null},
        ],
        'lessons': [
          {
            'course_ref': reference,
            'title': '合成课次',
            'starts_at_utc': '2026-11-16T00:00:00.000Z',
            'ends_at_utc': '2026-11-16T01:30:00.000Z',
            'location': null,
            'period_start': 1,
            'period_end': 2,
            'weekday': 1,
            'week_number': 13,
            'note': null,
          },
        ],
      },
    ],
    'period_times': [
      {
        'campus': '合成校区',
        'period': 1,
        'start_minute': 480,
        'end_minute': 525,
        'observed_at_utc': '2026-11-15T00:00:00.000Z',
      },
    ],
    'course_preferences': [
      {'course_ref': reference, 'remark': null, 'retained': true},
    ],
    'academic_completion': {
      'selection_semester': '2026-2027-1',
      'current_semester': '2026-2027-1',
      'observed_at_utc': '2026-11-15T00:00:00.000Z',
      'plans': [
        {
          'id': 'synthetic-plan',
          'name': '合成培养方案',
          'study_type': null,
          'calculated_at_school': '2026年11月15日 学校计算',
          'required_credits': '160.00',
          'earned_credits': '尚未计算',
          'selected_credits': null,
          'groups': [
            {
              'id': 'synthetic-group',
              'parent_id': null,
              'name': '合成课组',
              'kind': '任选一组',
              'required_credits': '10.0',
              'earned_credits': '0.0',
              'selected_credits': '3.0',
              'course_nature': null,
              'required_courses': null,
              'earned_courses': null,
              'required_groups': 1,
              'earned_groups': 0,
              'choice_groups': 2,
            },
          ],
        },
      ],
    },
  };
}

void main() {
  test('generated management API reads only the caller scope set', () async {
    final client = ApiClient(basePath: 'https://api.example.invalid')
      ..addDefaultHeader('Authorization', 'Bearer synthetic-token');
    client.client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/me/management');
      expect(request.url.query, isEmpty);
      expect(request.headers['Authorization'], 'Bearer synthetic-token');
      return http.Response(
        jsonEncode({
          'data': {
            'campus': false,
            'college_ids': ['college-a'],
          },
          'meta': {'request_id': 'synthetic-request'},
        }),
        200,
      );
    });
    addTearDown(client.client.close);
    final result = await MeApi(client).getMyManagement();
    expect(result!.data.campus, isFalse);
    expect(result.data.collegeIds, {'college-a'});
  });

  test(
    'typed teaching payload preserves B fields, nulls and school meanings',
    () {
      final payload = TeachingBackupPayload.fromJson(teachingPayload())!;
      final encoded = jsonDecode(jsonEncode(payload));
      expect(encoded, teachingPayload());
      expect(encoded['timetables'][0]['starts_on'], '2026-08-24');
      expect(
        encoded['academic_completion']['plans'][0]['earned_credits'],
        '尚未计算',
      );
      expect(encoded.toString(), isNot(contains('user_id')));
    },
  );

  test(
    'unselected teaching partitions remain omitted rather than empty or null',
    () {
      final selected = teachingPayload()
        ..remove('timetables')
        ..remove('period_times')
        ..remove('academic_completion');
      final payload = TeachingBackupPayload.fromJson(selected)!;
      expect(jsonDecode(jsonEncode(payload)), selected);
    },
  );

  test(
    'manual payload construction explicitly omits unselected collections',
    () {
      final source = TeachingBackupPayload.fromJson(teachingPayload())!;
      final payload = TeachingBackupPayload(
        format: source.format,
        formatVersion: source.formatVersion,
        exportedAtUtc: source.exportedAtUtc,
        timetables: const Optional.absent(),
        periodTimes: const Optional.absent(),
        coursePreferences: source.coursePreferences,
      );
      final selected = teachingPayload()
        ..remove('timetables')
        ..remove('period_times')
        ..remove('academic_completion');
      expect(jsonDecode(jsonEncode(payload)), selected);
    },
  );

  test('generated teaching snapshot accepts the empty deleted state', () async {
    final client = ApiClient();
    addTearDown(client.client.close);
    final data = {
      'revision': 0,
      'deleted': true,
      'payload': null,
      'updated_at': null,
    };
    final snapshot =
        await client.deserializeAsync(
              jsonEncode(data),
              'TeachingBackupSnapshot',
            )
            as TeachingBackupSnapshot;
    expect(jsonDecode(jsonEncode(snapshot)), data);
  });

  final base = Platform.environment['PUBLIC_INTEGRATION_TEST_API'];
  test(
    'generated teaching API uses real HTTP with private CAS and exact retry',
    () async {
      final uri = Uri.parse(base!);
      final transport = http.Client();
      addTearDown(transport.close);
      final accounts = HttpAccountGateway(baseUri: uri, httpClient: transport);
      final clients = <ApiClient>[];
      final suffix = DateTime.now().microsecondsSinceEpoch % 10000000;
      for (final prefix in ['1381', '1382']) {
        final phone = '$prefix${suffix.toString().padLeft(7, '0')}';
        expect((await accounts.sendPhoneCode(phone)).devMode, isTrue);
        final credentials = await accounts.loginWithPhone(
          phone: phone,
          smsCode: '114514',
        );
        clients.add(
          ApiClient(basePath: base)..addDefaultHeader(
            'Authorization',
            'Bearer ${credentials.accessToken}',
          ),
        );
      }
      addTearDown(() {
        for (final client in clients) {
          client.client.close();
        }
      });
      final api = PersonalBackupApi(clients.first);
      final otherApi = PersonalBackupApi(clients.last);
      final initial = (await api.getTeachingBackup())!.data;
      expect(initial.revision, 0);
      expect(initial.deleted, isTrue);
      final management = await MeApi(clients.first).getMyManagement();
      expect(management!.data.campus, isFalse);
      expect(management.data.collegeIds, isEmpty);
      final notesBefore = (await api.getNotesBackup())!.data;
      final payload = TeachingBackupPayload.fromJson(teachingPayload())!;
      final request = PutTeachingBackupRequest(
        expectedRevision: 0,
        payload: payload,
      );
      final key = const Uuid().v4();
      final receipt = (await api.putTeachingBackup(key, request))!.data;
      expect(receipt.revision, 1);
      final replayed = (await api.putTeachingBackup(key, request))!.data;
      expect(replayed.revision, receipt.revision);
      expect(
        jsonDecode(jsonEncode((await api.getTeachingBackup())!.data.payload)),
        teachingPayload(),
      );
      expect((await otherApi.getTeachingBackup())!.data.revision, 0);
      expect((await api.getNotesBackup())!.data, notesBefore);
      await expectLater(
        api.putTeachingBackup(const Uuid().v4(), request),
        throwsA(
          isA<ApiException>().having((error) => error.code, 'status', 409),
        ),
      );
      final deleted = await api.deleteTeachingBackup(
        const Uuid().v4(),
        DeleteTeachingBackupRequest(expectedRevision: 1),
      );
      expect(deleted!.data.revision, 2);
      final snapshot = (await api.getTeachingBackup())!.data;
      expect(snapshot.deleted, isTrue);
      expect(snapshot.payload, isNull);
      await expectLater(
        api.putTeachingBackup(const Uuid().v4(), request),
        throwsA(
          isA<ApiException>().having((error) => error.code, 'status', 409),
        ),
      );
      expect((await api.getTeachingBackup())!.data.deleted, isTrue);
      expect((await otherApi.getTeachingBackup())!.data.revision, 0);
    },
    skip: base == null
        ? 'Requires an isolated PUBLIC_INTEGRATION_TEST_API.'
        : false,
  );
}
