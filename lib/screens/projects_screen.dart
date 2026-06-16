import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

// Colors cycling per task group index
const _kGroupColors = [
  Color(0xFFFFB800), // amber
  Color(0xFF00BFFF), // sky
  Color(0xFF00C48C), // green
  Color(0xFF7C6EFF), // violet
  Color(0xFFFF6B35), // orange
  Color(0xFF5C6EFF), // indigo
];

Color _groupColor(int index) => _kGroupColors[index % _kGroupColors.length];

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _s = StorageService.instance;
  List<ProjectModel> _active   = [];
  List<ProjectModel> _archived = [];
  bool _showArchived = false;

  @override
  void initState() { super.initState(); _load(); }

  void _load() {
    final all = _s.getProjects();
    setState(() {
      _active   = all.where((p) => !p.isArchived).toList();
      _archived = all.where((p) => p.isArchived).toList();
    });
  }

  void _openProjectSheet([ProjectModel? editing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectSheet(
        editing: editing,
        onSave: (p) async {
          editing == null ? await _s.addProject(p) : await _s.updateProject(p);
          _load();
        },
        onDelete: editing == null ? null : () async {
          await _s.deleteProject(editing.id);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openProjectSheet(),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add, size: 28),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16, right: 16, bottom: 100,
        ),
        children: [
          // Header
          Row(children: [
            const Text('🚀', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Text('Goals & Projects', style: TextStyle(
              color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (_archived.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _showArchived = !_showArchived),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  backgroundColor: c.surfaceHigh,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(_showArchived ? 'Hide done' : '${_archived.length} done',
                  style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ),
          ]),
          const SizedBox(height: 16),

          if (_active.isEmpty && _archived.isEmpty)
            _EmptyState(onAdd: () => _openProjectSheet())
          else ...[
            ..._active.map((p) => _ProjectSection(
                  project: p,
                  onUpdate: () async { await _s.updateProject(p); _load(); },
                  onArchive: () async { await _s.archiveProject(p.id); _load(); },
                  onEdit: () => _openProjectSheet(p),
                )),
            if (_showArchived && _archived.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('COMPLETED', style: TextStyle(
                color: c.textDisabled, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              ..._archived.map((p) => _ArchivedTile(
                    project: p,
                    onUnarchive: () async { await _s.unarchiveProject(p.id); _load(); },
                    onDelete: () async { await _s.deleteProject(p.id); _load(); },
                  )),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── Project section ──────────────────────────────────────────────────────────

class _ProjectSection extends StatefulWidget {
  final ProjectModel project;
  final VoidCallback onUpdate;
  final VoidCallback onArchive;
  final VoidCallback onEdit;

  const _ProjectSection({
    required this.project,
    required this.onUpdate,
    required this.onArchive,
    required this.onEdit,
  });

  @override
  State<_ProjectSection> createState() => _ProjectSectionState();
}

class _ProjectSectionState extends State<_ProjectSection> {
  bool _expanded = true;

  void _addTaskGroup(String label) {
    final s = StorageService.instance;
    widget.project.tasks.add(TaskGroup(id: s.newId(), label: label));
    widget.onUpdate();
  }

  void _showAddGroupSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = appColors(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('New task group', style: TextStyle(
                color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Pension, Bank, Apartment…',
                  hintStyle: TextStyle(color: c.textDisabled),
                  filled: true, fillColor: c.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) { _addTaskGroup(v.trim()); Navigator.pop(ctx); }
                },
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (ctrl.text.trim().isNotEmpty) {
                      _addTaskGroup(ctrl.text.trim()); Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white,
                    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Add group', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final p = widget.project;
    final complete = p.isComplete;
    const orange = Color(0xFFFF6B35);
    const green  = Color(0xFF00C48C);
    final stripeColor = complete ? green : orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: complete ? green.withValues(alpha: 0.4) : c.border),
        boxShadow: [
          BoxShadow(color: stripeColor.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(children: [

          // ── Project header ─────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            onLongPress: widget.onEdit,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [stripeColor.withValues(alpha: 0.12), stripeColor.withValues(alpha: 0.04)],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
              ),
              child: Row(children: [
                Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: stripeColor, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: TextStyle(
                    color: complete ? green : c.textPrimary,
                    fontSize: 18, fontWeight: FontWeight.w800,
                  )),
                  Text('${p.tasks.length} task group${p.tasks.length == 1 ? '' : 's'}',
                    style: TextStyle(color: c.textSecondary, fontSize: 12)),
                ])),
                const SizedBox(width: 12),
                // Overall progress chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: stripeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (complete) ...[
                      const Icon(Icons.check_circle_rounded, size: 13, color: green),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      p.totalSubtasks == 0 ? '—' : '${p.doneSubtasks}/${p.totalSubtasks}',
                      style: TextStyle(
                        color: stripeColor, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: c.textDisabled, size: 20),
              ]),
            ),
          ),

          // Overall progress bar
          if (p.totalSubtasks > 0)
            LinearProgressIndicator(
              value: p.progress, minHeight: 3,
              backgroundColor: stripeColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(stripeColor),
            ),

          // ── Task groups ────────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: _expanded
                ? Column(children: [
                    ...p.tasks.asMap().entries.map((entry) {
                      final idx   = entry.key;
                      final group = entry.value;
                      return _TaskGroupCard(
                        group: group,
                        color: _groupColor(idx),
                        onToggleSubtask: (sub) {
                          sub.done = !sub.done;
                          HapticFeedback.selectionClick();
                          widget.onUpdate();
                        },
                        onAddSubtask: (label) {
                          group.subtasks.add(SubTaskModel(
                            id: StorageService.instance.newId(), label: label));
                          widget.onUpdate();
                        },
                        onDeleteSubtask: (sub) {
                          group.subtasks.removeWhere((s) => s.id == sub.id);
                          widget.onUpdate();
                        },
                        onDeleteGroup: () {
                          p.tasks.removeWhere((t) => t.id == group.id);
                          widget.onUpdate();
                          setState(() {});
                        },
                      );
                    }),

                    // + Add task group
                    InkWell(
                      onTap: _showAddGroupSheet,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Row(children: [
                          Icon(Icons.add_circle_outline_rounded,
                              color: c.textDisabled, size: 18),
                          const SizedBox(width: 8),
                          Text('Add task group',
                            style: TextStyle(color: c.textDisabled, fontSize: 13)),
                        ]),
                      ),
                    ),
                  ])
                : const SizedBox.shrink(),
          ),

          // Archive button when all done
          if (complete && _expanded)
            GestureDetector(
              onTap: widget.onArchive,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: green.withValues(alpha: 0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded, color: green, size: 16),
                  SizedBox(width: 6),
                  Text('All done — archive this project',
                    style: TextStyle(color: green, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

// ─── Task group card ──────────────────────────────────────────────────────────

class _TaskGroupCard extends StatefulWidget {
  final TaskGroup group;
  final Color color;
  final void Function(SubTaskModel) onToggleSubtask;
  final void Function(String) onAddSubtask;
  final void Function(SubTaskModel) onDeleteSubtask;
  final VoidCallback onDeleteGroup;

  const _TaskGroupCard({
    required this.group, required this.color,
    required this.onToggleSubtask, required this.onAddSubtask,
    required this.onDeleteSubtask, required this.onDeleteGroup,
  });

  @override
  State<_TaskGroupCard> createState() => _TaskGroupCardState();
}

class _TaskGroupCardState extends State<_TaskGroupCard> {
  bool _expanded = true;
  bool _showAdd  = false;
  final _addCtrl = TextEditingController();

  @override
  void dispose() { _addCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final g = widget.group;
    final col = widget.color;
    final complete = g.isComplete;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: complete ? col.withValues(alpha: 0.4) : c.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Left colored stripe
            Container(
              width: 4,
              color: complete ? col : col.withValues(alpha: 0.6),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Group header
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  onLongPress: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Delete "${g.label}"?'),
                        content: const Text('This will remove the group and all its tasks.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) widget.onDeleteGroup();
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: complete ? 0.07 : 0.04),
                    ),
                    child: Row(children: [
                      Container(width: 7, height: 7,
                        decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(g.label, style: TextStyle(
                          color: complete ? col : c.textPrimary,
                          fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('${g.subtasks.length} task${g.subtasks.length == 1 ? '' : 's'}',
                          style: TextStyle(color: c.textSecondary, fontSize: 10)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (complete) ...[
                            Icon(Icons.check_circle_rounded, size: 10, color: col),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            g.subtasks.isEmpty ? '—' : '${g.doneCount}/${g.subtasks.length}',
                            style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      const SizedBox(width: 4),
                      Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: c.textDisabled, size: 16),
                    ]),
                  ),
                ),

                // Subtask rows
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: _expanded && g.subtasks.isNotEmpty
                      ? Column(children: [
                          Divider(height: 1, color: c.border),
                          ...g.subtasks.map((sub) => Dismissible(
                                key: ValueKey(sub.id),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => widget.onDeleteSubtask(sub),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  color: Colors.red.withValues(alpha: 0.08),
                                  child: const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                                ),
                                child: _SubtaskRow(
                                  sub: sub, accentColor: col,
                                  onToggle: () => setState(() => widget.onToggleSubtask(sub)),
                                ),
                              )),
                        ])
                      : const SizedBox.shrink(),
                ),

                // Add subtask row
                if (_expanded) ...[
                  Divider(height: 1, color: c.border),
                  if (_showAdd)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _addCtrl,
                            autofocus: true,
                            style: TextStyle(color: c.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Add a task…',
                              hintStyle: TextStyle(color: c.textDisabled),
                              border: InputBorder.none,
                              isDense: true, contentPadding: EdgeInsets.zero,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (v) {
                              if (v.trim().isNotEmpty) widget.onAddSubtask(v.trim());
                              _addCtrl.clear();
                              setState(() => _showAdd = false);
                            },
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (_addCtrl.text.trim().isNotEmpty) {
                                widget.onAddSubtask(_addCtrl.text.trim());
                              }
                              _addCtrl.clear();
                              setState(() => _showAdd = false);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.check_rounded, color: col, size: 20),
                            ),
                          ),
                        ),
                      ]),
                    )
                  else
                    InkWell(
                      onTap: () => setState(() => _showAdd = true),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Row(children: [
                          Icon(Icons.add_rounded, color: col.withValues(alpha: 0.6), size: 16),
                          const SizedBox(width: 8),
                          Text('Add task', style: TextStyle(
                            color: col.withValues(alpha: 0.6), fontSize: 13,
                            fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ),
                ],

              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Subtask row — matches HabitTile exactly ──────────────────────────────────

class _SubtaskRow extends StatelessWidget {
  final SubTaskModel sub;
  final Color accentColor;
  final VoidCallback onToggle;
  const _SubtaskRow({required this.sub, required this.accentColor, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () { HapticFeedback.lightImpact(); onToggle(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: sub.done ? accentColor.withValues(alpha: 0.07) : Colors.transparent,
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: sub.done ? accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: sub.done ? accentColor : c.border, width: 1.5),
              ),
              child: sub.done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(sub.label, style: TextStyle(
              color: sub.done ? c.textSecondary : c.textPrimary,
              fontSize: 14, fontWeight: FontWeight.w500,
              decoration: sub.done ? TextDecoration.lineThrough : null,
              decorationColor: c.textSecondary,
            ))),
          ]),
        ),
      ),
    );
  }
}

// ─── Archived tile ────────────────────────────────────────────────────────────

class _ArchivedTile extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback onUnarchive;
  final VoidCallback onDelete;
  const _ArchivedTile({required this.project, required this.onUnarchive, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF00C48C), size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(project.name, style: TextStyle(
          color: c.textSecondary, fontSize: 14,
          decoration: TextDecoration.lineThrough, decorationColor: c.textSecondary,
        ))),
        TextButton(onPressed: onUnarchive,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
          child: Text('Reopen', style: TextStyle(color: c.accent, fontSize: 12))),
        const SizedBox(width: 4),
        GestureDetector(onTap: onDelete,
          child: const Icon(Icons.delete_outline, color: Colors.red, size: 18)),
      ]),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 60),
      const Text('🚀', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 14),
      Text('No projects yet', style: TextStyle(
        color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Tap + to add your first goal', style: TextStyle(color: c.textSecondary, fontSize: 14)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('New project'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]));
  }
}

// ─── Create / rename project sheet ───────────────────────────────────────────

class _ProjectSheet extends StatefulWidget {
  final ProjectModel? editing;
  final void Function(ProjectModel) onSave;
  final VoidCallback? onDelete;
  const _ProjectSheet({this.editing, required this.onSave, this.onDelete});

  @override
  State<_ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends State<_ProjectSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.editing?.name ?? '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _save() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    widget.onSave(ProjectModel(
      id: widget.editing?.id ?? StorageService.instance.newId(),
      name: name,
      tasks: widget.editing?.tasks ?? [],
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(isEdit ? 'Rename project' : 'New project',
            style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl, autofocus: true,
            style: TextStyle(color: c.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Project name',
              hintStyle: TextStyle(color: c.textDisabled),
              filled: true, fillColor: c.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 6),
          Text('Add task groups inside the project after creating.',
            style: TextStyle(color: c.textDisabled, fontSize: 12)),
          const SizedBox(height: 20),
          Row(children: [
            if (isEdit && widget.onDelete != null)
              TextButton(
                onPressed: () { widget.onDelete!(); Navigator.pop(context); },
                child: const Text('Delete project', style: TextStyle(color: Colors.red))),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isEdit ? 'Rename' : 'Create',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      ),
    );
  }
}
