import 'package:flutter/material.dart';
import 'screens/routine_screen.dart';
import 'screens/heatmap_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/shopping_screen.dart';
import 'services/theme_service.dart';
import 'services/intent_service.dart';
import 'theme/app_theme.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Register navigation callback so IntentService can switch tabs
    IntentService.instance.onNavigate = (idx) {
      if (mounted) setState(() => _index = idx);
    };
  }

  @override
  void dispose() {
    IntentService.instance.onNavigate = null;
    super.dispose();
  }

  static const _screens = [
    RoutineScreen(),
    HeatmapScreen(),
    ProjectsScreen(),
    ShoppingScreen(),
  ];

  static const _navItems = [
    _NavDef(Icons.check_box_outline_blank, Icons.check_box, 'Routine',  Color(0xFF00E5A0)),
    _NavDef(Icons.bar_chart_outlined,      Icons.bar_chart,  'Stats',    Color(0xFF7C6EFF)),
    _NavDef(Icons.rocket_launch_outlined,  Icons.rocket_launch, 'Goals', Color(0xFFFF6B35)),
    _NavDef(Icons.shopping_cart_outlined,  Icons.shopping_cart, 'Shop',  Color(0xFF00BFFF)),
  ];

  void _showTheme(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ThemeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          color: c.surface,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Logo mark
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.accent, c.accent.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('Z', style: TextStyle(
                          color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w900,
                        )),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Zelv', style: TextStyle(
                      color: c.textPrimary, fontSize: 20,
                      fontWeight: FontWeight.w800, letterSpacing: -0.5,
                    )),
                    Text(' Track', style: TextStyle(
                      color: c.accent, fontSize: 20,
                      fontWeight: FontWeight.w800, letterSpacing: -0.5,
                    )),
                    const Spacer(),
                    // Theme button moved here
                    GestureDetector(
                      onTap: () => _showTheme(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: c.surfaceHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.palette_outlined, color: c.textSecondary, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                ...List.generate(_navItems.length, (i) {
                  final item = _navItems[i];
                  final active = _index == i;
                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _index = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: active ? item.color.withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              active ? item.activeIcon : item.icon,
                              color: active ? item.color : c.textSecondary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(item.label,
                            style: TextStyle(
                              color: active ? item.color : c.textSecondary,
                              fontSize: 10,
                              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                            )),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDef {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  const _NavDef(this.icon, this.activeIcon, this.label, this.color);
}

// ─── Theme sheet ──────────────────────────────────────────────────────────────

class _ThemeSheet extends StatefulWidget {
  const _ThemeSheet();

  @override
  State<_ThemeSheet> createState() => _ThemeSheetState();
}

class _ThemeSheetState extends State<_ThemeSheet> {
  final _ts = ThemeService.instance;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final isDark = _ts.themeMode == ThemeMode.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),

          Text('APPEARANCE', style: TextStyle(
            color: c.textSecondary, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 1.5,
          )),
          const SizedBox(height: 12),

          // Mode toggle
          GestureDetector(
            onTap: () { _ts.toggleMode(); setState(() {}); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: isDark ? const Color(0xFF7C6EFF) : const Color(0xFFFFB800), size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Text(isDark ? 'Dark mode' : 'Light mode',
                    style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w500))),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 48, height: 28,
                    decoration: BoxDecoration(
                      color: isDark ? c.accent : c.border,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        width: 22, height: 22,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text('ACCENT', style: TextStyle(
            color: c.textSecondary, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 1.5,
          )),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(kAccentPresets.length, (i) {
              final preset = kAccentPresets[i];
              final selected = _ts.accentIndex == i;
              return GestureDetector(
                onTap: () { _ts.setAccent(i); setState(() {}); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: preset.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent, width: 3,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: preset.color.withValues(alpha: 0.5), blurRadius: 12)]
                        : [],
                  ),
                  child: selected ? const Icon(Icons.check, color: Colors.black, size: 22) : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: kAccentPresets.map((p) => SizedBox(
              width: 52,
              child: Text(p.name, textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 10)),
            )).toList(),
          ),
        ],
      ),
    );
  }
}
