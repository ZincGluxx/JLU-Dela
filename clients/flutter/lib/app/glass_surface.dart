import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.glassRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF374E73).withValues(alpha: 0.09),
            blurRadius: AppSpacing.xl,
            offset: const Offset(0, AppSpacing.sm),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          enabled: enabled,
          filter: ui.ImageFilter.blur(
            sigmaX: AppTheme.blurSigma,
            sigmaY: AppTheme.blurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: enabled ? null : Colors.white,
              gradient: enabled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.76),
                        Colors.white.withValues(alpha: 0.38),
                        Colors.white.withValues(alpha: 0.54),
                      ],
                    )
                  : null,
              border: Border.all(
                color: enabled
                    ? Colors.white.withValues(alpha: 0.92)
                    : AppTheme.border,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
