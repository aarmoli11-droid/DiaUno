import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

TextTheme _textTheme(Palette p) {
  final base = GoogleFonts.interTextTheme();
  return base.copyWith(
    displayLarge: GoogleFonts.inter(
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: p.text,
      letterSpacing: -0.8,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: 27,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: p.text,
      letterSpacing: -0.5,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: p.text,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 18,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: p.text,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: p.text,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      height: 1.55,
      fontWeight: FontWeight.w400,
      color: p.text,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14.5,
      height: 1.55,
      fontWeight: FontWeight.w400,
      color: p.text,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: p.text,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12.5,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: p.textSecondary,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12.5,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: p.textSecondary,
    ),
  );
}

ThemeData _build(Palette p, Brightness brightness) {
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.surfaceMuted,
    onPrimaryContainer: p.text,
    secondary: p.accent,
    onSecondary: Colors.white,
    secondaryContainer: p.surfaceMuted,
    onSecondaryContainer: p.text,
    tertiary: p.success,
    onTertiary: p.onPrimary,
    surface: p.surface,
    onSurface: p.onSurface,
    surfaceContainerHighest: p.surfaceMuted,
    onSurfaceVariant: p.textSecondary,
    outline: p.border,
    outlineVariant: p.border,
    error: p.error,
    onError: brightness == Brightness.light ? Colors.white : Colors.black87,
    errorContainer: p.surfaceMuted,
    onErrorContainer: p.error,
    inverseSurface: p.text,
    onInverseSurface: p.surface,
    shadow: Colors.black26,
    scrim: p.scrim,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: p.background,
    textTheme: _textTheme(p),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: _textTheme(p).titleLarge,
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: p.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: p.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: p.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: p.error, width: 2),
      ),
      labelStyle: TextStyle(color: p.textSecondary, fontSize: 14),
      floatingLabelStyle: TextStyle(color: p.primary, fontSize: 13),
      helperStyle: TextStyle(color: p.textSecondary, fontSize: 12),
      errorStyle: TextStyle(color: p.error, fontSize: 12.5),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : p.border,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.navBackground,
      indicatorColor: p.primary,
    ),
    dividerTheme: DividerThemeData(color: p.border, space: 1, thickness: 1),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.text,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      textStyle: TextStyle(color: p.surface, fontSize: 12),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceMuted,
      side: BorderSide(color: p.border),
      labelStyle: TextStyle(color: p.text, fontSize: 12.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
  );
}

class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);
}
