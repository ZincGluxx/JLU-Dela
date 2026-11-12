import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app/app.dart';
import 'core/api/diagnostics_service.dart';
import 'core/config/app_config.dart';
import 'features/planner/calendar_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final apiBaseUri = AppConfig.resolveApiBaseUri();
    final service = DiagnosticsService(
      apiBaseUri: apiBaseUri,
      httpClient: http.Client(),
    );
    final calendarService = CalendarService(
      apiBaseUri: apiBaseUri,
      httpClient: http.Client(),
    );
    runApp(
      JluDelaApp(diagnosticsService: service, calendarService: calendarService),
    );
  } on FormatException catch (error) {
    runApp(BootstrapErrorApp(message: error.message));
  }
}
