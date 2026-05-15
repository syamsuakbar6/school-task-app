import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const seedColor = Color(0xFF3D5AFE);
  static const lightSurface = Color(0xFFF8F7F4);
  static const darkSurface = Color(0xFF111318);
  static const darkCard = Color(0xFF1E2128);

  static ThemeData get light {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final scheme = baseScheme.copyWith(
      surface: lightSurface,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFCFBF8),
      surfaceContainer: const Color(0xFFF1F0EC),
    );

    return _themeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardColor: Colors.white,
      appBarBackgroundColor: Colors.transparent,
      appBarForegroundColor: scheme.primary,
    );
  }

  static ThemeData get dark {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    final scheme = baseScheme.copyWith(
      surface: darkSurface,
      surfaceContainerLowest: darkCard,
      surfaceContainerLow: const Color(0xFF242832),
      surfaceContainer: const Color(0xFF2B303B),
    );

    return _themeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardColor: darkCard,
      appBarBackgroundColor: scheme.surface,
      appBarForegroundColor: scheme.onSurface,
    );
  }

  static ThemeData _themeData({
    required ColorScheme colorScheme,
    required Color scaffoldBackgroundColor,
    required Color cardColor,
    required Color appBarBackgroundColor,
    required Color appBarForegroundColor,
  }) {
    final textTheme = _textTheme(colorScheme);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    final focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      textTheme: textTheme,
      cardColor: cardColor,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: appBarBackgroundColor,
        foregroundColor: appBarForegroundColor,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: appBarForegroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        prefixIconColor: colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: focusedInputBorder,
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
        focusedErrorBorder: focusedInputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme colorScheme) {
    const String serifFamily = 'DMSerifDisplay';
    const String sansFamily = 'DMSans';
    TextStyle serif(TextStyle? base) => (base ?? const TextStyle()).copyWith(
        fontFamily: serifFamily,
        color: colorScheme.onSurface,
        letterSpacing: 0,
      );

    TextStyle sans(TextStyle? base) => (base ?? const TextStyle()).copyWith(
        fontFamily: sansFamily,
        color: colorScheme.onSurface,
        letterSpacing: 0,
      );
    const base = TextTheme();

    return TextTheme(
    displayLarge:  serif(base.displayLarge),
    displayMedium: serif(base.displayMedium),
    displaySmall:  serif(base.displaySmall),
    headlineLarge: serif(base.headlineLarge),
    headlineMedium:serif(base.headlineMedium),
    headlineSmall: serif(base.headlineSmall),
    titleLarge:    sans(base.titleLarge).copyWith(fontWeight: FontWeight.w700),
    titleMedium:   sans(base.titleMedium).copyWith(fontWeight: FontWeight.w700),
    titleSmall:    sans(base.titleSmall).copyWith(fontWeight: FontWeight.w700),
    bodyLarge:     sans(base.bodyLarge),
    bodyMedium:    sans(base.bodyMedium),
    bodySmall:     sans(base.bodySmall),
    labelLarge:    sans(base.labelLarge).copyWith(fontWeight: FontWeight.w700),
    labelMedium:   sans(base.labelMedium),
    labelSmall:    sans(base.labelSmall),
  ).apply(
      displayColor: colorScheme.onSurface,
      bodyColor: colorScheme.onSurface,
    );
  }
}