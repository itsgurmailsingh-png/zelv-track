import 'package:flutter/material.dart';
import '../services/theme_service.dart';

// ─── Dark palette (accent-aware) ──────────────────────────────────────────────
class AppColors {
  final Color accent;
  final Color accentDim;
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  static const warn = Color(0xFFFF6B35);

  const AppColors._dark({required this.accent, required this.accentDim})
      : bg = const Color(0xFF0A0A0A),
        surface = const Color(0xFF141414),
        surfaceHigh = const Color(0xFF1E1E1E),
        border = const Color(0xFF2A2A2A),
        textPrimary = const Color(0xFFF5F5F5),
        textSecondary = const Color(0xFF888888),
        textDisabled = const Color(0xFF444444);

  const AppColors._light({required this.accent, required this.accentDim})
      : bg = const Color(0xFFF5F5F7),        // Apple light gray
        surface = const Color(0xFFFFFFFF),   // pure white cards
        surfaceHigh = const Color(0xFFEEEEF3), // slightly elevated
        border = const Color(0xFFE5E5EA),    // iOS-style subtle border
        textPrimary = const Color(0xFF1C1C1E),  // Apple near-black
        textSecondary = const Color(0xFF6C6C70), // Apple secondary label
        textDisabled = const Color(0xFFAEAEB2); // Apple tertiary label

  factory AppColors.forMode(ThemeMode mode, AccentPreset preset) {
    if (mode == ThemeMode.light) {
      return AppColors._light(accent: preset.color, accentDim: preset.dim);
    }
    return AppColors._dark(accent: preset.color, accentDim: preset.dim);
  }
}

// ─── ThemeData builder ────────────────────────────────────────────────────────
ThemeData buildTheme(ThemeMode mode, AccentPreset preset) {
  final c = AppColors.forMode(mode, preset);
  final isDark = mode == ThemeMode.dark;

  return ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: c.accent,
      onPrimary: isDark ? Colors.black : Colors.white,
      secondary: AppColors.warn,
      onSecondary: Colors.white,
      error: Colors.red,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: c.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
      iconTheme: IconThemeData(color: c.textPrimary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.accentDim,
    ),
    dividerTheme: DividerThemeData(
      color: c.border,
      thickness: 1,
      space: 1,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return c.accent;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.black),
      side: BorderSide(color: c.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    splashColor: c.accentDim,
    highlightColor: Colors.transparent,
    extensions: [AppColorsExtension(colors: c)],
  );
}

// ─── ThemeExtension — access AppColors anywhere via Theme.of(context) ─────────
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final AppColors colors;
  const AppColorsExtension({required this.colors});

  @override
  AppColorsExtension copyWith({AppColors? colors}) =>
      AppColorsExtension(colors: colors ?? this.colors);

  @override
  AppColorsExtension lerp(AppColorsExtension? other, double t) => this;
}

// Shorthand accessor
AppColors appColors(BuildContext context) =>
    Theme.of(context).extension<AppColorsExtension>()!.colors;
