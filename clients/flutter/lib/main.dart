import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'app/app.dart';
import 'app/device_campus_login.dart';
import 'app/local_migrations.dart';
import 'app/local_workbench.dart';
import 'core/academic/academic_calendar_cache.dart';
import 'core/academic/academic_calendar_service.dart';
import 'core/api/diagnostics_service.dart';
import 'core/auth/account_gateway.dart';
import 'core/auth/auth_gateway.dart';
import 'core/auth/workbench_api.dart';
import 'core/config/app_config.dart';
import 'core/backup/backup_gateway.dart';
import 'core/source/cookie_source_http_client.dart';
import 'core/source/source_page_opener_impl.dart';
import 'core/source/source_session.dart';
import 'core/storage/local_database.dart';
import 'core/storage/local_identity_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'HarmonyOS Sans SC',
    ], await rootBundle.loadString('assets/fonts/LICENSE_Fonts.txt'));
  });

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
    final academicCalendar = AcademicCalendarService(
      apiBaseUri: apiBaseUri,
      httpClient: http.Client(),
      cache: await FileAcademicCalendarCache.applicationSupport(),
    );
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
    final sourceHttp = CookieSourceHttpClient(sessions: sessions);
    final campusLogin = DeviceCampusLogin(sessions: sessions, http: sourceHttp);
    final browser = InAppWebViewSourcePageOpener(sessions: sessions);
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
          http: sourceHttp,
          campusLogin: campusLogin,
          browser: browser,
          academicCalendar: academicCalendar,
          session: workbenchApi.session,
          backupRemote: BackupGateway(workbenchApi.apiClient),
        ),
      ),
    );
    unawaited(academicCalendar.load());
    unawaited(workbenchApi.session.restore());
  } on FormatException catch (error) {
    runApp(BootstrapErrorApp(message: error.message));
  }
}
