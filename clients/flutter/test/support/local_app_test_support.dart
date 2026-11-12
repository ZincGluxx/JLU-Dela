import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/app.dart';
import 'package:jlu_dela/app/app_shell.dart';
import 'package:jlu_dela/app/local_migrations.dart';
import 'package:jlu_dela/app/local_workbench.dart';
import 'package:jlu_dela/core/api/diagnostics_service.dart';
import 'package:jlu_dela/core/auth/account_gateway.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/local_identity_store.dart';

class TrackingWorkbenchData extends WorkbenchData {
  TrackingWorkbenchData({
    required super.workspace,
    required super.teachingStore,
    required super.chaoxingStore,
    required super.contentStore,
  });

  int disposeCount = 0;

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }
}

class LocalAppHarness {
  LocalAppHarness._(this.database)
    : identityStore = LocalIdentityStore(database) {
    sessions = SourceSessionRegistry();
    http = UnavailableSourceHttpClient(sessions: sessions);
  }

  static Future<LocalAppHarness> create() async {
    final database = await LocalDatabase.openInMemory(
      migrations: appLocalMigrations,
    );
    addTearDown(database.close);
    return LocalAppHarness._(database);
  }

  final LocalDatabase database;
  final LocalIdentityStore identityStore;
  final CampusLogin campusLogin = const UnsupportedCampusLogin();
  final List<String> builtUserIds = [];
  final List<TrackingWorkbenchData> workbenches = [];
  late final SourceSessionRegistry sessions;
  late final SourceHttpClient http;

  WorkbenchData build(String userId) {
    builtUserIds.add(userId);
    final data = buildWorkbenchData(
      database: database,
      userId: userId,
      sessions: sessions,
      http: http,
      campusLogin: campusLogin,
    );
    final tracked = TrackingWorkbenchData(
      workspace: data.workspace,
      teachingStore: data.teachingStore,
      chaoxingStore: data.chaoxingStore,
      contentStore: data.contentStore,
    );
    workbenches.add(tracked);
    return tracked;
  }

  JluDelaApp buildApp({
    required DiagnosticsService diagnosticsService,
    required SessionController session,
    required AccountGateway accountGateway,
    CachedIdentity? cachedIdentity,
    Map<AppDestination, AppPageBuilder> pages = const {},
  }) {
    return JluDelaApp(
      diagnosticsService: diagnosticsService,
      session: session,
      accountGateway: accountGateway,
      identityStore: identityStore,
      workbenchBuilder: build,
      cachedIdentity: cachedIdentity,
      pages: pages,
    );
  }
}
