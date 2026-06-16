import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'storage_service.dart';

/// Handles incoming Android intents from Google Assistant App Actions.
///
/// Supported voice commands:
///   "Hey Google, tick cold shower in Zelv Track"
///   "Hey Google, add milk to shopping in Zelv Track"
///   "Hey Google, open shopping in Zelv Track"
///   "Hey Google, mark pension transfer done in Zelv Track"
///   "Hey Google, add book dentist to Health group in Zelv Track"
///   "Hey Google, add group Finance to Geneva Exit in Zelv Track"
///   "Hey Google, create project Home Renovation in Zelv Track"
class IntentService {
  IntentService._();
  static final instance = IntentService._();

  static const _channel = MethodChannel('com.zelv.track/intent');

  /// Called by MainNav so intents can switch tabs while app is open
  ValueChanged<int>? onNavigate;

  void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIntent') {
        final data = (call.arguments as Map?)?.cast<String, String?>();
        if (data != null) await _handle(data);
      }
    });
  }

  /// Call once on app start to process the intent that launched the app
  Future<void> handleLaunchIntent() async {
    try {
      final raw = await _channel.invokeMethod<Map>('getPendingIntent');
      if (raw == null) return;
      await _handle(raw.cast<String, String?>());
    } catch (_) {}
  }

  // ── Dispatcher ─────────────────────────────────────────────────────────────

  Future<void> _handle(Map<String, String?> data) async {
    final type = data['type'];
    final s = StorageService.instance;

    switch (type) {
      case 'tick_habit':
        await _tickHabit(data['habit_name'] ?? '', s);

      case 'add_shopping':
        await _addShopping(data['item_name'] ?? '', data['shop_name'] ?? '', s);
        onNavigate?.call(3);

      case 'open_screen':
        final idx = _screenIndex((data['screen_name'] ?? '').toLowerCase());
        if (idx >= 0) onNavigate?.call(idx);

      case 'tick_subtask':
        await _tickSubtask(data['subtask_name'] ?? '', s);
        onNavigate?.call(2);

      case 'add_subtask':
        await _addSubtask(data['subtask_name'] ?? '', data['group_name'] ?? '', s);
        onNavigate?.call(2);

      case 'add_task_group':
        await _addTaskGroup(data['group_name'] ?? '', data['project_name'] ?? '', s);
        onNavigate?.call(2);

      case 'create_project':
        await _createProject(data['project_name'] ?? '', s);
        onNavigate?.call(2);
    }
  }

  // ── Tick habit ─────────────────────────────────────────────────────────────

  Future<void> _tickHabit(String query, StorageService s) async {
    if (query.isEmpty) return;
    final habit = _fuzzyMatchHabit(query, s.getHabits());
    if (habit != null) await s.setHabit(habit.id, checked: true);
  }

  HabitModel? _fuzzyMatchHabit(String query, List<HabitModel> habits) {
    final q = query.toLowerCase();
    HabitModel? best;
    int bestScore = 0;
    for (final h in habits) {
      final label = h.label.toLowerCase();
      if (label == q) return h;
      final score = q.split(RegExp(r'\s+')).where((w) => w.length > 2 && label.contains(w)).length;
      if (score > bestScore) { bestScore = score; best = h; }
    }
    return best;
  }

  // ── Tick subtask ───────────────────────────────────────────────────────────

  Future<void> _tickSubtask(String query, StorageService s) async {
    if (query.isEmpty) return;
    final q = query.toLowerCase();
    final projects = s.getProjects();

    for (final project in projects) {
      for (final group in project.tasks) {
        for (final sub in group.subtasks) {
          if (_fuzzyScore(q, sub.label.toLowerCase()) > 0) {
            sub.done = true;
            await s.updateProject(project);
            return;
          }
        }
      }
    }
  }

  // ── Add subtask to a group ─────────────────────────────────────────────────

  Future<void> _addSubtask(String subtaskName, String groupName, StorageService s) async {
    if (subtaskName.isEmpty) return;
    final projects = s.getProjects();

    // Find group by name across all projects
    for (final project in projects) {
      for (final group in project.tasks) {
        if (groupName.isEmpty || _fuzzyScore(groupName.toLowerCase(), group.label.toLowerCase()) > 0) {
          group.subtasks.add(SubTaskModel(
            id:    '${group.id}_${DateTime.now().millisecondsSinceEpoch}',
            label: subtaskName,
          ));
          await s.updateProject(project);
          return;
        }
      }
    }
  }

  // ── Add task group to a project ────────────────────────────────────────────

  Future<void> _addTaskGroup(String groupName, String projectName, StorageService s) async {
    if (groupName.isEmpty) return;
    final projects = s.getProjects();

    ProjectModel? target;
    if (projectName.isNotEmpty) {
      final q = projectName.toLowerCase();
      target = projects.where((p) => _fuzzyScore(q, p.name.toLowerCase()) > 0).firstOrNull;
    }
    target ??= projects.firstOrNull; // default: first project

    if (target == null) return;
    target.tasks.add(TaskGroup(
      id:       '${target.id}_${DateTime.now().millisecondsSinceEpoch}',
      label:    groupName,
      subtasks: [],
    ));
    await s.updateProject(target);
  }

  // ── Create project ─────────────────────────────────────────────────────────

  Future<void> _createProject(String name, StorageService s) async {
    if (name.isEmpty) return;
    final id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_')
        + '_${DateTime.now().millisecondsSinceEpoch}';
    await s.addProject(ProjectModel(id: id, name: name, tasks: []));
  }

  // ── Add shopping item ───────────────────────────────────────────────────────

  Future<void> _addShopping(String itemName, String shopName, StorageService s) async {
    if (itemName.isEmpty) return;
    String? matchedShop;
    if (shopName.isNotEmpty) {
      final q = shopName.toLowerCase();
      matchedShop = s.getShops()
          .where((sh) => sh.name.toLowerCase().contains(q))
          .firstOrNull
          ?.name;
    }
    await s.addShoppingItem(ShoppingItem(
      id:    DateTime.now().millisecondsSinceEpoch.toString(),
      label: itemName,
      shop:  matchedShop,
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  int _fuzzyScore(String query, String target) =>
      query.split(RegExp(r'\s+')).where((w) => w.length > 2 && target.contains(w)).length;

  int _screenIndex(String s) {
    if (s.contains('routine') || s.contains('habit')) return 0;
    if (s.contains('stat')    || s.contains('heat'))  return 1;
    if (s.contains('project') || s.contains('goal'))  return 2;
    if (s.contains('shop')    || s.contains('list'))  return 3;
    return -1;
  }
}
