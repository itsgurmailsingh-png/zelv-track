import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final _s = StorageService.instance;

  late List<HabitModel> _habits;
  late Map<String, Map<String, bool>> _heatData;
  late List<String> _dates7;
  late List<double> _weekScores;
  late int _streak;
  late Map<String, double> _rates;

  @override
  void initState() { super.initState(); _load(); }

  void _load() {
    _habits     = _s.getHabits();
    _heatData   = _s.getHeatmapData(days: 7);
    _weekScores = _s.getWeeklyScores(days: 7);
    _streak     = _s.getCurrentStreak();
    _rates      = _s.getHabitRates(days: 7);
    _dates7     = List.generate(7, (i) => DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(Duration(days: 6 - i))));
    setState(() {});
  }

  double get _todayPct => _s.getTodayProgress();
  double get _weekAvg  => _weekScores.isEmpty ? 0 : _weekScores.reduce((a,b)=>a+b) / _weekScores.length;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        color: c.accent,
        child: ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16, right: 16, bottom: 80,
          ),
          children: [

            // ── Header ────────────────────────────────────────────────────────
            Row(children: [
              const Text('📊', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Text('Stats', style: TextStyle(
                color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 16),

            // ── Stat cards row ────────────────────────────────────────────────
            Row(children: [
              _StatCard(
                icon: Icons.today_rounded,
                iconColor: const Color(0xFF7C6EFF),
                label: 'Today',
                value: '${(_todayPct * 100).round()}%',
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFFF6B35),
                label: 'Streak',
                value: '$_streak d',
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.bar_chart_rounded,
                iconColor: c.accent,
                label: '7-day avg',
                value: '${(_weekAvg * 100).round()}%',
              ),
            ]),

            const SizedBox(height: 24),

            // ── 7-day bar chart ───────────────────────────────────────────────
            _SectionHeader(label: 'LAST 7 DAYS', icon: Icons.bar_chart_rounded, color: c.accent),
            const SizedBox(height: 10),
            _WeekBars(scores: _weekScores, dates: _dates7),

            const SizedBox(height: 24),

            // ── Heatmap ───────────────────────────────────────────────────────
            _SectionHeader(label: 'HABIT MAP', icon: Icons.grid_view_rounded, color: const Color(0xFF7C6EFF)),
            const SizedBox(height: 10),
            _Heatmap(habits: _habits, dates: _dates7, data: _heatData),

            const SizedBox(height: 24),

            // ── Top habits ────────────────────────────────────────────────────
            _SectionHeader(label: 'HABIT RATES (7 DAYS)', icon: Icons.emoji_events_rounded, color: const Color(0xFFFFB800)),
            const SizedBox(height: 10),
            _HabitRates(habits: _habits, rates: _rates),

          ],
        ),
      ),
    );
  }
}

// ─── Stat card (Zelv style) ───────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon, required this.iconColor,
    required this.label, required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(
            color: iconColor, fontSize: 22, fontWeight: FontWeight.w800,
          )),
          Text(label, style: TextStyle(
            color: iconColor.withValues(alpha: 0.75), fontSize: 11,
            fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(
        color: color, fontSize: 11,
        fontWeight: FontWeight.w800, letterSpacing: 1.4,
      )),
    ]);
  }
}

// ─── 7-day bar chart (improved) ───────────────────────────────────────────────

class _WeekBars extends StatelessWidget {
  final List<double> scores;
  final List<String> dates;
  const _WeekBars({required this.scores, required this.dates});

  Color _barColor(double pct) {
    if (pct >= 0.8) return const Color(0xFF00C48C);
    if (pct >= 0.5) return const Color(0xFFFFB800);
    return const Color(0xFFFF6B35);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: SizedBox(
        height: 110,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(scores.length, (i) {
            final isToday = dates[i] == today;
            final pct    = scores[i];
            final color  = isToday ? c.accent : _barColor(pct);
            final dayLabel = DateFormat('EEE').format(DateTime.parse(dates[i]));
            final pctLabel = '${(pct * 100).round()}%';

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (pct > 0)
                      Text(pctLabel, style: TextStyle(
                        color: color, fontSize: 9, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      height: (72 * pct).clamp(4.0, 72.0),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isToday ? 1 : 0.65),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: isToday ? [
                          BoxShadow(color: color.withValues(alpha: 0.3),
                              blurRadius: 8, offset: const Offset(0, 2)),
                        ] : [],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(dayLabel.substring(0, 1), style: TextStyle(
                      color: isToday ? color : c.textDisabled,
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w400,
                    )),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Habit heatmap ────────────────────────────────────────────────────────────

class _Heatmap extends StatelessWidget {
  final List<HabitModel> habits;
  final List<String> dates;
  final Map<String, Map<String, bool>> data;

  const _Heatmap({required this.habits, required this.dates, required this.data});

  // Each block gets its own color for heatmap cells
  Color _blockColor(String blockId) {
    switch (blockId) {
      case 'morning':   return const Color(0xFFFFB800);
      case 'lab':       return const Color(0xFF00BFFF);
      case 'midday':    return const Color(0xFF00C48C);
      case 'afternoon': return const Color(0xFF7C6EFF);
      case 'evening':   return const Color(0xFFFF6B35);
      case 'night':     return const Color(0xFF5C6EFF);
      default:          return const Color(0xFF888888);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    const cellSize = 18.0;
    const gap = 3.0;
    const labelW = 100.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header row
          Row(children: [
            const SizedBox(width: labelW),
            ...dates.map((d) {
              final isToday = d == today;
              return SizedBox(
                width: cellSize + gap,
                child: Text(
                  DateFormat('E').format(DateTime.parse(d)).substring(0, 1),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isToday ? c.accent : c.textDisabled,
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              );
            }),
          ]),
          const SizedBox(height: 6),

          // Habit rows
          ...habits.map((h) {
            final blockColor = _blockColor(h.blockId);
            return Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: Row(children: [
                SizedBox(
                  width: labelW,
                  child: Text(h.label,
                    style: TextStyle(color: c.textSecondary, fontSize: 9),
                    overflow: TextOverflow.ellipsis, maxLines: 1,
                  ),
                ),
                ...dates.map((d) {
                  final done = data[d]?[h.id] ?? false;
                  final isToday = d == today;
                  return Container(
                    width: cellSize,
                    height: cellSize,
                    margin: const EdgeInsets.only(right: gap),
                    decoration: BoxDecoration(
                      color: done
                          ? (h.isNonNeg ? AppColors.warn : blockColor)
                          : c.surfaceHigh,
                      borderRadius: BorderRadius.circular(4),
                      border: isToday
                          ? Border.all(color: c.accent.withValues(alpha: 0.5), width: 1)
                          : null,
                      boxShadow: done ? [
                        BoxShadow(
                          color: (h.isNonNeg ? AppColors.warn : blockColor).withValues(alpha: 0.25),
                          blurRadius: 3,
                        ),
                      ] : [],
                    ),
                  );
                }),
              ]),
            );
          }),

          const SizedBox(height: 10),
          // Legend
          Wrap(spacing: 12, runSpacing: 4, children: [
            _LegendDot(color: c.surfaceHigh, label: 'Missed'),
            _LegendDot(color: const Color(0xFF00BFFF), label: 'Lab habit'),
            _LegendDot(color: const Color(0xFFFFB800), label: 'Morning'),
            _LegendDot(color: AppColors.warn, label: 'Must-do'),
          ]),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: c.textDisabled, fontSize: 9)),
    ]);
  }
}

// ─── Habit rates (Zelv style rows) ───────────────────────────────────────────

class _HabitRates extends StatelessWidget {
  final List<HabitModel> habits;
  final Map<String, double> rates;
  const _HabitRates({required this.habits, required this.rates});

  Color _rateColor(double rate) {
    if (rate >= 0.8) return const Color(0xFF00C48C);
    if (rate >= 0.5) return const Color(0xFFFFB800);
    return const Color(0xFFFF6B35);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final sorted = [...habits]
      ..sort((a, b) => (rates[b.id] ?? 0).compareTo(rates[a.id] ?? 0));
    final top = sorted.take(10).toList();

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: top.asMap().entries.map((entry) {
          final i   = entry.key;
          final h   = entry.value;
          final rate = rates[h.id] ?? 0;
          final pct = (rate * 100).round();
          final color = _rateColor(rate);

          return Column(children: [
            if (i > 0) Divider(height: 1, color: c.border),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(i == 0 ? 13 : 0),
              ),
              child: Row(children: [
                // Rank
                SizedBox(
                  width: 20,
                  child: Text('${i + 1}', style: TextStyle(
                    color: c.textDisabled, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                // Label
                Expanded(
                  child: Text(h.label,
                    style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                // Bar
                SizedBox(
                  width: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: rate, minHeight: 6,
                      backgroundColor: c.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Pct badge
                Container(
                  width: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$pct%', style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                ),
              ]),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}
