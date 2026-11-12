import 'package:flutter/material.dart';

import 'theme.dart';

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppTheme.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}
