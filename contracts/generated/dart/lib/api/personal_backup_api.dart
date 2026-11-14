//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class PersonalBackupApi {
  PersonalBackupApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Delete this account's cloud note content, retaining a revision tombstone
  ///
  /// Does not delete local notes. Requires explicit confirmation and the current revision. Stale writes cannot silently recreate deleted content. Operational database backup retention is managed separately by the operator. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///   Stable UUID for the exact operation body, reused only for its retry.
  ///
  /// * [DeleteNotesBackupRequest] deleteNotesBackupRequest (required):
  Future<Response> deleteNotesBackupWithHttpInfo(String idempotencyKey, DeleteNotesBackupRequest deleteNotesBackupRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal-backup/notes';

    // ignore: prefer_final_locals
    Object? postBody = deleteNotesBackupRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'DELETE',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Delete this account's cloud note content, retaining a revision tombstone
  ///
  /// Does not delete local notes. Requires explicit confirmation and the current revision. Stale writes cannot silently recreate deleted content. Operational database backup retention is managed separately by the operator. 
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///   Stable UUID for the exact operation body, reused only for its retry.
  ///
  /// * [DeleteNotesBackupRequest] deleteNotesBackupRequest (required):
  Future<BackupReceiptResponse?> deleteNotesBackup(String idempotencyKey, DeleteNotesBackupRequest deleteNotesBackupRequest, { Future<void>? abortTrigger, }) async {
    final response = await deleteNotesBackupWithHttpInfo(idempotencyKey, deleteNotesBackupRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'BackupReceiptResponse',) as BackupReceiptResponse;
    
    }
    return null;
  }

  /// Read the current account's selected notes backup
  ///
  /// Reading and login do not authorize upload. No backup returns revision 0, deleted true, empty notes and null updated_at. A deletion retains only a revision tombstone. Responses are private and no-store. 
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getNotesBackupWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal-backup/notes';

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

  /// Read the current account's selected notes backup
  ///
  /// Reading and login do not authorize upload. No backup returns revision 0, deleted true, empty notes and null updated_at. A deletion retains only a revision tombstone. Responses are private and no-store. 
  Future<BackupSnapshotResponse?> getNotesBackup({ Future<void>? abortTrigger, }) async {
    final response = await getNotesBackupWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'BackupSnapshotResponse',) as BackupSnapshotResponse;
    
    }
    return null;
  }

  /// Replace an explicitly selected notes snapshot using compare-and-swap
  ///
  /// The client must obtain explicit upload consent and selected note IDs. Ownership comes only from the current account. At most 100 notes and 524288 UTF-8 bytes of serialized notes are accepted. Note local revisions, credentials, source sessions and report codes are not part of this schema. A stable Idempotency-Key binds this exact request to its receipt without retaining note text in the idempotency ledger. Retries return the original receipt, not a claim that the cloud has not subsequently changed. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///   Stable UUID for the exact operation body, reused only for its retry.
  ///
  /// * [PutNotesBackupRequest] putNotesBackupRequest (required):
  Future<Response> putNotesBackupWithHttpInfo(String idempotencyKey, PutNotesBackupRequest putNotesBackupRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal-backup/notes';

    // ignore: prefer_final_locals
    Object? postBody = putNotesBackupRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Replace an explicitly selected notes snapshot using compare-and-swap
  ///
  /// The client must obtain explicit upload consent and selected note IDs. Ownership comes only from the current account. At most 100 notes and 524288 UTF-8 bytes of serialized notes are accepted. Note local revisions, credentials, source sessions and report codes are not part of this schema. A stable Idempotency-Key binds this exact request to its receipt without retaining note text in the idempotency ledger. Retries return the original receipt, not a claim that the cloud has not subsequently changed. 
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///   Stable UUID for the exact operation body, reused only for its retry.
  ///
  /// * [PutNotesBackupRequest] putNotesBackupRequest (required):
  Future<BackupReceiptResponse?> putNotesBackup(String idempotencyKey, PutNotesBackupRequest putNotesBackupRequest, { Future<void>? abortTrigger, }) async {
    final response = await putNotesBackupWithHttpInfo(idempotencyKey, putNotesBackupRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'BackupReceiptResponse',) as BackupReceiptResponse;
    
    }
    return null;
  }
}
