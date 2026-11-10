import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/config/app_config.dart';

void main() {
  test('accepts an absolute http origin and removes trailing slashes', () {
    final uri = AppConfig.resolveApiBaseUri('http://127.0.0.1:8080///');

    expect(uri.toString(), 'http://127.0.0.1:8080');
  });

  test('accepts https origins', () {
    final uri = AppConfig.resolveApiBaseUri('https://api.example.edu.cn');

    expect(uri.scheme, 'https');
    expect(uri.host, 'api.example.edu.cn');
  });

  test('rejects values without an http(s) origin', () {
    for (final value in <String>[
      '127.0.0.1:8080',
      'ftp://127.0.0.1:8080',
      'http://127.0.0.1:8080/api',
      'http://127.0.0.1:8080?token=secret',
    ]) {
      expect(
        () => AppConfig.resolveApiBaseUri(value),
        throwsFormatException,
        reason: value,
      );
    }
  });
}
