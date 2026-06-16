import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/storage_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'main_nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF141414),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Init storage first (opens Hive), then theme (opens prefs box)
  await StorageService.instance.init();
  await ThemeService.instance.init();

  runApp(const RoutineTrackerApp());
}

class RoutineTrackerApp extends StatefulWidget {
  const RoutineTrackerApp({super.key});

  @override
  State<RoutineTrackerApp> createState() => _RoutineTrackerAppState();
}

class _RoutineTrackerAppState extends State<RoutineTrackerApp> {
  final _themeService = ThemeService.instance;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final mode = _themeService.themeMode;
    final preset = _themeService.accent;

    return MaterialApp(
      title: 'Zelv Track',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(ThemeMode.light, preset),
      darkTheme: buildTheme(ThemeMode.dark, preset),
      themeMode: mode,
      home: const MainNav(),
    );
  }
}
