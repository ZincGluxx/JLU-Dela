import 'package:flutter/material.dart';

import '../core/api/diagnostics_service.dart';
import '../features/settings/settings_page.dart';
import 'app_shell.dart';
import 'theme.dart';

class JluDelaApp extends StatelessWidget {
  const JluDelaApp({
    super.key,
    required this.diagnosticsService,
    this.pages = const <AppDestination, AppPageBuilder>{},
  });

  final DiagnosticsService diagnosticsService;
  final Map<AppDestination, AppPageBuilder> pages;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JLU Dela',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _WorkbenchPage(
        diagnosticsService: diagnosticsService,
        pages: pages,
      ),
    );
  }
}

class _WorkbenchPage extends StatefulWidget {
  const _WorkbenchPage({required this.diagnosticsService, required this.pages});

  final DiagnosticsService diagnosticsService;
  final Map<AppDestination, AppPageBuilder> pages;

  @override
  State<_WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<_WorkbenchPage> {
  AppDestination _destination = AppDestination.calendar;
  bool _glassEnabled = true;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      destination: _destination,
      glassEnabled: _glassEnabled,
      pages: {
        AppDestination.settings: (context) => SettingsPage(
          diagnosticsService: widget.diagnosticsService,
          glassEnabled: _glassEnabled,
          onGlassEnabledChanged: (value) {
            setState(() => _glassEnabled = value);
          },
        ),
        ...widget.pages,
      },
      onDestinationSelected: (destination) {
        setState(() => _destination = destination);
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
