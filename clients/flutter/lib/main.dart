import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app/app.dart';
import 'core/api/diagnostics_service.dart';
import 'core/auth/workbench_api.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final apiBaseUri = AppConfig.resolveApiBaseUri();
    final service = DiagnosticsService(
      apiBaseUri: apiBaseUri,
      httpClient: http.Client(),
    );
    final workbenchApi = WorkbenchApi(baseUri: apiBaseUri);
    runApp(
      JluDelaApp(diagnosticsService: service, session: workbenchApi.session),
    );
    unawaited(workbenchApi.session.restore());
  } on FormatException catch (error) {
    runApp(BootstrapErrorApp(message: error.message));
  }
}
