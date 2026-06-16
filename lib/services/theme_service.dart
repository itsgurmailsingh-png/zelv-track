import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ─── Accent presets ───────────────────────────────────────────────────────────
class AccentPreset {
  final String name;
  final Color color;
  final Color dim;          // ~15% opacity version for backgrounds

  const AccentPreset({
    required this.name,
    required this.color,
    required this.dim,
  });
}

const List<AccentPreset> kAccentPresets = [
  AccentPreset(
    name: 'Mint',
    color: Color(0xFF00E5A0),
    dim: Color(0x2600E5A0),
  ),
  AccentPreset(
    name: 'Violet',
    color: Color(0xFF7C6EFF),
    dim: Color(0x267C6EFF),
  ),
  AccentPreset(
    name: 'Rose',
    color: Color(0xFFFF4B6E),
    dim: Color(0x26FF4B6E),
  ),
  AccentPreset(
    name: 'Amber',
    color: Color(0xFFFFB800),
    dim: Color(0x26FFB800),
  ),
  AccentPreset(
    name: 'Sky',
    color: Color(0xFF00BFFF),
    dim: Color(0x2600BFFF),
  ),
];

// ─── ThemeService ─────────────────────────────────────────────────────────────
// Persists theme mode + accent color index in Hive.

class ThemeService extends ChangeNotifier {
  static ThemeService? _instance;
  ThemeService._();
  static ThemeService get instance {
    _instance ??= ThemeService._();
    return _instance!;
  }

  static const _kBox = 'prefs';
  static const _kMode = 'theme_mode';     // 'dark' | 'light'
  static const _kAccent = 'accent_index'; // 0–4

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_kBox);
  }

  ThemeMode get themeMode {
    final stored = _box.get(_kMode, defaultValue: 'dark') as String;
    return stored == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  int get accentIndex {
    final idx = _box.get(_kAccent, defaultValue: 0) as int;
    return idx.clamp(0, kAccentPresets.length - 1);
  }

  AccentPreset get accent => kAccentPresets[accentIndex];

  Future<void> setThemeMode(ThemeMode mode) async {
    await _box.put(_kMode, mode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }

  Future<void> setAccent(int index) async {
    await _box.put(_kAccent, index.clamp(0, kAccentPresets.length - 1));
    notifyListeners();
  }

  void toggleMode() {
    setThemeMode(themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
