//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

library openapi.api;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

part 'api_client.dart';
part 'api_helper.dart';
part 'api_exception.dart';
part 'auth/authentication.dart';
part 'auth/api_key_auth.dart';
part 'auth/oauth.dart';
part 'auth/http_basic_auth.dart';
part 'auth/http_bearer_auth.dart';
part 'optional.dart';

part 'api/auth_api.dart';
part 'api/calendar_api.dart';
part 'api/health_api.dart';
part 'api/me_api.dart';
part 'api/meta_api.dart';
part 'api/sync_api.dart';
part 'api/teaching_api.dart';
part 'api/todos_api.dart';

part 'model/academic_calendar.dart';
part 'model/academic_calendar_event.dart';
part 'model/academic_calendar_response.dart';
part 'model/academic_calendar_source.dart';
part 'model/academic_calendar_term.dart';
part 'model/academic_period.dart';
part 'model/academic_periods_source.dart';
part 'model/activate_request.dart';
part 'model/assignment_item.dart';
part 'model/calendar_data.dart';
part 'model/calendar_item.dart';
part 'model/calendar_response.dart';
part 'model/college.dart';
part 'model/course_list_meta.dart';
part 'model/course_list_response.dart';
part 'model/course_offering.dart';
part 'model/create_sync_job_request.dart';
part 'model/create_todo_request.dart';
part 'model/error_detail.dart';
part 'model/error_field.dart';
part 'model/error_response.dart';
part 'model/lesson.dart';
part 'model/lesson_item.dart';
part 'model/list_meta.dart';
part 'model/live_response.dart';
part 'model/live_status.dart';
part 'model/login_request.dart';
part 'model/logout_request.dart';
part 'model/me.dart';
part 'model/me_response.dart';
part 'model/meta_response.dart';
part 'model/pagination_meta.dart';
part 'model/ready_response.dart';
part 'model/ready_status.dart';
part 'model/refresh_request.dart';
part 'model/request_id_meta.dart';
part 'model/revision_conflict_detail.dart';
part 'model/revision_conflict_response.dart';
part 'model/schedule_list_meta.dart';
part 'model/schedule_list_response.dart';
part 'model/semester.dart';
part 'model/semester_list_meta.dart';
part 'model/semester_list_response.dart';
part 'model/service_meta.dart';
part 'model/snapshot_meta.dart';
part 'model/source_ref.dart';
part 'model/source_snapshot.dart';
part 'model/source_status.dart';
part 'model/sync_job.dart';
part 'model/sync_job_accepted.dart';
part 'model/sync_job_accepted_response.dart';
part 'model/sync_job_error.dart';
part 'model/sync_job_response.dart';
part 'model/sync_job_status.dart';
part 'model/teaching_source.dart';
part 'model/todo.dart';
part 'model/todo_item.dart';
part 'model/todo_list_response.dart';
part 'model/todo_response.dart';
part 'model/token_pair.dart';
part 'model/token_pair_response.dart';
part 'model/update_todo_request.dart';


/// An [ApiClient] instance that uses the default values obtained from
/// the OpenAPI specification file.
var defaultApiClient = ApiClient();

const _delimiters = {'csv': ',', 'ssv': ' ', 'tsv': '\t', 'pipes': '|'};
const _dateEpochMarker = 'epoch';
const _deepEquality = DeepCollectionEquality();
final _dateFormatter = DateFormat('yyyy-MM-dd');
final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

bool _isEpochMarker(String? pattern) => pattern == _dateEpochMarker || pattern == '/$_dateEpochMarker/';
