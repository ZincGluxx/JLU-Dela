import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppBreakpoints {
  static const double desktop = 768;
  static const double cardGrid = 720;
}

abstract final class AppTheme {
  static const Color primary = Color(0xFF2680EB);
  static const Color background = Color(0xFFF8F8FA);
  static const Color border = Color(0xFFE7E9EE);
  static const Color foreground = Color(0xFF202127);
  static const Color muted = Color(0xFF747984);
  static const Color blueSoft = Color(0xFFEAF2FD);
  static const double surfaceRadius = 16;
  static const double glassRadius = 24;
  static const double blurSigma = 24;

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(primary: primary, surface: Colors.white);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'HarmonyOS Sans SC',
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, space: 1),
    );
  }

  static BoxDecoration surfaceDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(surfaceRadius),
      border: Border.all(color: border),
    );
  }
}
