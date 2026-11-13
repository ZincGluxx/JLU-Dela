//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class FilesApi {
  FilesApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Delete an unattached file as its uploader
  ///
  /// Only the uploader may delete an unattached file. An attached file returns 409 FILE_IN_USE to its uploader. Other callers and missing files always return 404 FILE_NOT_FOUND, including when a file is attached. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///   Stored file identifier.
  Future<Response> deleteFileWithHttpInfo(String id, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/files/{id}'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


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

  /// Delete an unattached file as its uploader
  ///
  /// Only the uploader may delete an unattached file. An attached file returns 409 FILE_IN_USE to its uploader. Other callers and missing files always return 404 FILE_NOT_FOUND, including when a file is attached. 
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///   Stored file identifier.
  Future<void> deleteFile(String id, { Future<void>? abortTrigger, }) async {
    final response = await deleteFileWithHttpInfo(id, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Download unattached file bytes as its uploader
  ///
  /// Missing, non-owned and attached files return 404 FILE_NOT_FOUND, including attached files owned by the caller. After attachment, use an authorized business route; no query parameter makes a file public. Stored media_type is descriptive only; the response always uses safe octet-stream attachment delivery, never an inline rendering of the uploaded media type. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///   Stored file identifier.
  Future<Response> downloadFileWithHttpInfo(String id, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/files/{id}/content'
      .replaceAll('{id}', id);

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

  /// Download unattached file bytes as its uploader
  ///
  /// Missing, non-owned and attached files return 404 FILE_NOT_FOUND, including attached files owned by the caller. After attachment, use an authorized business route; no query parameter makes a file public. Stored media_type is descriptive only; the response always uses safe octet-stream attachment delivery, never an inline rendering of the uploaded media type. 
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///   Stored file identifier.
  Future<MultipartFile?> downloadFile(String id, { Future<void>? abortTrigger, }) async {
    final response = await downloadFileWithHttpInfo(id, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'MultipartFile',) as MultipartFile;
    
    }
    return null;
  }

  /// Read unattached file metadata as its uploader
  ///
  /// Missing files and files invisible to the caller return 404 FILE_NOT_FOUND. Once attached, direct reads return 404 even for the uploader. Business consumers must use their authorized business route instead; query parameters cannot broaden visibility. Business routes are not part of this contract. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///   Stored file identifier.
  Future<Response> getFileWithHttpInfo(String id, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/files/{id}'
      .replaceAll('{id}', id);

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

  /// Read unattached file metadata as its uploader
  ///
  /// Missing files and files invisible to the caller return 404 FILE_NOT_FOUND. Once attached, direct reads return 404 even for the uploader. Business consumers must use their authorized business route instead; query parameters cannot broaden visibility. Business routes are not part of this contract. 
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///   Stored file identifier.
  Future<StoredFileResponse?> getFile(String id, { Future<void>? abortTrigger, }) async {
    final response = await getFileWithHttpInfo(id, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'StoredFileResponse',) as StoredFileResponse;
    
    }
    return null;
  }

  /// Upload one private file
  ///
  /// Accepts exactly one multipart field named `file`, with a nonempty binary body and filename. Unknown or repeated fields return 422 VALIDATION_FAILED. Filenames contain at most 255 Unicode scalars and no control characters. The configured file limit defaults to 10 MiB and cannot exceed 64 MiB. Only this upload route allows an extra 64 KiB of multipart body overhead. The file remains private to its uploader until attached to a business object. Campus cookies and student reports must never be supplied to this API. 
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [MultipartFile] file (required):
  Future<Response> uploadFileWithHttpInfo(MultipartFile file, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/files';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['multipart/form-data'];

    bool hasFields = false;
    final mp = MultipartRequest('POST', Uri.parse(path));
    if (file != null) {
      hasFields = true;
      mp.files.add(file);
    }
    if (hasFields) {
      postBody = mp;
    }

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

  /// Upload one private file
  ///
  /// Accepts exactly one multipart field named `file`, with a nonempty binary body and filename. Unknown or repeated fields return 422 VALIDATION_FAILED. Filenames contain at most 255 Unicode scalars and no control characters. The configured file limit defaults to 10 MiB and cannot exceed 64 MiB. Only this upload route allows an extra 64 KiB of multipart body overhead. The file remains private to its uploader until attached to a business object. Campus cookies and student reports must never be supplied to this API. 
  ///
  /// Parameters:
  ///
  /// * [MultipartFile] file (required):
  Future<StoredFileResponse?> uploadFile(MultipartFile file, { Future<void>? abortTrigger, }) async {
    final response = await uploadFileWithHttpInfo(file, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'StoredFileResponse',) as StoredFileResponse;
    
    }
    return null;
  }
}
