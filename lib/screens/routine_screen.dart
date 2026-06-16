import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/habit_tile.dart';
import '../widgets/progress_ring.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen>
    with WidgetsBindingObserver {
  final _storage = StorageService.instance;
  Map<String, bool> _checked = {};
  List<HabitModel> _habits = [];
  // which blocks are manually expanded by user
  final Set<String> _manualExpanded = {};
  final Set<String> _manualCollapsed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _storage.onAppResume().then((_) => _load());
  }

  void _load() => setState(() {
        _habits  = _storage.getHabits();
        _checked = _storage.getTodayState();
      });

  Future<void> _toggle(String id, bool val) async {
    HapticFeedback.lightImpact();
    await _storage.setHabit(id, checked: val);
    setState(() => _checked[id] = val);
  }

  double get _progress => _storage.getTodayProgress();

  List<HabitModel> _habitsFor(String blockId) =>
      _habits.where((h) => h.blockId == blockId).toList();

  List<HabitModel> get _nonNegs => _habits.where((h) => h.isNonNeg).toList();

  bool _isExpanded(String blockId, String activeId) {
    if (_manualCollapsed.contains(blockId)) return false;
    if (_manualExpanded.contains(blockId)) return true;
    return blockId == activeId;
  }

  void _toggleExpand(String blockId) {
    setState(() {
      if (_manualExpanded.contains(blockId)) {
        _manualExpanded.remove(blockId);
        _manualCollapsed.add(blockId);
      } else if (_manualCollapsed.contains(blockId)) {
        _manualCollapsed.remove(blockId);
        _manualExpanded.add(blockId);
      } else {
        // was auto — flip it
        _manualCollapsed.add(blockId);
      }
    });
  }

  void _showAddEdit(BuildContext context, {HabitModel? editing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HabitSheet(
        editing: editing,
        onSave: (h) async {
          editing == null
              ? await _storage.addHabit(h)
              : await _storage.updateHabit(h);
          _load();
        },
        onDelete: editing == null
            ? null
            : () async { await _storage.deleteHabit(editing.id); _load(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final activeId = currentBlockId();
    final now = DateTime.now();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEdit(context),
        backgroundColor: c.accent,
        foregroundColor: Colors.black,
        elevation: 0,
        child: const Icon(Icons.add, size: 28),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Greeting card + progress ───────────────────────────────────────
          SliverToBoxAdapter(
            child: _GreetingCard(progress: _progress, now: now),
          ),

          // ── Non-negotiables ────────────────────────────────────────────────
          if (_nonNegs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _NonNegRow(habits: _nonNegs, checked: _checked),
              ),
            ),

          // ── Time blocks ────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final block = kBlockDefs[i];
                  final habits = _habitsFor(block.id);
                  if (habits.isEmpty) return const SizedBox.shrink();

                  final isActive = block.id == activeId;
                  final expanded = _isExpanded(block.id, activeId);
                  final doneCount = habits.where((h) => _checked[h.id] == true).length;
                  final isPast = block.endHour <= now.hour;

                  return _BlockCard(
                    block: block,
                    habits: habits,
                    checked: _checked,
                    isActive: isActive,
                    isPast: isPast,
                    expanded: expanded,
                    doneCount: doneCount,
                    onToggleExpand: () => _toggleExpand(block.id),
                    onHabitToggle: _toggle,
                    onLongPress: (h) => _showAddEdit(context, editing: h),
                    onDelete: (h) async {
                      await _storage.deleteHabit(h.id);
                      _load();
                    },
                  );
                },
                childCount: kBlockDefs.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Greeting card ────────────────────────────────────────────────────────────

class _GreetingCard extends StatelessWidget {
  final double progress;
  final DateTime now;
  const _GreetingCard({required this.progress, required this.now});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final pct = (progress * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.accent.withValues(alpha: 0.18), c.accentDim.withValues(alpha: 0.08)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.accent.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_greeting, style: TextStyle(
              color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w800,
            )),
            const SizedBox(height: 4),
            Text(DateFormat('EEEE, d MMMM').format(now), style: TextStyle(
              color: c.textSecondary, fontSize: 14,
            )),
            const SizedBox(height: 14),
            Row(children: [
              _StatChip(
                label: '$pct%', sublabel: 'done today',
                color: c.accent,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: DateFormat('HH:mm').format(now), sublabel: 'now',
                color: const Color(0xFF7C6EFF),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 16),
        ProgressRing(progress: progress, size: 90, strokeWidth: 9),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  const _StatChip({required this.label, required this.sublabel, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
          color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        Text(sublabel, style: TextStyle(
          color: color.withValues(alpha: 0.75), fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─── Block card ───────────────────────────────────────────────────────────────

class _BlockCard extends StatelessWidget {
  final BlockDef block;
  final List<HabitModel> habits;
  final Map<String, bool> checked;
  final bool isActive;
  final bool isPast;
  final bool expanded;
  final int doneCount;
  final VoidCallback onToggleExpand;
  final Future<void> Function(String, bool) onHabitToggle;
  final void Function(HabitModel) onLongPress;
  final void Function(HabitModel) onDelete;

  const _BlockCard({
    required this.block,
    required this.habits,
    required this.checked,
    required this.isActive,
    required this.isPast,
    required this.expanded,
    required this.doneCount,
    required this.onToggleExpand,
    required this.onHabitToggle,
    required this.onLongPress,
    required this.onDelete,
  });

  // Unique color per time block
  static Color _blockColor(String id) {
    switch (id) {
      case 'morning':   return const Color(0xFFFFB800); // amber
      case 'lab':       return const Color(0xFF00BFFF); // sky blue
      case 'midday':    return const Color(0xFF00C48C); // green
      case 'afternoon': return const Color(0xFF7C6EFF); // violet
      case 'evening':   return const Color(0xFFFF6B35); // orange
      case 'night':     return const Color(0xFF5C6EFF); // indigo
      default:          return const Color(0xFF888888);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final complete = habits.isNotEmpty && doneCount == habits.length;
    final blockColor = _blockColor(block.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? blockColor.withValues(alpha: 0.6) : c.border,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive ? [
          BoxShadow(color: blockColor.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 4)),
        ] : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Left color stripe — unique per block
            Container(
              width: 4,
              color: complete
                  ? blockColor
                  : isActive
                      ? blockColor
                      : blockColor.withValues(alpha: 0.3),
            ),
            Expanded(
              child: Column(
        children: [
          // Header — always visible
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggleExpand,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: isActive ? blockColor.withValues(alpha: 0.08) : c.surface,
              ),
              child: Row(
                children: [
                  // Status dot
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? c.accent
                          : isPast && complete
                          ? c.accent.withValues(alpha: 0.5)
                          : c.border,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isActive) ...[
                              Text('NOW  ', style: TextStyle(
                                color: c.accent, fontSize: 10,
                                fontWeight: FontWeight.w800, letterSpacing: 1.2,
                              )),
                            ],
                            Text(block.label, style: TextStyle(
                              color: c.textPrimary, fontSize: 15,
                              fontWeight: FontWeight.w700,
                            )),
                          ],
                        ),
                        Text(block.timeRange, style: TextStyle(
                          color: c.textSecondary, fontSize: 11,
                        )),
                      ],
                    ),
                  ),
                  // Progress badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: complete
                          ? c.accent.withValues(alpha: 0.15)
                          : c.surfaceHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        if (complete)
                          Icon(Icons.check_circle_rounded, size: 12, color: c.accent),
                        if (complete) const SizedBox(width: 4),
                        Text('$doneCount/${habits.length}', style: TextStyle(
                          color: complete ? c.accent : c.textSecondary,
                          fontSize: 11, fontWeight: FontWeight.w600,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: c.textDisabled, size: 18,
                  ),
                ],
              ),
            ),
          ),

          // Habits — animated expand
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: expanded
                ? Column(
                    children: [
                      Divider(height: 1, color: c.border),
                      ...habits.map((h) => Dismissible(
                            key: ValueKey(h.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async => true,
                            onDismissed: (_) => onDelete(h),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                              ),
                              child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            ),
                            child: GestureDetector(
                              onLongPress: () => onLongPress(h),
                              child: HabitTile(
                                habit: h,
                                checked: checked[h.id] ?? false,
                                onChanged: (v) => onHabitToggle(h.id, v),
                              ),
                            ),
                          )),
                      const SizedBox(height: 4),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
              ],
            ),          // Column
          ),            // Expanded
        ]),             // Row children
      ),                // IntrinsicHeight
    ),                  // ClipRRect
  );
  }
}

// ─── Non-neg row ──────────────────────────────────────────────────────────────

class _NonNegRow extends StatelessWidget {
  final List<HabitModel> habits;
  final Map<String, bool> checked;
  const _NonNegRow({required this.habits, required this.checked});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Row(
      children: habits.map((h) {
        final done = checked[h.id] ?? false;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: done ? AppColors.warn.withValues(alpha: 0.12) : c.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: done ? AppColors.warn.withValues(alpha: 0.5) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: done ? AppColors.warn : c.textDisabled, size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(h.label, style: TextStyle(
                  color: done ? AppColors.warn : c.textSecondary,
                  fontSize: 10, fontWeight: FontWeight.w600,
                ), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Add/Edit habit sheet ─────────────────────────────────────────────────────

class _HabitSheet extends StatefulWidget {
  final HabitModel? editing;
  final void Function(HabitModel) onSave;
  final VoidCallback? onDelete;
  const _HabitSheet({this.editing, required this.onSave, this.onDelete});

  @override
  State<_HabitSheet> createState() => _HabitSheetState();
}

class _HabitSheetState extends State<_HabitSheet> {
  late final TextEditingController _ctrl;
  late String _blockId;
  late bool _isNonNeg;

  @override
  void initState() {
    super.initState();
    _ctrl     = TextEditingController(text: widget.editing?.label ?? '');
    _blockId  = widget.editing?.blockId ?? (currentBlockId().isEmpty ? 'morning' : currentBlockId());
    _isNonNeg = widget.editing?.isNonNeg ?? false;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _save() {
    final label = _ctrl.text.trim();
    if (label.isEmpty) return;
    widget.onSave(HabitModel(
      id: widget.editing?.id ?? StorageService.instance.newId(),
      label: label, blockId: _blockId, isNonNeg: _isNonNeg,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final isEdit = widget.editing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
            Text(isEdit ? 'Edit habit' : 'New habit',
              style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl, autofocus: true,
              style: TextStyle(color: c.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Habit name',
                hintStyle: TextStyle(color: c.textDisabled),
                filled: true, fillColor: c.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 14),
            Text('Time block', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: kBlockDefs.map((b) {
              final sel = _blockId == b.id;
              return GestureDetector(
                onTap: () => setState(() => _blockId = b.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? c.accent : c.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(b.label, style: TextStyle(
                    color: sel ? Colors.black : c.textSecondary,
                    fontSize: 12, fontWeight: FontWeight.w600,
                  )),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => setState(() => _isNonNeg = !_isNonNeg),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _isNonNeg ? AppColors.warn.withValues(alpha: 0.12) : c.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isNonNeg ? AppColors.warn.withValues(alpha: 0.5) : Colors.transparent),
                ),
                child: Row(children: [
                  Icon(_isNonNeg ? Icons.flag_rounded : Icons.flag_outlined,
                      color: _isNonNeg ? AppColors.warn : c.textSecondary, size: 20),
                  const SizedBox(width: 10),
                  Text('Non-negotiable (MUST)', style: TextStyle(
                    color: _isNonNeg ? AppColors.warn : c.textPrimary,
                    fontSize: 14, fontWeight: FontWeight.w500,
                  )),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              if (isEdit && widget.onDelete != null)
                TextButton(
                  onPressed: () { widget.onDelete!(); Navigator.pop(context); },
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accent, foregroundColor: Colors.black, elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isEdit ? 'Save' : 'Add',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
