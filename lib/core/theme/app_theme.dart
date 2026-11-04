import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF14224A);
  static const accent = Color(0xFF3D6BF5);
  static const whatsApp = Color(0xFF25D366);
  static const sms = Color(0xFF7C5CFC);
  static const lightBackground = Color(0xFFF3F5F9);
  static const darkBackground = Color(0xFF0B0E14);
  static const darkSurface = Color(0xFF151A23);

  /// Segment colours for charts drawn on the navy hero gradient.
  static const chart = [
    Color(0xFF8AB4FF),
    Color(0xFF5EE0BF),
    Color(0xFFFFC870),
    Color(0xFFFF8FAB),
  ];

  /// Navy-to-indigo gradient used by hero cards and banners.
  static LinearGradient hero(Brightness brightness) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brightness == Brightness.dark
        ? const [Color(0xFF1C2850), Color(0xFF141C36)]
        : const [Color(0xFF14224A), Color(0xFF2E3F8F)],
  );

  /// Soft elevation for floating cards in light mode.
  static List<BoxShadow> softShadow(Brightness brightness) =>
      brightness == Brightness.dark
      ? const []
      : [
          BoxShadow(
            color: navy.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ];
}

abstract final class AppTheme {
  static const radius = 20.0;
  static const maxContentWidth = 720.0;

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.navy,
          primary: AppColors.navy,
          secondary: AppColors.accent,
          surface: Colors.white,
        ).copyWith(
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF0F2F6),
          surfaceContainerHighest: const Color(0xFFE6E9EF),
          outlineVariant: const Color(0xFFE6E9F0),
        );
    return _build(scheme, AppColors.lightBackground);
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.navy,
          brightness: Brightness.dark,
          primary: const Color(0xFF9DB8F5),
          secondary: const Color(0xFF7FA3F2),
          surface: AppColors.darkSurface,
        ).copyWith(
          surfaceContainerLowest: AppColors.darkSurface,
          surfaceContainerLow: const Color(0xFF1D222B),
          surfaceContainerHighest: const Color(0xFF272D38),
          outlineVariant: const Color(0xFF2A303B),
        );
    return _build(scheme, AppColors.darkBackground);
  }

  static ThemeData _build(ColorScheme scheme, Color background) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
    );
    final text = base.textTheme;
    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        // Material 3 defaults (0.25–0.5) read loose on iOS system fonts.
        bodyLarge: text.bodyLarge?.copyWith(letterSpacing: 0.1),
        bodyMedium: text.bodyMedium?.copyWith(letterSpacing: 0.1),
        bodySmall: text.bodySmall?.copyWith(letterSpacing: 0.15),
        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.secondary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Horizontal padding that keeps content readable on tablets.
EdgeInsets contentPadding(BuildContext context, {double vertical = 0}) {
  final width = MediaQuery.sizeOf(context).width;
  final side = width > AppTheme.maxContentWidth + 40
      ? (width - AppTheme.maxContentWidth) / 2
      : 20.0;
  return EdgeInsets.symmetric(horizontal: side, vertical: vertical);
}
