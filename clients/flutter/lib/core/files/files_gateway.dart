import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:jlu_dela_api/api.dart';

import '../api/api_failure.dart';

class FilesGateway {
  FilesGateway(ApiClient apiClient) : _api = FilesApi(apiClient);

  final FilesApi _api;

  Future<StoredFile> upload(http.MultipartFile file) async {
    if (file.field != 'file' || file.filename == null) {
      throw ArgumentError.value(file, 'file', 'Expected a named file field.');
    }
    try {
      return _metadata(await _api.uploadFile(file));
    } on ApiException catch (error) {
      throw mapApiException(error);
    }
  }

  Future<StoredFile> metadata(String id) async {
    try {
      return _metadata(await _api.getFile(id));
    } on ApiException catch (error) {
      throw mapApiException(error);
    }
  }

  Future<Uint8List> download(String id) async {
    try {
      final response = await _api.downloadFileWithHttpInfo(id);
      if (response.statusCode >= 400) {
        throw apiFailureFromErrorBody(
          response.statusCode,
          utf8.decode(response.bodyBytes, allowMalformed: true),
        );
      }
      return response.bodyBytes;
    } on ApiException catch (error) {
      throw mapApiException(error);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _api.deleteFile(id);
    } on ApiException catch (error) {
      throw mapApiException(error);
    }
  }

  StoredFile _metadata(StoredFileResponse? response) {
    if (response == null) {
      throw const ApiFailure(
        kind: ApiFailureKind.protocol,
        technicalMessage: 'The file response is empty.',
      );
    }
    return response.data;
  }
}
