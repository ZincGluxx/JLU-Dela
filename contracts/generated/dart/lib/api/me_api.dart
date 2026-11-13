//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class MeApi {
  MeApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Return the authenticated workbench user
  ///
  /// The user id always comes from the session on the server. Clients must not send or choose a user id. The response contains no campus source session or credential. 
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getMeWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/me';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

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

  /// Return the authenticated workbench user
  ///
  /// The user id always comes from the session on the server. Clients must not send or choose a user id. The response contains no campus source session or credential. 
  Future<MeResponse?> getMe({ Future<void>? abortTrigger, }) async {
    final response = await getMeWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'MeResponse',) as MeResponse;
    
    }
    return null;
  }

  /// Update the current account
  ///
  /// Omitted fields keep their values. New usernames are not trimmed or lowercased. New passwords require 8-16 Unicode scalar values including ASCII lowercase, uppercase and a digit. Existing password login rules are unchanged. A duplicate username returns 409 USERNAME_TAKEN. Phone and student identity fields are not accepted.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [UpdateAccountRequest] updateAccountRequest (required):
  Future<Response> updateAccountWithHttpInfo(UpdateAccountRequest updateAccountRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/me/account';

    // ignore: prefer_final_locals
    Object? postBody = updateAccountRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PATCH',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Update the current account
  ///
  /// Omitted fields keep their values. New usernames are not trimmed or lowercased. New passwords require 8-16 Unicode scalar values including ASCII lowercase, uppercase and a digit. Existing password login rules are unchanged. A duplicate username returns 409 USERNAME_TAKEN. Phone and student identity fields are not accepted.
  ///
  /// Parameters:
  ///
  /// * [UpdateAccountRequest] updateAccountRequest (required):
  Future<MeResponse?> updateAccount(UpdateAccountRequest updateAccountRequest, { Future<void>? abortTrigger, }) async {
    final response = await updateAccountWithHttpInfo(updateAccountRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'MeResponse',) as MeResponse;
    
    }
    return null;
  }

  /// Verify a student report on the server
  ///
  /// Accepts a report code, never a client-supplied student or college claim. The server confirms Jilin University and college from the official student report. The result records a past report check, not current enrollment or proof that the caller is the report holder. No enrollment status restriction, automatic expiry or repeated verification is imposed. Phone numbers determine account uniqueness; the same report may verify multiple phone accounts. Student identifiers, names and birth dates are not processed. Report codes and raw personal reports are not stored. Current official HTML has been observed in the browser; Rust end-to-end verification is still pending. Invalid reports and non-Jilin University reports return 422 STUDENT_REPORT_INVALID and STUDENT_NOT_ELIGIBLE. Restricted, unrecognized or unavailable upstream responses return 503 STUDENT_REPORT_RESTRICTED, STUDENT_REPORT_PARSE_FAILED or STUDENT_VERIFICATION_UNAVAILABLE.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [VerifyStudentReportRequest] verifyStudentReportRequest (required):
  Future<Response> verifyStudentReportWithHttpInfo(VerifyStudentReportRequest verifyStudentReportRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/me/student-verification';

    // ignore: prefer_final_locals
    Object? postBody = verifyStudentReportRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Verify a student report on the server
  ///
  /// Accepts a report code, never a client-supplied student or college claim. The server confirms Jilin University and college from the official student report. The result records a past report check, not current enrollment or proof that the caller is the report holder. No enrollment status restriction, automatic expiry or repeated verification is imposed. Phone numbers determine account uniqueness; the same report may verify multiple phone accounts. Student identifiers, names and birth dates are not processed. Report codes and raw personal reports are not stored. Current official HTML has been observed in the browser; Rust end-to-end verification is still pending. Invalid reports and non-Jilin University reports return 422 STUDENT_REPORT_INVALID and STUDENT_NOT_ELIGIBLE. Restricted, unrecognized or unavailable upstream responses return 503 STUDENT_REPORT_RESTRICTED, STUDENT_REPORT_PARSE_FAILED or STUDENT_VERIFICATION_UNAVAILABLE.
  ///
  /// Parameters:
  ///
  /// * [VerifyStudentReportRequest] verifyStudentReportRequest (required):
  Future<MeResponse?> verifyStudentReport(VerifyStudentReportRequest verifyStudentReportRequest, { Future<void>? abortTrigger, }) async {
    final response = await verifyStudentReportWithHttpInfo(verifyStudentReportRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'MeResponse',) as MeResponse;
    
    }
    return null;
  }
}
