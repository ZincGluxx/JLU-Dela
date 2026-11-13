import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/core/api/api_failure.dart';
import 'package:jlu_dela/core/auth/workbench_api.dart';

import 'support/session_test_support.dart';

const _fileId = '0589272a-4b20-4406-898f-fef877cbe9ee';

Map<String, Object> _metadata() => {
  'data': {
    'id': _fileId,
    'uploader_id': '2d7e17b7-9509-4130-b32c-15ea3de9a631',
    'original_name': '课程😀.pdf',
    'size_bytes': 4,
    'media_type': 'application/pdf',
    'created_at': '2026-11-13T12:00:00Z',
  },
  'meta': {'request_id': 'file-request'},
};

String _error(String code) => jsonEncode({
  'error': {
    'code': code,
    'message': 'File operation failed.',
    'request_id': 'file-error-request',
    'retryable': code == 'FILE_STORAGE_UNAVAILABLE',
    'fields': <Object>[],
  },
});

void main() {
  Future<WorkbenchApi> signedIn(http.Client client) async {
    final api = WorkbenchApi(
      baseUri: Uri.parse('https://workbench.example'),
      authGateway: FakeAuthGateway(onFetchMe: (_) async => testUser()),
      refreshTokenStore: MemoryRefreshTokenStore(),
      httpClient: client,
    );
    addTearDown(api.close);
    await api.session.signIn(testCredentials());
    return api;
  }

  test(
    'upload sends exactly one binary file field and original filename',
    () async {
      final api = await signedIn(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/files');
          expect(request.headers['authorization'], 'Bearer access-a');
          expect(request.headers.containsKey('cookie'), isFalse);
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          final wire = utf8.decode(request.bodyBytes, allowMalformed: true);
          expect(
            RegExp(
              'content-disposition:',
              caseSensitive: false,
            ).allMatches(wire),
            hasLength(1),
          );
          expect(wire, contains('name="file"; filename="课程😀.pdf"'));
          expect(wire, contains('application/octet-stream'));
          expect(request.bodyBytes, containsAllInOrder([0, 255, 128, 1]));
          return http.Response(
            jsonEncode(_metadata()),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final stored = await api.files.upload(
        http.MultipartFile.fromBytes('file', [
          0,
          255,
          128,
          1,
        ], filename: '课程😀.pdf'),
      );
      expect(stored.id, _fileId);
      expect(stored.originalName, '课程😀.pdf');
      expect(stored.sizeBytes, 4);
      expect(stored.createdAt.isUtc, isTrue);
    },
  );

  test('metadata and delete share the authenticated ApiClient', () async {
    final methods = <String>[];
    final api = await signedIn(
      MockClient((request) async {
        methods.add(request.method);
        expect(request.url.path, '/api/v1/files/$_fileId');
        expect(request.url.hasQuery, isFalse);
        expect(request.headers['authorization'], 'Bearer access-a');
        return request.method == 'DELETE'
            ? http.Response('', 204)
            : http.Response(
                jsonEncode(_metadata()),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
      }),
    );
    expect(
      (await api.files.metadata(_fileId)).uploaderId,
      '2d7e17b7-9509-4130-b32c-15ea3de9a631',
    );
    await api.files.delete(_fileId);
    expect(methods, ['GET', 'DELETE']);
  });

  test(
    'download preserves arbitrary binary bytes without JSON or UTF8 decoding',
    () async {
      final bytes = [0, 255, 254, 128, 13, 10, 0];
      final api = await signedIn(
        MockClient((request) async {
          expect(request.url.path, '/api/v1/files/$_fileId/content');
          expect(request.headers['authorization'], 'Bearer access-a');
          return http.Response.bytes(
            bytes,
            200,
            headers: {
              'content-type': 'application/octet-stream',
              'content-disposition': 'attachment; filename="download.bin"',
              'x-content-type-options': 'nosniff',
              'cache-control': 'private, no-store',
            },
          );
        }),
      );
      expect(await api.files.download(_fileId), bytes);
    },
  );

  for (final (status, code) in [
    (404, 'FILE_NOT_FOUND'),
    (409, 'FILE_IN_USE'),
    (413, 'PAYLOAD_TOO_LARGE'),
    (422, 'VALIDATION_FAILED'),
    (503, 'FILE_STORAGE_UNAVAILABLE'),
  ]) {
    test('maps $code from metadata/upload/download/delete errors', () async {
      final api = await signedIn(
        MockClient((_) async => http.Response(_error(code), status)),
      );
      final operations = <Future<Object?> Function()>[
        () => api.files.metadata(_fileId),
        () => api.files.upload(
          http.MultipartFile.fromBytes('file', [1], filename: 'test.bin'),
        ),
        () => api.files.download(_fileId),
        () async {
          await api.files.delete(_fileId);
          return null;
        },
      ];
      for (final operation in operations) {
        await expectLater(
          operation(),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.kind, 'kind', ApiFailureKind.server)
                .having((e) => e.code, 'code', code)
                .having((e) => e.statusCode, 'status', status)
                .having((e) => e.requestId, 'requestId', 'file-error-request')
                .having((e) => e.retryable, 'retryable', status == 503),
          ),
        );
      }
    });
  }

  test(
    'caller revision scope discards a download completed after account switch',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final tokens = <String?>[];
      final api = await signedIn(
        MockClient((request) async {
          tokens.add(request.headers['authorization']);
          if (tokens.length == 1) {
            started.complete();
            return pending.future;
          }
          return http.Response.bytes([2], 200);
        }),
      );
      List<int>? visibleBytes;
      Future<void> load() async {
        final revision = api.session.sessionRevision;
        final bytes = await api.files.download(_fileId);
        if (revision != api.session.sessionRevision) return;
        visibleBytes = bytes;
      }

      final oldLoad = load();
      await started.future;
      await api.session.signIn(
        testCredentials(accessToken: 'access-b', refreshToken: 'refresh-b'),
      );
      await load();
      pending.complete(http.Response.bytes([1], 200));
      await oldLoad;
      expect(visibleBytes, [2]);
      expect(tokens, ['Bearer access-a', 'Bearer access-b']);
    },
  );

  test('expired multipart upload refreshes but never replays POST', () async {
    var requests = 0;
    final auth = FakeAuthGateway(
      onFetchMe: (_) async => testUser(),
      onRefresh: (_) async => testTokenPair(accessToken: 'access-b'),
    );
    final api = WorkbenchApi(
      baseUri: Uri.parse('https://workbench.example'),
      authGateway: auth,
      refreshTokenStore: MemoryRefreshTokenStore(),
      httpClient: MockClient((_) async {
        requests++;
        return http.Response(_error('TOKEN_EXPIRED'), 401);
      }),
    );
    addTearDown(api.close);
    await api.session.signIn(testCredentials());
    await expectLater(
      api.files.upload(
        http.MultipartFile.fromBytes('file', [1], filename: 'once.bin'),
      ),
      throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'TOKEN_EXPIRED')),
    );
    expect(requests, 1);
    expect(auth.refreshCount, 1);
    expect(api.session.accessToken, 'access-b');
  });
}
