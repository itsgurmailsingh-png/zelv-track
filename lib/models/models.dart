// ─── Fixed time-block containers ─────────────────────────────────────────────

class BlockDef {
  final String id;
  final String label;
  final String timeRange;
  final int startHour; // 24h
  final int endHour;
  const BlockDef(this.id, this.label, this.timeRange, this.startHour, this.endHour);
}

const List<BlockDef> kBlockDefs = [
  BlockDef('morning',   'Morning',    '7:00 – 9:00',   7,  9),
  BlockDef('lab',       'Lab / Work', '9:00 – 12:00',  9,  12),
  BlockDef('midday',    'Midday',     '12:00 – 14:00', 12, 14),
  BlockDef('afternoon', 'Afternoon',  '14:00 – 18:00', 14, 18),
  BlockDef('evening',   'Evening',    '18:00 – 21:00', 18, 21),
  BlockDef('night',     'Night',      '21:00 – 23:00', 21, 23),
];

BlockDef blockById(String id) =>
    kBlockDefs.firstWhere((b) => b.id == id, orElse: () => kBlockDefs.first);

String currentBlockId() {
  final h = DateTime.now().hour;
  for (final b in kBlockDefs) {
    if (h >= b.startHour && h < b.endHour) return b.id;
  }
  return ''; // outside all blocks
}

// ─── Dynamic habit ────────────────────────────────────────────────────────────

class HabitModel {
  final String id;
  String label;
  String blockId;
  bool isNonNeg;

  HabitModel({
    required this.id,
    required this.label,
    required this.blockId,
    this.isNonNeg = false,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'blockId': blockId, 'isNonNeg': isNonNeg};

  factory HabitModel.fromJson(Map<String, dynamic> j) => HabitModel(
        id: j['id'] as String,
        label: j['label'] as String,
        blockId: j['blockId'] as String,
        isNonNeg: j['isNonNeg'] as bool? ?? false,
      );

  HabitModel copyWith({String? label, String? blockId, bool? isNonNeg}) =>
      HabitModel(
        id: id,
        label: label ?? this.label,
        blockId: blockId ?? this.blockId,
        isNonNeg: isNonNeg ?? this.isNonNeg,
      );
}

// ─── Dynamic project — 3-level hierarchy ─────────────────────────────────────
//   Project → Task (group) → Subtask (item)

class SubTaskModel {
  final String id;
  String label;
  bool done;

  SubTaskModel({required this.id, required this.label, this.done = false});

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'done': done};

  factory SubTaskModel.fromJson(Map<String, dynamic> j) => SubTaskModel(
        id: j['id'] as String,
        label: j['label'] as String,
        done: j['done'] as bool? ?? false,
      );
}

class TaskGroup {
  final String id;
  String label;
  List<SubTaskModel> subtasks;

  TaskGroup({required this.id, required this.label, List<SubTaskModel>? subtasks})
      : subtasks = subtasks ?? [];

  bool get isComplete => subtasks.isNotEmpty && subtasks.every((s) => s.done);
  double get progress => subtasks.isEmpty
      ? 0 : subtasks.where((s) => s.done).length / subtasks.length;
  int get doneCount => subtasks.where((s) => s.done).length;

  Map<String, dynamic> toJson() => {
        'id': id, 'label': label,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
      };

  factory TaskGroup.fromJson(Map<String, dynamic> j) => TaskGroup(
        id: j['id'] as String,
        label: j['label'] as String,
        subtasks: (j['subtasks'] as List<dynamic>? ?? [])
            .map((s) => SubTaskModel.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class ProjectModel {
  final String id;
  String name;
  List<TaskGroup> tasks;
  bool isArchived;

  ProjectModel({
    required this.id,
    required this.name,
    List<TaskGroup>? tasks,
    this.isArchived = false,
  }) : tasks = tasks ?? [];

  int get totalSubtasks => tasks.fold(0, (s, t) => s + t.subtasks.length);
  int get doneSubtasks  => tasks.fold(0, (s, t) => s + t.doneCount);

  bool get isComplete => totalSubtasks > 0 && doneSubtasks == totalSubtasks;
  double get progress => totalSubtasks == 0 ? 0 : doneSubtasks / totalSubtasks;

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'isArchived': isArchived,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

  factory ProjectModel.fromJson(Map<String, dynamic> j) => ProjectModel(
        id: j['id'] as String,
        name: j['name'] as String,
        isArchived: j['isArchived'] as bool? ?? false,
        tasks: (j['tasks'] as List<dynamic>? ?? [])
            .map((t) => TaskGroup.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

// ─── Default seed data ────────────────────────────────────────────────────────

List<HabitModel> defaultHabits() => [
  // ── Morning 7:00–7:30 ──────────────────────────────────────────────────────
  HabitModel(id: 'no_phone_10',    label: 'No phone first 10 min',                 blockId: 'morning'),
  HabitModel(id: 'cold_shower',    label: 'Cold shower (2–3 min cold at end)',      blockId: 'morning'),
  HabitModel(id: 'get_dressed',    label: 'Get dressed — no screen scrolling',      blockId: 'morning'),
  // ── Breakfast 7:30 ────────────────────────────────────────────────────────
  HabitModel(id: 'breakfast',      label: 'Breakfast',                              blockId: 'morning', isNonNeg: true),
  HabitModel(id: 'protein_first',  label: 'Protein first (eggs, paneer, nuts)',     blockId: 'morning'),
  HabitModel(id: 'cemtore',        label: 'Cemtore K2-7 — 1 capsule with food',    blockId: 'morning'),
  HabitModel(id: 'omega3',         label: 'Omega-3 — 1–2g EPA with food',          blockId: 'morning'),
  HabitModel(id: 'no_caff_early',  label: 'No caffeine yet',                        blockId: 'morning'),
  // ── Chai/Coffee 8:00 ──────────────────────────────────────────────────────
  HabitModel(id: 'chai_or_coffee', label: 'Chai OR coffee with L-theanine (not both)', blockId: 'morning'),
  HabitModel(id: 'waited_90min',   label: 'Waited 90 min after waking',             blockId: 'morning'),
  // ── Lab / Work 9:00 ───────────────────────────────────────────────────────
  HabitModel(id: 'phone_away',     label: 'Phone out of reach',                     blockId: 'lab'),
  HabitModel(id: 'hard_tasks',     label: 'Hard tasks in alert window',             blockId: 'lab'),
  HabitModel(id: 'work_near_ppl',  label: 'Work near others when possible',         blockId: 'lab'),
  // ── Midday Lunch ──────────────────────────────────────────────────────────
  HabitModel(id: 'protein_lunch',  label: 'Protein prioritised (dal, paneer, chicken)', blockId: 'midday'),
  HabitModel(id: 'no_carb_only',   label: 'Avoid pure carb meal',                  blockId: 'midday'),
  HabitModel(id: 'ckap_syn_lunch', label: 'Ckap-Syn — 1 tablet with food',         blockId: 'midday'),
  HabitModel(id: 'water_lunch',    label: 'Water',                                  blockId: 'midday'),
  // ── Afternoon 15:30 ───────────────────────────────────────────────────────
  HabitModel(id: 'tulsi_tea',      label: 'Green Tulsi Tea @ 15:30',               blockId: 'afternoon', isNonNeg: true),
  HabitModel(id: 'no_sugar_crash', label: 'No sugar crash — keep it clean',         blockId: 'afternoon'),
  HabitModel(id: 'last_caffeine',  label: 'Last caffeine of the day — hard rule',   blockId: 'afternoon'),
  HabitModel(id: 'wind_buffer',    label: 'Light tasks only (16:30–17:30)',         blockId: 'afternoon'),
  HabitModel(id: 'no_caff_1700',   label: 'No new caffeine after 17:00',            blockId: 'afternoon'),
  // ── Evening Workout ───────────────────────────────────────────────────────
  HabitModel(id: 'trois_rollon',   label: 'Trois roll-on to knee 5–10 min before', blockId: 'evening'),
  HabitModel(id: 'cycling_30',     label: '30 min cycling (rehab intensity)',        blockId: 'evening'),
  HabitModel(id: 'knee_check',     label: 'Stop if knee swells or locks',           blockId: 'evening'),
  HabitModel(id: 'protein_shake',  label: 'Protein shake immediately after',        blockId: 'evening'),
  HabitModel(id: 'arthrosave',     label: 'Arthrosave Trio in shake / right after', blockId: 'evening'),
  HabitModel(id: 'post_shower',    label: 'Shower after workout',                   blockId: 'evening'),
  // ── Dinner ────────────────────────────────────────────────────────────────
  HabitModel(id: 'cook_eat',       label: 'Cook and eat',                           blockId: 'evening'),
  HabitModel(id: 'ckap_syn_din',   label: 'Ckap-Syn — 1 tablet with dinner',       blockId: 'evening'),
  HabitModel(id: 'trois_bed',      label: 'Trois roll-on if knee throbbing',        blockId: 'evening'),
  // ── Night ─────────────────────────────────────────────────────────────────
  HabitModel(id: 'screens_dim',    label: 'Screens dim 30 min before sleep',        blockId: 'night'),
  HabitModel(id: 'phone_charging', label: 'Phone charging out of reach',            blockId: 'night'),
  HabitModel(id: 'sleep_2300',     label: 'Sleep by 23:00',                         blockId: 'night', isNonNeg: true),
];

// ─── Shop ────────────────────────────────────────────────────────────────────

class ShopModel {
  final String id;
  String name;
  String emoji;

  ShopModel({required this.id, required this.name, this.emoji = '🏪'});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'emoji': emoji};

  factory ShopModel.fromJson(Map<String, dynamic> j) => ShopModel(
    id:    j['id']    as String,
    name:  j['name']  as String,
    emoji: j['emoji'] as String? ?? '🏪',
  );
}

List<ShopModel> defaultShops() => [
  ShopModel(id: 'supermarket', name: 'Supermarket', emoji: '🛒'),
  ShopModel(id: 'budget',      name: 'Budget store', emoji: '💰'),
  ShopModel(id: 'pharmacy',    name: 'Pharmacy',     emoji: '💊'),
  ShopModel(id: 'market',      name: 'Market',       emoji: '🥦'),
  ShopModel(id: 'other',       name: 'Other',        emoji: '🏪'),
];

// ─── Shopping item ────────────────────────────────────────────────────────────

class ShoppingItem {
  final String id;
  String label;
  String? brand;   // optional brand name
  String? shop;    // optional store (groups items by shop)
  bool done;

  ShoppingItem({
    required this.id,
    required this.label,
    this.brand,
    this.shop,
    this.done = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'label': label,
    if (brand != null) 'brand': brand,
    if (shop  != null) 'shop': shop,
    'done': done,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
    id:    j['id']    as String,
    label: j['label'] as String,
    brand: j['brand'] as String?,
    shop:  j['shop']  as String?,
    done:  j['done']  as bool? ?? false,
  );
}

// ─── Recalibrated plan schedule (reference — mirrors kBlockDefs' pattern) ────
// Pure functions of plan-week number, not stored per-user. See the week-4
// decision point: weeks 1–4 run the recalibrated timeline (rung held at 1,
// stress inoculation delayed); week 5 onward resumes the original calendar
// weeks unshifted, which compresses rung 2's window to weeks 5–6.

String planPhaseNameForWeek(int week) {
  if (week <= 4) return 'Phase A — Full push';
  if (week <= 8) return 'Phase B — Build';
  return 'Phase C/D — Load & test';
}

String planPhaseThemeForWeek(int week) {
  if (week <= 4) return 'Rumination + social-anxiety core work. Everything else at maintenance.';
  if (week <= 8) return 'Ladder and stress inoculation resume, on whichever path Week 4 selected.';
  return 'Load phase. Final measures and decision table at Week 12.';
}

String planRungForWeek(int week) {
  if (week <= 4) return 'Rung 1 — low-stakes initiations (hold, do not advance)';
  if (week <= 6) return 'Rung 2 — peer initiations, 1 follow-up/week';
  if (week <= 10) return 'Rung 3 — new-setting initiations weekly, 2 follow-ups/week';
  return 'Rung 4 — maintain, count people at 3+ contacts';
}

bool planStressInoculationActiveForWeek(int week) => week >= 5;

String planStressInoculationStatusForWeek(int week) {
  if (week < 5) return 'Not started — resumes Week 5';
  if (week <= 8) return 'Stage 1 — weekly deliberate stressor + debrief';
  return 'Stage 2 — difficulty +1, reappraisal script';
}

List<String> planReadingForWeek(int week) {
  if (week <= 4) return const ['Hope/Heimberg — core chapters (finish by Wk4)', 'Carbonell — Worry Trick (finish by Wk4)'];
  if (week <= 6) return const ['Kahneman — Thinking Fast & Slow (Pt 1–3)'];
  if (week <= 8) return const ['Korb — Upward Spiral', 'Goleman & Davidson — Altered Traits (from Wk7)'];
  if (week <= 11) return const ['Nagoski — Come As You Are', 'Tetlock — Superforecasting'];
  return const ['Galef — Scout Mindset', 'DBT Skills Workbook — dialectics chapter'];
}

// ─── Daily log (MVD — numbers, not ticks) ────────────────────────────────────

class DailyLogModel {
  final String date; // yyyy-MM-dd
  int trainingMin;
  String? trainingType; // strength / rehab / cycle / walk / hike / boxing
  int mealsPlanned; // 0–3
  int deviceFreeMin;
  bool socialInitiation;
  String? initiationType; // stranger / peer / follow-up
  String prediction;
  int predictedConfidence; // 0–100
  String outcome;
  bool? predictionCorrect; // null = unresolved
  int mood; // 1–10, 0 = not logged
  int ruminationLoops;
  bool ruminationPostponementUsed; // Weeks 1–4 only, then retires from MVD
  String ruminationPostponementNote;
  int kneePain; // 0–10
  bool kneeSwelling;
  String notes;

  DailyLogModel({
    required this.date,
    this.trainingMin = 0,
    this.trainingType,
    this.mealsPlanned = 0,
    this.deviceFreeMin = 0,
    this.socialInitiation = false,
    this.initiationType,
    this.prediction = '',
    this.predictedConfidence = 0,
    this.outcome = '',
    this.predictionCorrect,
    this.mood = 0,
    this.ruminationLoops = 0,
    this.ruminationPostponementUsed = false,
    this.ruminationPostponementNote = '',
    this.kneePain = 0,
    this.kneeSwelling = false,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'trainingMin': trainingMin,
        'trainingType': trainingType,
        'mealsPlanned': mealsPlanned,
        'deviceFreeMin': deviceFreeMin,
        'socialInitiation': socialInitiation,
        'initiationType': initiationType,
        'prediction': prediction,
        'predictedConfidence': predictedConfidence,
        'outcome': outcome,
        'predictionCorrect': predictionCorrect,
        'mood': mood,
        'ruminationLoops': ruminationLoops,
        'ruminationPostponementUsed': ruminationPostponementUsed,
        'ruminationPostponementNote': ruminationPostponementNote,
        'kneePain': kneePain,
        'kneeSwelling': kneeSwelling,
        'notes': notes,
      };

  factory DailyLogModel.fromJson(Map<String, dynamic> j) => DailyLogModel(
        date: j['date'] as String,
        trainingMin: j['trainingMin'] as int? ?? 0,
        trainingType: j['trainingType'] as String?,
        mealsPlanned: j['mealsPlanned'] as int? ?? 0,
        deviceFreeMin: j['deviceFreeMin'] as int? ?? 0,
        socialInitiation: j['socialInitiation'] as bool? ?? false,
        initiationType: j['initiationType'] as String?,
        prediction: j['prediction'] as String? ?? '',
        predictedConfidence: j['predictedConfidence'] as int? ?? 0,
        outcome: j['outcome'] as String? ?? '',
        predictionCorrect: j['predictionCorrect'] as bool?,
        mood: j['mood'] as int? ?? 0,
        ruminationLoops: j['ruminationLoops'] as int? ?? 0,
        ruminationPostponementUsed: j['ruminationPostponementUsed'] as bool? ?? false,
        ruminationPostponementNote: j['ruminationPostponementNote'] as String? ?? '',
        kneePain: j['kneePain'] as int? ?? 0,
        kneeSwelling: j['kneeSwelling'] as bool? ?? false,
        notes: j['notes'] as String? ?? '',
      );
}

// ─── Weekly review (Sunday) ───────────────────────────────────────────────────

class ForecastModel {
  String text;
  int probability; // 0–100
  String? outcome;
  bool? correct;

  ForecastModel({
    this.text = '',
    this.probability = 0,
    this.outcome,
    this.correct,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'probability': probability,
        'outcome': outcome,
        'correct': correct,
      };

  factory ForecastModel.fromJson(Map<String, dynamic> j) => ForecastModel(
        text: j['text'] as String? ?? '',
        probability: j['probability'] as int? ?? 0,
        outcome: j['outcome'] as String?,
        correct: j['correct'] as bool?,
      );
}

List<ForecastModel> defaultForecasts() =>
    List.generate(3, (_) => ForecastModel());

class WeeklyReviewModel {
  final String weekOf; // yyyy-MM-dd, Sunday
  List<ForecastModel> forecasts;
  String greyDrillCertainty;
  String greyDrillOpposite;
  String stressInoculationWhat;
  String stressInoculationDebrief;
  int followUpsSent;
  int peopleAt3PlusContacts;

  WeeklyReviewModel({
    required this.weekOf,
    List<ForecastModel>? forecasts,
    this.greyDrillCertainty = '',
    this.greyDrillOpposite = '',
    this.stressInoculationWhat = '',
    this.stressInoculationDebrief = '',
    this.followUpsSent = 0,
    this.peopleAt3PlusContacts = 0,
  }) : forecasts = forecasts ?? defaultForecasts();

  Map<String, dynamic> toJson() => {
        'weekOf': weekOf,
        'forecasts': forecasts.map((f) => f.toJson()).toList(),
        'greyDrillCertainty': greyDrillCertainty,
        'greyDrillOpposite': greyDrillOpposite,
        'stressInoculationWhat': stressInoculationWhat,
        'stressInoculationDebrief': stressInoculationDebrief,
        'followUpsSent': followUpsSent,
        'peopleAt3PlusContacts': peopleAt3PlusContacts,
      };

  factory WeeklyReviewModel.fromJson(Map<String, dynamic> j) =>
      WeeklyReviewModel(
        weekOf: j['weekOf'] as String,
        forecasts: (j['forecasts'] as List<dynamic>? ?? [])
            .map((f) => ForecastModel.fromJson(f as Map<String, dynamic>))
            .toList(),
        greyDrillCertainty: j['greyDrillCertainty'] as String? ?? '',
        greyDrillOpposite: j['greyDrillOpposite'] as String? ?? '',
        stressInoculationWhat: j['stressInoculationWhat'] as String? ?? '',
        stressInoculationDebrief:
            j['stressInoculationDebrief'] as String? ?? '',
        followUpsSent: j['followUpsSent'] as int? ?? 0,
        peopleAt3PlusContacts: j['peopleAt3PlusContacts'] as int? ?? 0,
      );
}

// ─── Scale measurement (weeks 1, 6, 12) ──────────────────────────────────────

class ScaleMeasurementModel {
  final String date;
  String type; // 'baseline' (full battery, weeks 1/6/12) | 'checkpoint' (PTQ/SPIN/PSS-10 only, weeks 4/8)
  int? pss10;
  int? ucla;
  int? ptq;
  int? spin;
  int? rhr;
  double? sleepAvg;
  double? screenAvg;
  double? weight;
  int? soiRBehavior;
  int? soiRAttitude;
  int? soiRDesire;

  ScaleMeasurementModel({
    required this.date,
    this.type = 'baseline',
    this.pss10,
    this.ucla,
    this.ptq,
    this.spin,
    this.rhr,
    this.sleepAvg,
    this.screenAvg,
    this.weight,
    this.soiRBehavior,
    this.soiRAttitude,
    this.soiRDesire,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'type': type,
        'pss10': pss10,
        'ucla': ucla,
        'ptq': ptq,
        'spin': spin,
        'rhr': rhr,
        'sleepAvg': sleepAvg,
        'screenAvg': screenAvg,
        'weight': weight,
        'soiRBehavior': soiRBehavior,
        'soiRAttitude': soiRAttitude,
        'soiRDesire': soiRDesire,
      };

  factory ScaleMeasurementModel.fromJson(Map<String, dynamic> j) =>
      ScaleMeasurementModel(
        date: j['date'] as String,
        type: j['type'] as String? ?? 'baseline',
        pss10: j['pss10'] as int?,
        ucla: j['ucla'] as int?,
        ptq: j['ptq'] as int?,
        spin: j['spin'] as int?,
        rhr: j['rhr'] as int?,
        sleepAvg: (j['sleepAvg'] as num?)?.toDouble(),
        screenAvg: (j['screenAvg'] as num?)?.toDouble(),
        weight: (j['weight'] as num?)?.toDouble(),
        soiRBehavior: j['soiRBehavior'] as int?,
        soiRAttitude: j['soiRAttitude'] as int?,
        soiRDesire: j['soiRDesire'] as int?,
      );
}

// ─── Uploaded report (PDF text extraction) ───────────────────────────────────

class ReportModel {
  final String id;
  String title;
  String filename;
  String uploadedAt; // yyyy-MM-dd
  String extractedText;

  ReportModel({
    required this.id,
    required this.title,
    required this.filename,
    required this.uploadedAt,
    this.extractedText = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filename': filename,
        'uploadedAt': uploadedAt,
        'extractedText': extractedText,
      };

  factory ReportModel.fromJson(Map<String, dynamic> j) => ReportModel(
        id: j['id'] as String,
        title: j['title'] as String,
        filename: j['filename'] as String,
        uploadedAt: j['uploadedAt'] as String,
        extractedText: j['extractedText'] as String? ?? '',
      );
}

List<ProjectModel> defaultProjects() => [];
