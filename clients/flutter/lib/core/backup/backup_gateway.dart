import 'dart:convert';

import 'package:jlu_dela_api/api.dart';

import '../api/api_failure.dart';

class BackupConflict implements Exception {
  const BackupConflict(this.current);

  final BackupSnapshot current;
}

abstract interface class BackupRemote {
  Future<BackupSnapshot> read();
  Future<BackupReceipt> put(String key, PutNotesBackupRequest request);
  Future<BackupReceipt> delete(String key, int revision);
}

class BackupGateway implements BackupRemote {
  BackupGateway(ApiClient client) : _api = PersonalBackupApi(client);

  final PersonalBackupApi _api;

  @override
  Future<BackupSnapshot> read() => _request(() async {
    final response = await _api.getNotesBackup();
    if (response == null) throw const FormatException('备份响应为空');
    return response.data;
  });

  @override
  Future<BackupReceipt> put(String key, PutNotesBackupRequest request) =>
      _request(() async {
        final response = await _api.putNotesBackup(key, request);
        if (response == null) throw const FormatException('备份响应为空');
        return response.data;
      });

  @override
  Future<BackupReceipt> delete(String key, int revision) => _request(() async {
    final response = await _api.deleteNotesBackup(
      key,
      DeleteNotesBackupRequest(expectedRevision: revision),
    );
    if (response == null) throw const FormatException('备份响应为空');
    return response.data;
  });

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (error) {
      if (error.code == 409) {
        final response = BackupConflictResponse.fromJson(
          jsonDecode(error.message ?? '{}'),
        );
        final current = response?.error.current.orElse(null);
        if (current != null) throw BackupConflict(current);
      }
      throw mapApiException(error);
    }
  }
}
