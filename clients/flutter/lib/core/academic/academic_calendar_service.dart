import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jlu_dela_api/api.dart' as api;

import '../api/api_failure.dart';
import '../models/local_date.dart';
import 'academic_calendar.dart';
import 'academic_calendar_cache.dart';
import 'academic_calendar_contract.dart';
import 'academic_calendar_snapshot.dart';

export 'academic_calendar.dart';
export 'academic_calendar_snapshot.dart';

class AcademicCalendarService extends ChangeNotifier {
  AcademicCalendarService({
    required Uri apiBaseUri,
    required http.Client httpClient,
    required this.cache,
    this.now = DateTime.now,
    this.timeout = const Duration(seconds: 10),
  }) : _client = api.ApiClient(basePath: apiBaseUri.toString()),
       _snapshot = AcademicCalendarSnapshot(academicYear: currentAcademicYear) {
    _client.client = httpClient;
  }

  static const currentAcademicYear = '2026-2027';

  final api.ApiClient _client;
  final AcademicCalendarCache cache;
  final DateTime Function() now;
  final Duration timeout;
  AcademicCalendarSnapshot _snapshot;
  final _snapshots = <String, AcademicCalendarSnapshot>{};
  final _loads = <String, Future<void>>{};
  Future<void> _pending = Future.value();

  static const publishedAcademicYears = ['2025-2026', '2026-2027'];

  AcademicCalendarSnapshot snapshotForYear(String year) =>
      _snapshots[year] ?? AcademicCalendarSnapshot(academicYear: year);

  OfficialAcademicCalendar? calendarOn(LocalDate date) {
    final calendars = [
      for (final year in publishedAcademicYears)
        ?snapshotForYear(year).calendar,
    ];
    for (final calendar in calendars) {
      if (calendar.termOn(date) != null) return calendar;
    }
    for (final calendar in calendars) {
      if (calendar.events.any(
        (event) =>
            date.compareTo(event.startDate) >= 0 &&
            date.compareTo(event.endDate) <= 0,
      )) {
        return calendar;
      }
    }
    return null;
  }

  Future<void> ensureLoaded(String year) {
    if (_loads[year] case final pending?) return pending;
    if (_snapshots.containsKey(year)) return Future.value();
    final pending = load(academicYear: year);
    _loads[year] = pending;
    return pending.whenComplete(() => _loads.remove(year));
  }

  AcademicCalendarSnapshot get snapshot => _snapshot;
  OfficialAcademicCalendar? get currentCalendar => _snapshot.calendar;

  Future<void> load({String? academicYear}) => _enqueue(academicYear, true);
  Future<void> refresh({String? academicYear}) =>
      _enqueue(academicYear ?? _snapshot.academicYear, false);

  Future<void> _enqueue(String? academicYear, bool readCache) {
    final year = academicYear ?? currentAcademicYear;
    final parts = year.split('-');
    if (!RegExp(r'^\d{4}-\d{4}$').hasMatch(year) ||
        int.parse(parts[1]) != int.parse(parts[0]) + 1) {
      throw ArgumentError.value(year, 'academicYear');
    }
    final next = _pending.then((_) => _sync(year, readCache));
    _pending = next;
    return next;
  }

  Future<void> _sync(String year, bool readCache) async {
    var calendar = snapshotForYear(year).calendar;
    var syncedAt = snapshotForYear(year).lastSyncedAt;
    String? cacheError;
    if (readCache) {
      try {
        final contents = await cache.read(year);
        if (contents != null) {
          final stored = jsonDecode(contents) as Map<String, dynamic>;
          final data = _decode(stored['data'], year);
          calendar = academicCalendarFromContract(data);
          syncedAt = DateTime.parse(stored['synced_at'] as String);
        }
      } on Object catch (error) {
        cacheError = error.toString();
      }
    }
    _snapshot = AcademicCalendarSnapshot(
      academicYear: year,
      calendar: calendar,
      lastSyncedAt: syncedAt,
      cacheError: cacheError,
      isRefreshing: true,
    );
    _snapshots[year] = _snapshot;
    notifyListeners();
    ApiFailure? failure;
    try {
      final response = await api.CalendarApi(
        _client,
      ).getAcademicCalendarWithHttpInfo(academicYear: year).timeout(timeout);
      if (response.statusCode != 200) {
        throw apiFailureFromErrorBody(response.statusCode, response.body);
      }
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final data = _decode(body['data'], year);
      final fresh = academicCalendarFromContract(data);
      final fetchedAt = now().toUtc();
      try {
        await cache.write(
          year,
          jsonEncode({'data': data, 'synced_at': fetchedAt.toIso8601String()}),
        );
        cacheError = null;
      } on Object catch (error) {
        cacheError = error.toString();
      }
      calendar = fresh;
      syncedAt = fetchedAt;
    } on ApiFailure catch (error) {
      failure = error;
    } on api.ApiException catch (error) {
      failure = mapApiException(error);
    } on TimeoutException catch (error) {
      failure = ApiFailure(
        kind: ApiFailureKind.timeout,
        technicalMessage: '$error',
      );
    } on http.ClientException catch (error) {
      failure = ApiFailure(
        kind: ApiFailureKind.network,
        technicalMessage: '$error',
      );
    } on IOException catch (error) {
      failure = ApiFailure(
        kind: ApiFailureKind.network,
        technicalMessage: '$error',
      );
    } on Object catch (error) {
      failure = ApiFailure(
        kind: ApiFailureKind.protocol,
        technicalMessage: '$error',
      );
    }
    _snapshot = AcademicCalendarSnapshot(
      academicYear: year,
      calendar: calendar,
      lastSyncedAt: syncedAt,
      cacheError: cacheError,
      error: failure,
    );
    _snapshots[year] = _snapshot;
    notifyListeners();
  }

  api.AcademicCalendar _decode(Object? json, String year) {
    validateAcademicDates(json);
    final data = api.AcademicCalendar.fromJson(json);
    if (data == null || data.academicYear != year) {
      throw const FormatException(
        'Academic calendar year does not match request.',
      );
    }
    return data;
  }
}
