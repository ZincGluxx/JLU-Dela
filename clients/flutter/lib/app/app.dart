import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jlu_dela_api/api.dart';

import '../core/api/diagnostics_service.dart';
import '../core/auth/account_gateway.dart';
import '../core/auth/session_controller.dart';
import '../core/auth/session_models.dart';
import '../core/auth/session_scope.dart';
import '../core/storage/local_identity_store.dart';
import '../features/assignments/assignments_page.dart';
import '../features/auth/login_page.dart';
import '../features/content/materials_page.dart';
import '../features/content/notices_page.dart';
import '../features/planner/calendar_page.dart';
import '../features/planner/todo_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/source_connection_card.dart';
import '../features/teaching/teaching_page.dart';
import 'app_shell.dart';
import 'local_workbench.dart';
import 'session_gate.dart';
import 'theme.dart';

class JluDelaApp extends StatelessWidget {
  const JluDelaApp({
    super.key,
    required this.diagnosticsService,
    required this.session,
    required this.accountGateway,
    required this.identityStore,
    required this.workbenchBuilder,
    this.cachedIdentity,
    this.pages = const <AppDestination, AppPageBuilder>{},
  });

  final DiagnosticsService diagnosticsService;
  final SessionController session;
  final AccountGateway accountGateway;
  final LocalIdentityStore identityStore;
  final WorkbenchData Function(String userId) workbenchBuilder;
  final CachedIdentity? cachedIdentity;
  final Map<AppDestination, AppPageBuilder> pages;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JLU Dela',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) =>
          SessionScope(session: session, child: child!),
      home: _WorkbenchPage(
        diagnosticsService: diagnosticsService,
        session: session,
        accountGateway: accountGateway,
        identityStore: identityStore,
        workbenchBuilder: workbenchBuilder,
        cachedIdentity: cachedIdentity,
        pages: pages,
      ),
    );
  }
}

class _WorkbenchPage extends StatefulWidget {
  const _WorkbenchPage({
    required this.diagnosticsService,
    required this.session,
    required this.accountGateway,
    required this.identityStore,
    required this.workbenchBuilder,
    required this.cachedIdentity,
    required this.pages,
  });

  final DiagnosticsService diagnosticsService;
  final SessionController session;
  final AccountGateway accountGateway;
  final LocalIdentityStore identityStore;
  final WorkbenchData Function(String userId) workbenchBuilder;
  final CachedIdentity? cachedIdentity;
  final Map<AppDestination, AppPageBuilder> pages;

  @override
  State<_WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<_WorkbenchPage> {
  AppDestination _destination = AppDestination.calendar;
  bool _glassEnabled = true;
  CachedIdentity? _cachedIdentity;
  String? _activeUserId;
  String? _recordedUserId;
  WorkbenchData? _workbench;

  @override
  void initState() {
    super.initState();
    _cachedIdentity = widget.cachedIdentity;
    widget.session.addListener(_handleSessionChanged);
    _syncWorkbench();
  }

  @override
  void dispose() {
    widget.session.removeListener(_handleSessionChanged);
    _clearWorkbench();
    super.dispose();
  }

  void _handleSessionChanged() {
    _syncWorkbench();
    if (mounted) {
      setState(() {});
    }
  }

  void _syncWorkbench() {
    final phase = widget.session.phase;
    final user = widget.session.currentUser;
    if (phase == SessionPhase.authenticated && user != null) {
      _recordConfirmedAccount(user);
    } else {
      _recordedUserId = null;
    }

    final userId = switch (phase) {
      SessionPhase.authenticated || SessionPhase.restoring => user?.id,
      SessionPhase.unavailable => user?.id ?? _cachedIdentity?.userId,
      SessionPhase.signedOut => null,
    };

    if (userId == _activeUserId) {
      return;
    }
    _clearWorkbench();
    _activeUserId = userId;
    if (userId != null) {
      _workbench = widget.workbenchBuilder(userId);
    }
  }

  void _recordConfirmedAccount(Me user) {
    if (_recordedUserId == user.id) {
      return;
    }
    _recordedUserId = user.id;
    final verifiedAt = DateTime.now().toUtc();
    _cachedIdentity = CachedIdentity(
      userId: user.id,
      displayName: user.displayName,
      timezone: user.timezone,
      verifiedAtUtc: verifiedAt,
      lastUsedAtUtc: verifiedAt,
    );
    unawaited(
      widget.identityStore.recordVerified(
        userId: user.id,
        displayName: user.displayName,
        timezone: user.timezone,
        verifiedAt: verifiedAt,
      ),
    );
  }

  void _clearWorkbench() {
    final workbench = _workbench;
    if (workbench == null) {
      return;
    }
    workbench.workspace.sessions.clearAll();
    workbench.dispose();
    _workbench = null;
  }

  Map<AppDestination, AppPageBuilder> _workbenchPages(WorkbenchData data) {
    final workspace = data.workspace;
    return {
      AppDestination.todos: (context) => TodoPage(workspace: workspace),
      AppDestination.calendar: (context) => CalendarPage(workspace: workspace),
      AppDestination.teaching: (context) =>
          TeachingPage(workspace: workspace, store: data.teachingStore),
      AppDestination.assignments: (context) =>
          AssignmentsPage(workspace: workspace, store: data.chaoxingStore),
      AppDestination.materials: (context) =>
          MaterialsPage(workspace: workspace, store: data.contentStore),
      AppDestination.notices: (context) =>
          NoticesPage(workspace: workspace, store: data.contentStore),
    };
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.session.phase;
    final workbench = _workbench;
    final contentVisible = workbench != null && phase != SessionPhase.restoring;
    final offline = phase == SessionPhase.unavailable && workbench != null;
    final pages = <AppDestination, AppPageBuilder>{
      AppDestination.settings: (context) => SettingsPage(
        diagnosticsService: widget.diagnosticsService,
        session: widget.session,
        glassEnabled: _glassEnabled,
        onGlassEnabledChanged: (value) {
          setState(() => _glassEnabled = value);
        },
        sourceConnections: workbench == null
            ? null
            : SourceConnectionController(
                source: workbench.workspace.source,
                enabled: phase != SessionPhase.signedOut,
              ),
      ),
      if (contentVisible) ..._workbenchPages(workbench),
      if (contentVisible) ...widget.pages,
      if (!contentVisible)
        for (final destination in AppDestination.values)
          if (destination != AppDestination.settings)
            destination: (context) => phase == SessionPhase.signedOut
                ? LoginPage(
                    session: widget.session,
                    accountGateway: widget.accountGateway,
                  )
                : SessionGate(
                    phase: phase,
                    onRetry: widget.session.retryRestore,
                  ),
    };

    return AppShell(
      destination: _destination,
      glassEnabled: _glassEnabled,
      pageScopeKey: _activeUserId ?? 'anonymous',
      offlineBanner: offline
          ? _OfflineBanner(onRetry: widget.session.retryRestore)
          : null,
      pages: pages,
      onDestinationSelected: (destination) {
        setState(() => _destination = destination);
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('offline-banner'),
      color: const Color(0xFFFFF4E5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
        side: const BorderSide(color: Color(0xFFF0C48A)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 20,
              color: Color(0xFF8A5A00),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                '离线 · 应用会话未确认',
                key: Key('offline-banner-label'),
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              key: const Key('offline-reverify'),
              onPressed: () => unawaited(onRetry()),
              child: const Text('重新连接'),
            ),
          ],
        ),
      ),
    );
  }
}

class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({
    super.key,
    required this.message,
    this.title = 'API 地址配置无效',
    this.hint = '通过 --dart-define=API_BASE_URL=http://host:port 设置服务地址。',
  });

  final String message;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JLU Dela',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.settings_ethernet, size: 40),
                  const SizedBox(height: AppSpacing.md),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(message),
                  const SizedBox(height: AppSpacing.md),
                  Text(hint, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
