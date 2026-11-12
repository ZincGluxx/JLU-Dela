import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/core/academic/academic_calendar_cache.dart';
import 'package:jlu_dela/core/academic/academic_calendar_service.dart';
import 'package:jlu_dela/core/api/api_failure.dart';
import 'package:jlu_dela/core/models/local_date.dart';

void main() {
  late Directory directory;
  late FileAcademicCalendarCache cache;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'academic-calendar-test-',
    );
    cache = FileAcademicCalendarCache(directory);
  });
  tearDown(() async => directory.delete(recursive: true));

  AcademicCalendarService service(
    Future<http.Response> Function(http.Request) handler, {
    AcademicCalendarCache? cacheOverride,
  }) => AcademicCalendarService(
    apiBaseUri: Uri.parse('https://example.test'),
    httpClient: MockClient(handler),
    cache: cacheOverride ?? cache,
    now: () => DateTime.utc(2026, 11, 12),
  );

  test(
    'real public API roundtrip for both published academic years',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      final calendar = AcademicCalendarService(
        apiBaseUri: Uri.parse('http://127.0.0.1:8080'),
        httpClient: client,
        cache: cache,
      );
      for (final year in ['2026-2027', '2025-2026']) {
        await calendar.load(academicYear: year);
        expect(calendar.snapshot.error, isNull);
        expect(calendar.snapshot.cacheError, isNull);
        expect(calendar.currentCalendar!.academicYear, year);
        expect(
          calendar.currentCalendar!.sourceUrl,
          startsWith('https://jwc.jlu.edu.cn/'),
        );
        expect(calendar.currentCalendar!.periods, hasLength(12));
        expect(await cache.read(year), isNotNull);
      }
    },
    skip: !const bool.fromEnvironment('ACADEMIC_API_SMOKE'),
  );

  test(
    'network success uses public API and persists generated contract',
    () async {
      final calendar = service((request) async {
        expect(request.url.path, '/api/v1/academic-calendar');
        expect(request.url.queryParameters['academic_year'], '2026-2027');
        expect(request.headers.containsKey('authorization'), isFalse);
        return response(fixture());
      });
      await calendar.load();
      expect(calendar.snapshot.error, isNull);
      expect(calendar.snapshot.isRefreshing, isFalse);
      expect(calendar.currentCalendar!.periods.single.startMinute, 480);
      expect(
        calendar.currentCalendar!.terms.single.teachingWeekOn(
          const LocalDate(2026, 9, 14),
        ),
        2,
      );
      expect(calendar.currentCalendar!.includesMakeupDayRules, isFalse);
      expect(await cache.read('2026-2027'), contains('synced_at'));
    },
  );

  test(
    'restart offline retains cached calendar and synchronization time',
    () async {
      final online = service((_) async => response(fixture()));
      await online.load();
      final offline = service(
        (_) async => throw http.ClientException('offline'),
      );
      await offline.load();
      expect(offline.currentCalendar!.version, 'test-v1');
      expect(offline.snapshot.error!.kind, ApiFailureKind.network);
      expect(offline.snapshot.lastSyncedAt, DateTime.utc(2026, 11, 12));
    },
  );

  test(
    'cache write failure retains previous disk cache and fresh memory data',
    () async {
      final online = service((_) async => response(fixture()));
      await online.load();
      final failing = service(
        (_) async => response(fixture(version: 'test-v2')),
        cacheOverride: FailingWriteCache(cache),
      );
      await failing.load();
      expect(failing.currentCalendar!.version, 'test-v2');
      expect(failing.snapshot.cacheError, isNotNull);
      expect(failing.snapshot.error, isNull);
      expect(await cache.read('2026-2027'), contains('test-v1'));
    },
  );

  test(
    'invalid dates and reversed ranges never replace a successful calendar',
    () async {
      var data = fixture();
      final calendar = service((_) async => response(data));
      await calendar.load();
      for (final date in [
        '2026-02-30',
        '2026-13-01',
        '2026-9-07',
        '2027-02-01',
      ]) {
        data = fixture();
        (data['terms'] as List).single['start_date'] = date;
        await calendar.refresh();
        expect(calendar.snapshot.error!.kind, ApiFailureKind.protocol);
        expect(
          calendar.currentCalendar!.terms.single.startDate,
          const LocalDate(2026, 9, 7),
        );
      }
    },
  );

  test(
    'academic years keep independent caches and never show another year',
    () async {
      final calendar = service((request) async {
        final year = request.url.queryParameters['academic_year']!;
        return response(fixture(year: year));
      });
      await calendar.load();
      await calendar.load(academicYear: '2025-2026');
      expect(calendar.currentCalendar!.academicYear, '2025-2026');
      await calendar.refresh();
      expect(calendar.snapshot.cacheError, isNull);
      expect(calendar.snapshot.academicYear, '2025-2026');
      expect(calendar.currentCalendar!.academicYear, '2025-2026');
      expect(await cache.read('2026-2027'), contains('2026-2027'));
      expect(await cache.read('2025-2026'), contains('2025-2026'));
      final offline = service(
        (_) async => throw http.ClientException('offline'),
      );
      await offline.load(academicYear: '2025-2026');
      expect(offline.currentCalendar!.academicYear, '2025-2026');
      await offline.load(academicYear: '2027-2028');
      expect(offline.currentCalendar, isNull);
    },
  );

  test('404 is exposed and cached success is preserved', () async {
    var available = true;
    final calendar = service(
      (_) async => available
          ? response(fixture())
          : http.Response(
              jsonEncode({
                'error': {
                  'code': 'ACADEMIC_CALENDAR_NOT_FOUND',
                  'message': 'Not found',
                  'request_id': 'test',
                  'retryable': false,
                  'fields': <String, dynamic>{},
                },
              }),
              404,
            ),
    );
    await calendar.load();
    available = false;
    await calendar.refresh();
    expect(calendar.snapshot.error!.code, 'ACADEMIC_CALENDAR_NOT_FOUND');
    expect(calendar.currentCalendar, isNotNull);
  });

  test('invalid time ranges are rejected without losing cached data', () async {
    var data = fixture();
    final calendar = service((_) async => response(data));
    await calendar.load();
    data = fixture();
    (data['periods'] as List).single['start_time'] = '25:00';
    await calendar.refresh();
    expect(calendar.snapshot.error!.kind, ApiFailureKind.protocol);
    expect(calendar.currentCalendar!.periods.single.startMinute, 480);
  });
}

http.Response response(Map<String, dynamic> data) => http.Response(
  jsonEncode({
    'data': data,
    'meta': {'request_id': 'test'},
  }),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> fixture({
  String year = '2026-2027',
  String version = 'test-v1',
}) => {
  'academic_year': year,
  'version': version,
  'time_zone': 'Asia/Shanghai',
  'source': {
    'url': 'https://jwc.jlu.edu.cn/calendar',
    'image_url': 'https://jwc.jlu.edu.cn/calendar.jpg',
    'published_at': '2026-05-01',
  },
  'includes_makeup_day_rules': false,
  'notes': ['不含调休规则'],
  'terms': [
    {
      'id': '$year-1',
      'name': '秋季学期',
      'start_date': '2026-09-07',
      'end_date': '2027-01-10',
      'teaching_weeks': 18,
    },
  ],
  'periods_source': {
    'url': 'https://jwc.jlu.edu.cn/periods',
    'published_at': null,
    'effective_from_term': '2023-2024-2',
  },
  'periods': [
    {'number': 1, 'start_time': '08:00', 'end_time': '08:45'},
  ],
  'events': [
    {
      'id': 'winter',
      'title': '寒假',
      'type': 'winter_break',
      'start_date': '2027-01-11',
      'end_date': '2027-02-28',
      'term_id': null,
    },
  ],
};

class FailingWriteCache implements AcademicCalendarCache {
  FailingWriteCache(this.delegate);
  final AcademicCalendarCache delegate;
  @override
  Future<String?> read(String year) => delegate.read(year);
  @override
  Future<void> write(String year, String contents) async =>
      throw const FileSystemException('read only');
}
