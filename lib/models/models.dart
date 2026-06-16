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
  // ── Morning ───────────────────────────────────────────────────────────────
  HabitModel(id: 'no_phone_10',    label: 'No phone first 10 min',           blockId: 'morning'),
  HabitModel(id: 'cold_shower',    label: 'Cold shower',                      blockId: 'morning'),
  HabitModel(id: 'get_dressed',    label: 'Get dressed — no scrolling',       blockId: 'morning'),
  HabitModel(id: 'breakfast',      label: 'Breakfast',                        blockId: 'morning', isNonNeg: true),
  HabitModel(id: 'protein_first',  label: 'Protein first',                    blockId: 'morning'),
  HabitModel(id: 'no_caff_early',  label: 'No caffeine yet',                  blockId: 'morning'),
  HabitModel(id: 'waited_90min',   label: 'Waited 90 min after waking',       blockId: 'morning'),
  // ── Lab / Work ───────────────────────────────────────────────────────────
  HabitModel(id: 'phone_away',     label: 'Phone out of reach',               blockId: 'lab'),
  HabitModel(id: 'hard_tasks',     label: 'Hard tasks in alert window',       blockId: 'lab'),
  HabitModel(id: 'work_near_ppl',  label: 'Work near others when possible',   blockId: 'lab'),
  // ── Midday ───────────────────────────────────────────────────────────────
  HabitModel(id: 'protein_lunch',  label: 'Protein-rich lunch',               blockId: 'midday'),
  HabitModel(id: 'no_carb_only',   label: 'Avoid pure carb meal',             blockId: 'midday'),
  HabitModel(id: 'water_lunch',    label: 'Water',                            blockId: 'midday'),
  // ── Afternoon ────────────────────────────────────────────────────────────
  HabitModel(id: 'herbal_tea',     label: 'Herbal tea @ 15:30',              blockId: 'afternoon', isNonNeg: true),
  HabitModel(id: 'no_sugar_crash', label: 'No sugar crash',                   blockId: 'afternoon'),
  HabitModel(id: 'last_caffeine',  label: 'Last caffeine — hard rule',        blockId: 'afternoon'),
  HabitModel(id: 'wind_buffer',    label: 'Light tasks only (16:30–17:30)',   blockId: 'afternoon'),
  // ── Evening ──────────────────────────────────────────────────────────────
  HabitModel(id: 'workout',        label: '30 min workout',                   blockId: 'evening'),
  HabitModel(id: 'protein_shake',  label: 'Protein shake after workout',      blockId: 'evening'),
  HabitModel(id: 'post_shower',    label: 'Shower after workout',             blockId: 'evening'),
  HabitModel(id: 'cook_eat',       label: 'Cook and eat dinner',              blockId: 'evening'),
  // ── Night ─────────────────────────────────────────────────────────────────
  HabitModel(id: 'screens_dim',    label: 'Screens dim 30 min before sleep',  blockId: 'night'),
  HabitModel(id: 'phone_charging', label: 'Phone charging out of reach',      blockId: 'night'),
  HabitModel(id: 'sleep_2300',     label: 'Sleep by 23:00',                   blockId: 'night', isNonNeg: true),
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
  ShopModel(id: 'migros',   name: 'Migros',   emoji: '🛒'),
  ShopModel(id: 'coop',     name: 'Coop',     emoji: '🛒'),
  ShopModel(id: 'lidl',     name: 'Lidl',     emoji: '💰'),
  ShopModel(id: 'aldi',     name: 'Aldi',     emoji: '💰'),
  ShopModel(id: 'pharmacy', name: 'Pharmacy', emoji: '💊'),
  ShopModel(id: 'market',   name: 'Market',   emoji: '🥦'),
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

List<ProjectModel> defaultProjects() => [
  ProjectModel(
    id: 'sample_project',
    name: 'Sample Project',
    tasks: [
      TaskGroup(id: 'sp_research', label: 'Research', subtasks: [
        SubTaskModel(id: 'r1', label: 'Define scope'),
        SubTaskModel(id: 'r2', label: 'Gather resources'),
      ]),
      TaskGroup(id: 'sp_build', label: 'Build', subtasks: [
        SubTaskModel(id: 'b1', label: 'Set up environment'),
        SubTaskModel(id: 'b2', label: 'Implement core feature'),
        SubTaskModel(id: 'b3', label: 'Review & iterate'),
      ]),
      TaskGroup(id: 'sp_ship', label: 'Ship', subtasks: [
        SubTaskModel(id: 's1', label: 'Final review'),
        SubTaskModel(id: 's2', label: 'Deploy'),
      ]),
    ],
  ),
];
