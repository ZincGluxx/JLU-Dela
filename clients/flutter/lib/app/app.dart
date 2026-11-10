import 'package:flutter/material.dart';

import '../core/api/diagnostics_service.dart';
import '../features/diagnostics/diagnostics_page.dart';
import 'theme.dart';

class JluDelaApp extends StatelessWidget {
  const JluDelaApp({super.key, required this.diagnosticsService});

  final DiagnosticsService diagnosticsService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JLU Dela',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: DiagnosticsPage(service: diagnosticsService),
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
