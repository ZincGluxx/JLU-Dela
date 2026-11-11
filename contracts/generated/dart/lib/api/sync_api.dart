//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class SyncApi {
  SyncApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Queue a source synchronization
  ///
  /// Persists a sync job and returns 202 before any source work starts. Repeating the same user, source, resource and canonical scope while a job is queued or running returns that job with `reused: true`; it does not replay work or create a second job. A queued or running job is executed by one worker. An interrupted process is recovered after its lease expires; after three attempts the job fails with `SYNC_INTERRUPTED`. No source adapter is registered in this build, so every source currently returns 422 UNSUPPORTED_SOURCE. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [CreateSyncJobRequest] createSyncJobRequest (required):
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<Response> createSyncJobWithHttpInfo(CreateSyncJobRequest createSyncJobRequest, { String? xRequestId, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/sync-jobs';

    // ignore: prefer_final_locals
    Object? postBody = createSyncJobRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (xRequestId != null) {
      headerParams[r'X-Request-Id'] = parameterToString(xRequestId);
    }

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

  /// Queue a source synchronization
  ///
  /// Persists a sync job and returns 202 before any source work starts. Repeating the same user, source, resource and canonical scope while a job is queued or running returns that job with `reused: true`; it does not replay work or create a second job. A queued or running job is executed by one worker. An interrupted process is recovered after its lease expires; after three attempts the job fails with `SYNC_INTERRUPTED`. No source adapter is registered in this build, so every source currently returns 422 UNSUPPORTED_SOURCE. 
  ///
  /// Parameters:
  ///
  /// * [CreateSyncJobRequest] createSyncJobRequest (required):
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<SyncJobAcceptedResponse?> createSyncJob(CreateSyncJobRequest createSyncJobRequest, { String? xRequestId, Future<void>? abortTrigger, }) async {
    final response = await createSyncJobWithHttpInfo(createSyncJobRequest, xRequestId: xRequestId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SyncJobAcceptedResponse',) as SyncJobAcceptedResponse;
    
    }
    return null;
  }

  /// Read a sync job owned by the current user
  ///
  /// Returns the persisted job. Jobs of other users, unknown ids and invalid ids all return 404 SYNC_JOB_NOT_FOUND. The response never contains source payloads, credentials or upstream error text. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///   Opaque sync job id.
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<Response> getSyncJobWithHttpInfo(String id, { String? xRequestId, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/sync-jobs/{id}'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

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

  /// Read a sync job owned by the current user
  ///
  /// Returns the persisted job. Jobs of other users, unknown ids and invalid ids all return 404 SYNC_JOB_NOT_FOUND. The response never contains source payloads, credentials or upstream error text. 
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///   Opaque sync job id.
  ///
  /// * [String] xRequestId:
  ///   Optional client request identifier. The server echoes it in the response header and body.
  Future<SyncJobResponse?> getSyncJob(String id, { String? xRequestId, Future<void>? abortTrigger, }) async {
    final response = await getSyncJobWithHttpInfo(id, xRequestId: xRequestId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SyncJobResponse',) as SyncJobResponse;
    
    }
    return null;
  }
}
