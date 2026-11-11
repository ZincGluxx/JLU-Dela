import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api/diagnostics_service.dart';
import '../diagnostics/diagnostics_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.diagnosticsService,
    required this.glassEnabled,
    required this.onGlassEnabledChanged,
  });

  final DiagnosticsService diagnosticsService;
  final bool glassEnabled;
  final ValueChanged<bool> onGlassEnabledChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: SwitchListTile(
              key: const Key('glass-toggle'),
              title: const Text('玻璃材质'),
              subtitle: const Text('关闭后使用实色表面，布局保持不变'),
              value: glassEnabled,
              onChanged: onGlassEnabledChanged,
            ),
          ),
        ),
        Expanded(child: DiagnosticsPage(service: diagnosticsService)),
      ],
    );
  }
}
