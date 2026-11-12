//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class CalendarApi {
  CalendarApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Read study calendar entries in a date range
  ///
  /// `from` is inclusive and `to` is exclusive, both interpreted as calendar days in `Asia/Shanghai`. The first release accepts at most 93 days.  Boundaries use interval overlap rather than point containment:  - lesson: `starts_at < to AND ends_at > from` - assignment and todo: `due_at >= from AND due_at < to`, or the whole   calendar day for `date_only`  `items` is a discriminated union on `kind` (`lesson`, `assignment`, `todo`). Lessons come from the timetable source, assignments from the assignment source and todos from this service. An assignment is never duplicated into a todo.  Ordering is stable: time ascending, then `kind` in the fixed order lesson, assignment, todo, then title, then id.  A failing campus source does not remove the other sources' items; its state is reported structurally in `sources[]`. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   Inclusive start day in Asia/Shanghai.
  ///
  /// * [DateTime] to (required):
  ///   Exclusive end day in Asia/Shanghai.
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<Response> getCalendarWithHttpInfo(DateTime from, DateTime to, { String? xRequestId, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/calendar';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'from', _dateFormatter.format(from)));
      queryParams.addAll(_queryParams('', 'to', _dateFormatter.format(to)));

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

  /// Read study calendar entries in a date range
  ///
  /// `from` is inclusive and `to` is exclusive, both interpreted as calendar days in `Asia/Shanghai`. The first release accepts at most 93 days.  Boundaries use interval overlap rather than point containment:  - lesson: `starts_at < to AND ends_at > from` - assignment and todo: `due_at >= from AND due_at < to`, or the whole   calendar day for `date_only`  `items` is a discriminated union on `kind` (`lesson`, `assignment`, `todo`). Lessons come from the timetable source, assignments from the assignment source and todos from this service. An assignment is never duplicated into a todo.  Ordering is stable: time ascending, then `kind` in the fixed order lesson, assignment, todo, then title, then id.  A failing campus source does not remove the other sources' items; its state is reported structurally in `sources[]`. 
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   Inclusive start day in Asia/Shanghai.
  ///
  /// * [DateTime] to (required):
  ///   Exclusive end day in Asia/Shanghai.
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<CalendarResponse?> getCalendar(DateTime from, DateTime to, { String? xRequestId, Future<void>? abortTrigger, }) async {
    final response = await getCalendarWithHttpInfo(from, to, xRequestId: xRequestId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'CalendarResponse',) as CalendarResponse;
    
    }
    return null;
  }
}
