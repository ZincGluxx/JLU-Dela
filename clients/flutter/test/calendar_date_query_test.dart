import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela_api/api.dart';

void main() {
  for (final dates in [
    (
      label: 'local DateTime',
      from: DateTime(2026, 12, 31, 0, 30),
      to: DateTime(2027, 1, 2, 23, 45),
    ),
    (
      label: 'UTC DateTime',
      from: DateTime.utc(2026, 12, 31, 0, 30),
      to: DateTime.utc(2027, 1, 2, 23, 45),
    ),
  ]) {
    test('calendar sends date-only queries from ${dates.label}', () async {
      final client = ApiClient(basePath: 'https://workbench.example');
      var requestCount = 0;
      client.client = MockClient((request) async {
        requestCount++;
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/calendar');
        expect(request.url.queryParametersAll, {
          'from': ['2026-12-31'],
          'to': ['2027-01-02'],
        });
        return http.Response('{}', 200);
      });
      addTearDown(client.client.close);

      final response = await CalendarApi(
        client,
      ).getCalendarWithHttpInfo(dates.from, dates.to);

      expect(response.statusCode, 200);
      expect(requestCount, 1);
    });
  }
}
