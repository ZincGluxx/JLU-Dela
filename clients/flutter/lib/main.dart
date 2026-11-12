import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app/app.dart';
import 'app/device_campus_login.dart';
import 'app/local_migrations.dart';
import 'app/local_workbench.dart';
import 'core/api/diagnostics_service.dart';
import 'core/auth/account_gateway.dart';
import 'core/auth/auth_gateway.dart';
import 'core/auth/workbench_api.dart';
import 'core/config/app_config.dart';
import 'core/source/source_portal.dart';
import 'core/source/source_session.dart';
import 'core/storage/local_database.dart';
import 'core/storage/local_identity_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final LocalDatabase database;
  try {
    database = await LocalDatabase.open(migrations: appLocalMigrations);
  } on LocalSchemaTooNewException catch (error) {
    runApp(
      BootstrapErrorApp(
        title: '本地数据库版本过新',
        message:
            '当前应用支持本地数据版本 ${error.supportedVersion}，'
            '本地数据库版本为 ${error.databaseVersion}。',
        hint: '请升级应用后重试，不要删除本地数据文件。',
      ),
    );
    return;
  } on Exception catch (error) {
    runApp(
      BootstrapErrorApp(
        title: '本地数据库无法打开',
        message: '$error',
        hint: '请确认应用可以写入应用支持目录后重启应用。',
      ),
    );
    return;
  }

  try {
    final apiBaseUri = AppConfig.resolveApiBaseUri();
    final service = DiagnosticsService(
      apiBaseUri: apiBaseUri,
      httpClient: http.Client(),
    );
    final workbenchApi = WorkbenchApi(
      baseUri: apiBaseUri,
      authGateway: HttpAuthGateway(baseUri: apiBaseUri),
    );
    final accountGateway = HttpAccountGateway(baseUri: apiBaseUri);
    final identityStore = LocalIdentityStore(database);
    final cachedIdentity = await identityStore.lastUsed();
    final sessions = SourceSessionRegistry();
    final httpClient = UnavailableSourceHttpClient(sessions: sessions);
    final campusLogin = DeviceCampusLogin(sessions: sessions);
    const browser = UnsupportedSourcePageOpener();
    runApp(
      JluDelaApp(
        diagnosticsService: service,
        session: workbenchApi.session,
        accountGateway: accountGateway,
        identityStore: identityStore,
        cachedIdentity: cachedIdentity,
        workbenchBuilder: (userId) => buildWorkbenchData(
          database: database,
          userId: userId,
          sessions: sessions,
          http: httpClient,
          campusLogin: campusLogin,
          browser: browser,
        ),
      ),
    );
    unawaited(workbenchApi.session.restore());
  } on FormatException catch (error) {
    runApp(BootstrapErrorApp(message: error.message));
  }
}
