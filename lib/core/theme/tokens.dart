import 'package:flutter/material.dart';

/// Tokens semánticos. Las pantallas consumen esta capa, nunca colores literales.
class Palette {
  const Palette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.text,
    required this.textSecondary,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.onSurface,
    required this.navBackground,
    required this.navInactive,
    required this.scrim,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color text;
  final Color textSecondary;
  final Color border;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color onSurface;
  final Color navBackground;
  final Color navInactive;
  final Color scrim;

  Color stateColor(StateTone tone) => switch (tone) {
    StateTone.neutral => textSecondary,
    StateTone.success => success,
    StateTone.warning => warning,
    StateTone.error => error,
    StateTone.accent => accent,
  };
}

enum StateTone { neutral, success, warning, error, accent }

class AppColors {
  static const Palette light = Palette(
    background: Color(0xFFF6F8F5),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEEF2ED),
    text: Color(0xFF152019),
    textSecondary: Color(0xFF536159),
    border: Color(0xFFDCE4DC),
    primary: Color(0xFF2E6B4E),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF5A4A86),
    success: Color(0xFF277A4B),
    warning: Color(0xFF9A6708),
    error: Color(0xFFB23B3B),
    onSurface: Color(0xFF152019),
    navBackground: Color(0xFF18251D),
    navInactive: Color(0xFFB6C4BA),
    scrim: Color(0x66101A13),
  );

  static const Palette dark = Palette(
    background: Color(0xFF101713),
    surface: Color(0xFF18221C),
    surfaceMuted: Color(0xFF212E26),
    text: Color(0xFFEFF4EF),
    textSecondary: Color(0xFFA9B8AE),
    border: Color(0xFF33443A),
    primary: Color(0xFF7FC5A0),
    onPrimary: Color(0xFF0D1B13),
    accent: Color(0xFFB7A6E8),
    success: Color(0xFF7FD2A1),
    warning: Color(0xFFE0B45F),
    error: Color(0xFFF09090),
    onSurface: Color(0xFFEFF4EF),
    navBackground: Color(0xFF0A100C),
    navInactive: Color(0xFF9AABA0),
    scrim: Color(0x99000000),
  );
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double contentMaxWidth = 880;
  static const double navMaxWidth = 560;
}

class AppRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;
}
