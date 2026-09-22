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
const _kBoxDailyLogs   = 'daily_logs';        // 'YYYY-MM-DD' → JSON DailyLogModel
const _kBoxWeeklyRev   = 'weekly_reviews';    // weekOf (Sunday) → JSON WeeklyReviewModel
const _kBoxScaleMeas   = 'scale_measurements';// 'YYYY-MM-DD' → JSON ScaleMeasurementModel
const _kBoxReports     = 'reports';           // 'list' → JSON list of ReportModel

typedef PlanPhaseInfo = ({
  int? currentWeek,
  String? phaseName,
  String? phaseTheme,
  String? rungStatus,
  bool stressActive,
  String? stressStatus,
  List<String> reading,
});

typedef CheckpointStatus = ({
  bool week4Due,
  bool week4Done,
  double? week4PtqDelta,
  double? week4SpinDelta,
  double? week4Pss10Delta,
  bool? week4AllImproved,
  bool week8Triggered,
  bool week8Due,
  bool week8Done,
});

// Best-effort detection of clinical scale scores inside extracted report text.
// Returns whichever of pss10/ucla/ptq/spin it could find a nearby number for.
Map<String, int> detectScaleScores(String text) {
  final patterns = {
    'pss10': RegExp(r'PSS-?10[^\d]{0,20}?(\d{1,3})', caseSensitive: false),
    'ucla':  RegExp(r'UCLA[^\d]{0,25}?(\d{1,3})', caseSensitive: false),
    'ptq':   RegExp(r'PTQ[^\d]{0,20}?(\d{1,3})', caseSensitive: false),
    'spin':  RegExp(r'SPIN[^\d]{0,20}?(\d{1,3})', caseSensitive: false),
  };
  final found = <String, int>{};
  patterns.forEach((key, re) {
    final m = re.firstMatch(text);
    if (m != null) {
      final v = int.tryParse(m.group(1)!);
      if (v != null) found[key] = v;
    }
  });
  return found;
}

class StorageService {
  static StorageService? _instance;
  StorageService._();
  static StorageService get instance => _instance ??= StorageService._();

  late Box _state;
  late Box _defs;
  late Box _history;
  late Box _projects;
  late Box _prefs;
  late Box _dailyLogs;
  late Box _weeklyRev;
  late Box _scaleMeas;
  late Box _reports;

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
    _dailyLogs = await Hive.openBox(_kBoxDailyLogs);
    _weeklyRev = await Hive.openBox(_kBoxWeeklyRev);
    _scaleMeas = await Hive.openBox(_kBoxScaleMeas);
    _reports   = await Hive.openBox(_kBoxReports);
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

  // ── Daily log CRUD ────────────────────────────────────────────────────────

  DailyLogModel getDailyLog(String date) {
    final raw = _dailyLogs.get(date);
    if (raw == null) return DailyLogModel(date: date);
    return DailyLogModel.fromJson(jsonDecode(raw as String) as Map<String, dynamic>);
  }

  Future<void> saveDailyLog(DailyLogModel log) async {
    log.mealsPlanned = log.mealsPlanned.clamp(0, 3);
    log.mood = log.mood.clamp(0, 10);
    log.kneePain = log.kneePain.clamp(0, 10);
    log.predictedConfidence = log.predictedConfidence.clamp(0, 100);
    await _dailyLogs.put(log.date, jsonEncode(log.toJson()));
  }

  List<DailyLogModel> getDailyLogs({int days = 7}) => List.generate(days, (i) {
        final date = DateFormat('yyyy-MM-dd')
            .format(DateTime.now().subtract(Duration(days: days - 1 - i)));
        return getDailyLog(date);
      });

  // ── Weekly review CRUD ───────────────────────────────────────────────────

  String weekOfFor(DateTime d) {
    // Roll back to the most recent Sunday (DateTime.weekday: Mon=1..Sun=7).
    final sunday = d.subtract(Duration(days: d.weekday % 7));
    return DateFormat('yyyy-MM-dd').format(sunday);
  }

  WeeklyReviewModel getWeeklyReview(String weekOf) {
    final raw = _weeklyRev.get(weekOf);
    if (raw == null) return WeeklyReviewModel(weekOf: weekOf);
    return WeeklyReviewModel.fromJson(jsonDecode(raw as String) as Map<String, dynamic>);
  }

  Future<void> saveWeeklyReview(WeeklyReviewModel review) async {
    for (final f in review.forecasts) {
      f.probability = f.probability.clamp(0, 100);
    }
    await _weeklyRev.put(review.weekOf, jsonEncode(review.toJson()));
  }

  List<WeeklyReviewModel> getWeeklyReviews({int weeks = 12}) => List.generate(weeks, (i) {
        final weekOf = weekOfFor(DateTime.now().subtract(Duration(days: 7 * (weeks - 1 - i))));
        return getWeeklyReview(weekOf);
      });

  // ── Scale measurement CRUD ───────────────────────────────────────────────

  List<ScaleMeasurementModel> getScaleMeasurements() {
    final dates = _scaleMeas.keys.cast<String>().toList()..sort();
    return dates
        .map((d) => ScaleMeasurementModel.fromJson(
            jsonDecode(_scaleMeas.get(d) as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveScaleMeasurement(ScaleMeasurementModel m) async =>
      _scaleMeas.put(m.date, jsonEncode(m.toJson()));

  Future<void> deleteScaleMeasurement(String date) async =>
      _scaleMeas.delete(date);

  // ── Plan schedule anchor ─────────────────────────────────────────────────

  String? getPlanStartDate() => _prefs.get('plan_start_date') as String?;

  Future<void> setPlanStartDate(String date) async => _prefs.put('plan_start_date', date);

  // 1-indexed plan week for a given date; null if no start date set or date precedes it.
  int? weekNumberForDate(String date) {
    final start = getPlanStartDate();
    if (start == null) return null;
    final diff = DateTime.parse(date).difference(DateTime.parse(start)).inDays;
    if (diff < 0) return null;
    return (diff ~/ 7) + 1;
  }

  bool isRuminationFieldActive(String date) {
    final w = weekNumberForDate(date);
    return w != null && w >= 1 && w <= 4;
  }

  // ── Plan derived views ───────────────────────────────────────────────────

  double mvdPercentForDate(DailyLogModel d) {
    final items = [
      d.trainingMin > 0,
      d.mealsPlanned > 0,
      d.deviceFreeMin > 0,
      d.socialInitiation,
      d.mood > 0,
    ];
    if (isRuminationFieldActive(d.date)) items.add(d.ruminationPostponementUsed);
    return items.where((b) => b).length / items.length;
  }

  PlanPhaseInfo getCurrentPhaseInfo() {
    final week = weekNumberForDate(DateFormat('yyyy-MM-dd').format(DateTime.now()));
    if (week == null) {
      return (
        currentWeek: null, phaseName: null, phaseTheme: null,
        rungStatus: null, stressActive: false, stressStatus: null, reading: const [],
      );
    }
    final w = week.clamp(1, 12);
    return (
      currentWeek: week,
      phaseName: planPhaseNameForWeek(w),
      phaseTheme: planPhaseThemeForWeek(w),
      rungStatus: planRungForWeek(w),
      stressActive: planStressInoculationActiveForWeek(w),
      stressStatus: planStressInoculationStatusForWeek(w),
      reading: planReadingForWeek(w),
    );
  }

  // Week 4 / Week 8 checkpoint automation, per the recalibrated plan's decision
  // table: retest PTQ/SPIN/PSS-10 at Wk4; if not all three improved ≥20% but
  // at least one did, retest again at Wk8. "None moved" routes to a therapist
  // and doesn't schedule a Wk8 retest on its own.
  CheckpointStatus getCheckpointStatus() {
    if (getPlanStartDate() == null) {
      return (
        week4Due: false, week4Done: false,
        week4PtqDelta: null, week4SpinDelta: null, week4Pss10Delta: null,
        week4AllImproved: null, week8Triggered: false, week8Due: false, week8Done: false,
      );
    }
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final currentWeek = weekNumberForDate(today) ?? 0;
    final scales = getScaleMeasurements();

    ScaleMeasurementModel? firstWhereOrNull(bool Function(ScaleMeasurementModel) test) {
      for (final m in scales) {
        if (test(m)) return m;
      }
      return null;
    }

    final baseline = firstWhereOrNull((m) => m.type == 'baseline');
    final week4Entry = firstWhereOrNull((m) => m.type == 'checkpoint' && weekNumberForDate(m.date) == 4);
    final week8Entry = firstWhereOrNull((m) => m.type == 'checkpoint' && weekNumberForDate(m.date) == 8);

    double? delta(int? base, int? check) =>
        (base == null || check == null || base == 0) ? null : (base - check) / base * 100;

    final ptqDelta = delta(baseline?.ptq, week4Entry?.ptq);
    final spinDelta = delta(baseline?.spin, week4Entry?.spin);
    final pss10Delta = delta(baseline?.pss10, week4Entry?.pss10);

    bool? allImproved;
    var movedCount = 0;
    if (ptqDelta != null && spinDelta != null && pss10Delta != null) {
      final moved = [ptqDelta >= 20, spinDelta >= 20, pss10Delta >= 20];
      movedCount = moved.where((b) => b).length;
      allImproved = movedCount == 3;
    }
    final week8Triggered = week4Entry != null && allImproved == false && movedCount > 0;

    return (
      week4Due: currentWeek >= 4 && week4Entry == null,
      week4Done: week4Entry != null,
      week4PtqDelta: ptqDelta, week4SpinDelta: spinDelta, week4Pss10Delta: pss10Delta,
      week4AllImproved: allImproved,
      week8Triggered: week8Triggered,
      week8Due: week8Triggered && currentWeek >= 8 && week8Entry == null,
      week8Done: week8Entry != null,
    );
  }

  double getMvdWeeklyPercent({String? weekOf}) {
    final sunday = weekOf != null ? DateTime.parse(weekOf) : DateTime.parse(weekOfFor(DateTime.now()));
    final days = List.generate(7, (i) =>
        getDailyLog(DateFormat('yyyy-MM-dd').format(sunday.add(Duration(days: i)))));
    if (days.isEmpty) return 0;
    return days.map(mvdPercentForDate).reduce((a, b) => a + b) / days.length;
  }

  double getPredictionAccuracy({int days = 30}) {
    final logs = getDailyLogs(days: days).where((d) => d.predictionCorrect != null).toList();
    if (logs.isEmpty) return 0;
    final correct = logs.where((d) => d.predictionCorrect == true).length;
    return correct / logs.length;
  }

  double getBrierScore({int weeks = 12}) {
    final forecasts = getWeeklyReviews(weeks: weeks)
        .expand((r) => r.forecasts)
        .where((f) => f.correct != null)
        .toList();
    if (forecasts.isEmpty) return 0;
    final sumSq = forecasts.fold<double>(0, (sum, f) {
      final p = f.probability / 100.0;
      final o = f.correct == true ? 1.0 : 0.0;
      return sum + (p - o) * (p - o);
    });
    return sumSq / forecasts.length;
  }

  List<({String date, int kneePain, int trainingMin})> getKneeLoadSeries({int days = 30}) =>
      getDailyLogs(days: days)
          .map((d) => (date: d.date, kneePain: d.kneePain, trainingMin: d.trainingMin))
          .toList();

  // ── Report CRUD ──────────────────────────────────────────────────────────

  List<ReportModel> getReports() {
    final raw = _reports.get('list');
    if (raw == null) return [];
    return (jsonDecode(raw as String) as List<dynamic>)
        .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  Future<void> _saveReports(List<ReportModel> reports) async =>
      _reports.put('list', jsonEncode(reports.map((r) => r.toJson()).toList()));

  Future<void> addReport(ReportModel report) async =>
      _saveReports(getReports()..add(report));

  Future<void> deleteReport(String id) async =>
      _saveReports(getReports().where((r) => r.id != id).toList());

  // ── Wellbeing score ───────────────────────────────────────────────────────
  // Composite 0–100: 40% clinical scales (inverted — lower raw score is better),
  // 30% rolling daily affect (mood + inverse rumination), 30% behavioral
  // (MVD% + prediction accuracy). Returns null until there's a baseline scale
  // measurement to normalize the clinical component against.

  double? getWellbeingScore({int rollingDays = 7}) {
    final scales = getScaleMeasurements();
    if (scales.isEmpty) return null;
    final latest = scales.last;

    double invert(int? value, int maxScale) {
      if (value == null) return 50; // neutral if that instrument wasn't filled
      return (1 - (value / maxScale).clamp(0.0, 1.0)) * 100;
    }

    final clinical = [
      invert(latest.pss10, 40),
      invert(latest.ucla, 80),
      invert(latest.ptq, 60),
      invert(latest.spin, 68),
    ].reduce((a, b) => a + b) / 4;

    final logs = getDailyLogs(days: rollingDays);
    final loggedMood = logs.where((d) => d.mood > 0).toList();
    final moodAvg = loggedMood.isEmpty
        ? 50.0
        : loggedMood.map((d) => d.mood / 10 * 100).reduce((a, b) => a + b) / loggedMood.length;
    final ruminationAvg = logs.isEmpty
        ? 0.0
        : logs.map((d) => d.ruminationLoops).reduce((a, b) => a + b) / logs.length;
    final ruminationScore = (100 - ruminationAvg * 10).clamp(0.0, 100.0);
    final affect = (moodAvg + ruminationScore) / 2;

    final mvdAvg = logs.isEmpty
        ? 0.0
        : logs.map(mvdPercentForDate).reduce((a, b) => a + b) / logs.length * 100;
    final resolvedPredictions = logs.any((d) => d.predictionCorrect != null);
    final accuracy = resolvedPredictions ? getPredictionAccuracy(days: rollingDays) * 100 : 50.0;
    final behavioral = (mvdAvg + accuracy) / 2;

    return clinical * 0.4 + affect * 0.3 + behavioral * 0.3;
  }

  // ── Unique ID helper ──────────────────────────────────────────────────────

  String newId() => DateTime.now().millisecondsSinceEpoch.toString();
}
