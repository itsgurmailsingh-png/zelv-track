import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

const _kBoxState   = 'habit_state';   // 'YYYY-MM-DD/habitId' → bool
const _kBoxDefs    = 'habit_defs';    // 'habits' → JSON list
const _kBoxHistory = 'history';       // 'YYYY-MM-DD' → double
const _kBoxProjects= 'projects';      // 'list' → JSON list
const _kBoxPrefs   = 'prefs';         // misc keys
const _kKeyDate    = '__date__';

class StorageService {
  static StorageService? _instance;
  StorageService._();
  static StorageService get instance => _instance ??= StorageService._();

  late Box _state;
  late Box _defs;
  late Box _history;
  late Box _projects;
  late Box _prefs;

  Future<void> init() async {
    // Use app-specific support dir, not ~/Documents
    final dir = await getApplicationSupportDirectory();
    final appDir = Directory('${dir.path}/routine_tracker');
    await appDir.create(recursive: true);
    Hive.init(appDir.path);
    _state    = await Hive.openBox(_kBoxState);
    _defs     = await Hive.openBox(_kBoxDefs);
    _history  = await Hive.openBox(_kBoxHistory);
    _projects = await Hive.openBox(_kBoxProjects);
    _prefs    = await Hive.openBox(_kBoxPrefs);
    await _seedIfEmpty();
    await _checkMidnightReset();
  }

  // ── Seed defaults on first launch ─────────────────────────────────────────
  // Bump this when the project data model changes — forces a re-seed.
  static const _kProjectSchema = 2;

  Future<void> _seedIfEmpty() async {
    if (_defs.get('habits') == null) {
      await _saveHabitList(defaultHabits());
    }
    final schema = _prefs.get('project_schema', defaultValue: 0) as int;
    if (_projects.get('list') == null || schema < _kProjectSchema) {
      await _saveProjectList(defaultProjects());
      await _prefs.put('project_schema', _kProjectSchema);
    }
  }

  // ── Date helpers ─────────────────────────────────────────────────────────

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _habitKey(String date, String id) => '$date/$id';

  // ── Midnight reset ────────────────────────────────────────────────────────

  Future<void> _checkMidnightReset() async {
    final stored = _prefs.get(_kKeyDate, defaultValue: '') as String;
    final today  = _today;
    if (stored != today) {
      if (stored.isNotEmpty) {
        await _history.put(stored, _computeScore(stored));
      }
      final toDelete = _state.keys.where((k) => k != _kKeyDate).toList();
      await _state.deleteAll(toDelete);
      await _prefs.put(_kKeyDate, today);
    }
  }

  Future<void> onAppResume() => _checkMidnightReset();

  double _computeScore(String date) {
    final ids = getHabits().map((h) => h.id).toList();
    if (ids.isEmpty) return 0;
    final done = ids.where((id) =>
        _state.get(_habitKey(date, id), defaultValue: false) == true).length;
    return done / ids.length;
  }

  // ── Habit definitions CRUD ────────────────────────────────────────────────

  List<HabitModel> getHabits() {
    final raw = _defs.get('habits');
    if (raw == null) return [];
    final list = jsonDecode(raw as String) as List<dynamic>;
    return list.map((e) => HabitModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveHabitList(List<HabitModel> habits) async {
    await _defs.put('habits', jsonEncode(habits.map((h) => h.toJson()).toList()));
  }

  Future<void> addHabit(HabitModel h) async {
    final list = getHabits()..add(h);
    await _saveHabitList(list);
  }

  Future<void> updateHabit(HabitModel updated) async {
    final list = getHabits().map((h) => h.id == updated.id ? updated : h).toList();
    await _saveHabitList(list);
  }

  Future<void> deleteHabit(String id) async {
    final list = getHabits().where((h) => h.id != id).toList();
    await _saveHabitList(list);
  }

  Future<void> reorderHabits(List<HabitModel> reordered) => _saveHabitList(reordered);

  // ── Daily habit state ─────────────────────────────────────────────────────

  Map<String, bool> getTodayState() {
    final today = _today;
    return {
      for (final h in getHabits())
        h.id: _state.get(_habitKey(today, h.id), defaultValue: false) as bool,
    };
  }

  Future<void> setHabit(String id, {required bool checked}) async =>
      _state.put(_habitKey(_today, id), checked);

  double getTodayProgress() => _computeScore(_today);

  // ── Heatmap ───────────────────────────────────────────────────────────────

  Map<String, Map<String, bool>> getHeatmapData({int days = 14}) {
    final habits = getHabits();
    final result = <String, Map<String, bool>>{};
    for (int i = 0; i < days; i++) {
      final date = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(Duration(days: i)));
      result[date] = {
        for (final h in habits)
          h.id: _state.get(_habitKey(date, h.id), defaultValue: false) as bool,
      };
    }
    return result;
  }

  double getScoreForDate(String date) {
    if (date == _today) return getTodayProgress();
    return _history.get(date, defaultValue: 0.0) as double;
  }

  // ── Projects CRUD ─────────────────────────────────────────────────────────

  List<ProjectModel> getProjects() {
    final raw = _projects.get('list');
    if (raw == null) return [];
    final list = jsonDecode(raw as String) as List<dynamic>;
    return list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveProjectList(List<ProjectModel> projects) async =>
      _projects.put('list', jsonEncode(projects.map((p) => p.toJson()).toList()));

  Future<void> addProject(ProjectModel p) async {
    final list = getProjects()..add(p);
    await _saveProjectList(list);
  }

  Future<void> updateProject(ProjectModel updated) async {
    final list = getProjects()
        .map((p) => p.id == updated.id ? updated : p)
        .toList();
    await _saveProjectList(list);
  }

  Future<void> deleteProject(String id) async {
    final list = getProjects().where((p) => p.id != id).toList();
    await _saveProjectList(list);
  }

  Future<void> archiveProject(String id) async {
    final list = getProjects().map((p) {
      if (p.id == id) p.isArchived = true;
      return p;
    }).toList();
    await _saveProjectList(list);
  }

  Future<void> unarchiveProject(String id) async {
    final list = getProjects().map((p) {
      if (p.id == id) p.isArchived = false;
      return p;
    }).toList();
    await _saveProjectList(list);
  }

  // Subtask toggle is embedded inside the ProjectModel — just call updateProject after toggling.

  // ── Shopping list ─────────────────────────────────────────────────────────

  List<ShoppingItem> getShoppingList() {
    final raw = _projects.get('shopping');
    if (raw == null) return [];
    return (jsonDecode(raw as String) as List<dynamic>)
        .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveShoppingList(List<ShoppingItem> items) async =>
      _projects.put('shopping', jsonEncode(items.map((i) => i.toJson()).toList()));

  Future<void> addShoppingItem(ShoppingItem item) async =>
      _saveShoppingList(getShoppingList()..add(item));

  Future<void> toggleShoppingItem(String id) async {
    final list = getShoppingList().map((i) {
      if (i.id == id) i.done = !i.done;
      return i;
    }).toList();
    await _saveShoppingList(list);
  }

  Future<void> deleteShoppingItem(String id) async =>
      _saveShoppingList(getShoppingList().where((i) => i.id != id).toList());

  Future<void> clearCompletedShopping() async =>
      _saveShoppingList(getShoppingList().where((i) => !i.done).toList());

  Future<void> saveShoppingList(List<ShoppingItem> items) async =>
      _saveShoppingList(items);

  // ── Shops CRUD ────────────────────────────────────────────────────────────

  List<ShopModel> getShops() {
    final raw = _projects.get('shops');
    if (raw == null) return defaultShops();
    return (jsonDecode(raw as String) as List<dynamic>)
        .map((e) => ShopModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveShops(List<ShopModel> shops) async =>
      _projects.put('shops', jsonEncode(shops.map((s) => s.toJson()).toList()));

  Future<void> addShop(ShopModel shop) async =>
      _saveShops(getShops()..add(shop));

  Future<void> updateShop(ShopModel updated) async =>
      _saveShops(getShops().map((s) => s.id == updated.id ? updated : s).toList());

  Future<void> deleteShop(String id) async =>
      _saveShops(getShops().where((s) => s.id != id).toList());

  // ── Stats ──────────────────────────────────────────────────────────────────

  int getCurrentStreak() {
    int streak = 0;
    for (int i = 0; i < 30; i++) {
      final date = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(Duration(days: i)));
      if (getScoreForDate(date) >= 0.5) streak++; else break;
    }
    return streak;
  }

  List<double> getWeeklyScores({int days = 7}) => List.generate(days, (i) {
        final date = DateFormat('yyyy-MM-dd')
            .format(DateTime.now().subtract(Duration(days: days - 1 - i)));
        return getScoreForDate(date);
      });

  Map<String, double> getHabitRates({int days = 7}) {
    final habits = getHabits();
    return {
      for (final h in habits)
        h.id: List.generate(days, (i) {
          final date = DateFormat('yyyy-MM-dd')
              .format(DateTime.now().subtract(Duration(days: i)));
          return _state.get(_habitKey(date, h.id), defaultValue: false) == true ? 1.0 : 0.0;
        }).fold(0.0, (a, b) => a + b) / days,
    };
  }

  // ── Unique ID helper ──────────────────────────────────────────────────────

  String newId() => DateTime.now().millisecondsSinceEpoch.toString();
}
