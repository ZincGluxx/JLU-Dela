import 'package:flutter/material.dart';

import '../core/api/diagnostics_service.dart';
import '../core/auth/account_gateway.dart';
import '../core/auth/session_controller.dart';
import '../core/auth/session_models.dart';
import '../features/auth/login_page.dart';
import '../features/settings/settings_page.dart';
import 'app_shell.dart';
import 'session_gate.dart';
import 'theme.dart';

class JluDelaApp extends StatelessWidget {
  const JluDelaApp({
    super.key,
    required this.diagnosticsService,
    required this.session,
    required this.accountGateway,
    this.pages = const <AppDestination, AppPageBuilder>{},
  });

  final DiagnosticsService diagnosticsService;
  final SessionController session;
  final AccountGateway accountGateway;
  final Map<AppDestination, AppPageBuilder> pages;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JLU Dela',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _WorkbenchPage(
        diagnosticsService: diagnosticsService,
        session: session,
        accountGateway: accountGateway,
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
    required this.pages,
  });

  final DiagnosticsService diagnosticsService;
  final SessionController session;
  final AccountGateway accountGateway;
  final Map<AppDestination, AppPageBuilder> pages;

  @override
  State<_WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<_WorkbenchPage> {
  AppDestination _destination = AppDestination.calendar;
  bool _glassEnabled = true;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, child) {
        final phase = widget.session.phase;
        final keepContent =
            phase == SessionPhase.authenticated ||
            (phase == SessionPhase.unavailable &&
                widget.session.currentUser != null);
        return AppShell(
          destination: _destination,
          glassEnabled: _glassEnabled,
          pages: {
            AppDestination.settings: (context) => SettingsPage(
              diagnosticsService: widget.diagnosticsService,
              session: widget.session,
              glassEnabled: _glassEnabled,
              onGlassEnabledChanged: (value) {
                setState(() => _glassEnabled = value);
              },
            ),
            if (keepContent) ...widget.pages,
            if (!keepContent)
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
          },
          onDestinationSelected: (destination) {
            setState(() => _destination = destination);
          },
        );
      },
    );
  }
}

class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({super.key, required this.message});

  final String message;

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
                  Text(
                    'API 地址配置无效',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(message),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '通过 --dart-define=API_BASE_URL=http://host:port 设置服务地址。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
