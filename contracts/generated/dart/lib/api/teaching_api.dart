//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class TeachingApi {
  TeachingApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// List the caller's expanded lessons in a semester and date range
  ///
  /// Draft only; this route is not implemented. Reads saved actual lesson occurrences for the bearer user. A missing or invisible semester returns 404. `semester_id`, `from` and `to` are all required.  `from` is inclusive and `to` exclusive, interpreted as campus dates in `Asia/Shanghai`; `from < to` and the range is at most 93 calendar days. Convert both midnights to UTC before applying interval overlap: `starts_at < to AND ends_at > from`, including cross-midnight lessons. Unknown school dates or period times must not produce guessed lessons.  Sort by `starts_at` ascending, then `id` ascending. The cursor binds the user, semester, date range and ordering. Malformed or mismatched cursors return 422 `BAD_CURSOR`; other invalid query values return 422 `VALIDATION_FAILED`. Calendar aggregation must traverse every page or use an equivalent complete internal range query.  Snapshot metadata describes the requested range. A failed refresh preserves cached lessons and reports `stale` and `last_error_code`, including `SOURCE_AUTH_REQUIRED`; it does not turn this read into 409. Partial observations never remove unseen lessons. Removal after a cancellation or move requires a complete, serially confirmed scope; the device upload and concurrency protocol remains owned by A. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] semesterId (required):
  ///   Workbench semester ID owned by the caller.
  ///
  /// * [DateTime] from (required):
  ///   Inclusive start day in Asia/Shanghai.
  ///
  /// * [DateTime] to (required):
  ///   Exclusive end day in Asia/Shanghai, at most 93 days after from.
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  ///
  /// * [int] limit:
  ///   Maximum number of records on this page.
  ///
  /// * [String] cursor:
  ///   Opaque meta.next_cursor from the previous page, bound to the caller, filters and ordering.
  Future<Response> getScheduleWithHttpInfo(String semesterId, DateTime from, DateTime to, { String? xRequestId, int? limit, String? cursor, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/schedule';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'semester_id', semesterId));
      queryParams.addAll(_queryParams('', 'from', _dateFormatter.format(from)));
      queryParams.addAll(_queryParams('', 'to', _dateFormatter.format(to)));
    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
    }
    if (cursor != null) {
      queryParams.addAll(_queryParams('', 'cursor', cursor));
    }

    if (xRequestId != null) {
      headerParams[r'X-Request-Id'] = parameterToString(xRequestId);
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// List the caller's expanded lessons in a semester and date range
  ///
  /// Draft only; this route is not implemented. Reads saved actual lesson occurrences for the bearer user. A missing or invisible semester returns 404. `semester_id`, `from` and `to` are all required.  `from` is inclusive and `to` exclusive, interpreted as campus dates in `Asia/Shanghai`; `from < to` and the range is at most 93 calendar days. Convert both midnights to UTC before applying interval overlap: `starts_at < to AND ends_at > from`, including cross-midnight lessons. Unknown school dates or period times must not produce guessed lessons.  Sort by `starts_at` ascending, then `id` ascending. The cursor binds the user, semester, date range and ordering. Malformed or mismatched cursors return 422 `BAD_CURSOR`; other invalid query values return 422 `VALIDATION_FAILED`. Calendar aggregation must traverse every page or use an equivalent complete internal range query.  Snapshot metadata describes the requested range. A failed refresh preserves cached lessons and reports `stale` and `last_error_code`, including `SOURCE_AUTH_REQUIRED`; it does not turn this read into 409. Partial observations never remove unseen lessons. Removal after a cancellation or move requires a complete, serially confirmed scope; the device upload and concurrency protocol remains owned by A. 
  ///
  /// Parameters:
  ///
  /// * [String] semesterId (required):
  ///   Workbench semester ID owned by the caller.
  ///
  /// * [DateTime] from (required):
  ///   Inclusive start day in Asia/Shanghai.
  ///
  /// * [DateTime] to (required):
  ///   Exclusive end day in Asia/Shanghai, at most 93 days after from.
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  ///
  /// * [int] limit:
  ///   Maximum number of records on this page.
  ///
  /// * [String] cursor:
  ///   Opaque meta.next_cursor from the previous page, bound to the caller, filters and ordering.
  Future<ScheduleListResponse?> getSchedule(String semesterId, DateTime from, DateTime to, { String? xRequestId, int? limit, String? cursor, Future<void>? abortTrigger, }) async {
    final response = await getScheduleWithHttpInfo(semesterId, from, to, xRequestId: xRequestId, limit: limit, cursor: cursor, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ScheduleListResponse',) as ScheduleListResponse;
    
    }
    return null;
  }

  /// List the caller's shared course offerings
  ///
  /// Draft only; this route is not implemented. Reads saved normalized courses for the bearer user. Omitting a filter leaves it unrestricted. `semester_id` matches exactly; a missing or invisible semester returns 404. Courses with an unknown semester have `semester_id: null` and appear only when no semester filter is supplied. A source filter matches a course with that source association, without discarding its other `source_refs`. Equal course names do not imply shared identity.  Sort by source `name` ascending, then `id` ascending, regardless of the user's remark. The cursor binds the user, all filters and ordering. Malformed or mismatched cursors return 422 `BAD_CURSOR`; other invalid query values return 422 `VALIDATION_FAILED`.  Per-source metadata is a draft choice pending A/C/E review. With a source filter, `source_snapshots` contains exactly that source; without it, it contains `jlu_iedu` then `chaoxing`, including sources never synced. Source failures preserve cached records and are reported in the corresponding snapshot, not as 409 or a workbench 401. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  ///
  /// * [String] semesterId:
  ///   Exact workbench semester ID owned by the caller.
  ///
  /// * [TeachingSource] source_:
  ///
  /// * [bool] retained:
  ///   Filter the user's retained preference. Omit to return both values.
  ///
  /// * [int] limit:
  ///   Maximum number of records on this page.
  ///
  /// * [String] cursor:
  ///   Opaque meta.next_cursor from the previous page, bound to the caller, filters and ordering.
  Future<Response> listCoursesWithHttpInfo({ String? xRequestId, String? semesterId, TeachingSource? source_, bool? retained, int? limit, String? cursor, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/courses';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (semesterId != null) {
      queryParams.addAll(_queryParams('', 'semester_id', semesterId));
    }
    if (source_ != null) {
      queryParams.addAll(_queryParams('', 'source', source_));
    }
    if (retained != null) {
      queryParams.addAll(_queryParams('', 'retained', retained));
    }
    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
    }
    if (cursor != null) {
      queryParams.addAll(_queryParams('', 'cursor', cursor));
    }

    if (xRequestId != null) {
      headerParams[r'X-Request-Id'] = parameterToString(xRequestId);
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// List the caller's shared course offerings
  ///
  /// Draft only; this route is not implemented. Reads saved normalized courses for the bearer user. Omitting a filter leaves it unrestricted. `semester_id` matches exactly; a missing or invisible semester returns 404. Courses with an unknown semester have `semester_id: null` and appear only when no semester filter is supplied. A source filter matches a course with that source association, without discarding its other `source_refs`. Equal course names do not imply shared identity.  Sort by source `name` ascending, then `id` ascending, regardless of the user's remark. The cursor binds the user, all filters and ordering. Malformed or mismatched cursors return 422 `BAD_CURSOR`; other invalid query values return 422 `VALIDATION_FAILED`.  Per-source metadata is a draft choice pending A/C/E review. With a source filter, `source_snapshots` contains exactly that source; without it, it contains `jlu_iedu` then `chaoxing`, including sources never synced. Source failures preserve cached records and are reported in the corresponding snapshot, not as 409 or a workbench 401. 
  ///
  /// Parameters:
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  ///
  /// * [String] semesterId:
  ///   Exact workbench semester ID owned by the caller.
  ///
  /// * [TeachingSource] source_:
  ///
  /// * [bool] retained:
  ///   Filter the user's retained preference. Omit to return both values.
  ///
  /// * [int] limit:
  ///   Maximum number of records on this page.
  ///
  /// * [String] cursor:
  ///   Opaque meta.next_cursor from the previous page, bound to the caller, filters and ordering.
  Future<CourseListResponse?> listCourses({ String? xRequestId, String? semesterId, TeachingSource? source_, bool? retained, int? limit, String? cursor, Future<void>? abortTrigger, }) async {
    final response = await listCoursesWithHttpInfo(xRequestId: xRequestId, semesterId: semesterId, source_: source_, retained: retained, limit: limit, cursor: cursor, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'CourseListResponse',) as CourseListResponse;
    
    }
    return null;
  }

  /// List the caller's saved semesters
  ///
  /// Draft only; this route is not implemented. Reads normalized workbench data for the bearer user and does not initiate a campus request. `current_semester_id` is null without reliable current-term evidence.  Sort by `starts_on` descending, nulls last, then `id` ascending. The cursor must continue into the null-date region and is bound to the user and ordering. A malformed or mismatched cursor returns 422 `BAD_CURSOR`; other invalid query values return 422 `VALIDATION_FAILED`.  An unobserved source returns an empty list with `never_synced`; a complete empty snapshot returns an empty list with `current`. A failed refresh keeps saved data and reports `stale` with `last_error_code`. Source authorization failure does not turn this cached read into 409 or invalidate the workbench identity. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  ///
  /// * [int] limit:
  ///   Maximum number of records on this page.
  ///
  /// * [String] cursor:
  ///   Opaque meta.next_cursor from the previous page, bound to the caller, filters and ordering.
  Future<Response> listSemestersWithHttpInfo({ String? xRequestId, int? limit, String? cursor, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/semesters';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
    }
    if (cursor != null) {
      queryParams.addAll(_queryParams('', 'cursor', cursor));
    }

    if (xRequestId != null) {
      headerParams[r'X-Request-Id'] = parameterToString(xRequestId);
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// List the caller's saved semesters
  ///
  /// Draft only; this route is not implemented. Reads normalized workbench data for the bearer user and does not initiate a campus request. `current_semester_id` is null without reliable current-term evidence.  Sort by `starts_on` descending, nulls last, then `id` ascending. The cursor must continue into the null-date region and is bound to the user and ordering. A malformed or mismatched cursor returns 422 `BAD_CURSOR`; other invalid query values return 422 `VALIDATION_FAILED`.  An unobserved source returns an empty list with `never_synced`; a complete empty snapshot returns an empty list with `current`. A failed refresh keeps saved data and reports `stale` with `last_error_code`. Source authorization failure does not turn this cached read into 409 or invalidate the workbench identity. 
  ///
  /// Parameters:
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  ///
  /// * [int] limit:
  ///   Maximum number of records on this page.
  ///
  /// * [String] cursor:
  ///   Opaque meta.next_cursor from the previous page, bound to the caller, filters and ordering.
  Future<SemesterListResponse?> listSemesters({ String? xRequestId, int? limit, String? cursor, Future<void>? abortTrigger, }) async {
    final response = await listSemestersWithHttpInfo(xRequestId: xRequestId, limit: limit, cursor: cursor, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SemesterListResponse',) as SemesterListResponse;
    
    }
    return null;
  }
}
