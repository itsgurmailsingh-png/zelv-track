import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/daily_log_sheet.dart';
import '../widgets/weekly_review_sheet.dart';
import '../widgets/scale_measurement_sheet.dart';
import '../widgets/progress_ring.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _s = StorageService.instance;

  late DailyLogModel _today;
  late List<DailyLogModel> _history7;
  late String _weekOf;
  late double _mvdWeekly;
  late double _predictionAccuracy;
  late double _brierScore;
  late List<({String date, int kneePain, int trainingMin})> _kneeLoad;
  late List<ScaleMeasurementModel> _scales;
  late List<ReportModel> _reports;
  double? _wellbeing;
  String? _planStartDate;
  late PlanPhaseInfo _phaseInfo;
  late CheckpointStatus _checkpoint;
  bool _uploading = false;

  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() { super.initState(); _load(); }

  void _load() {
    _today = _s.getDailyLog(_todayStr);
    _history7 = _s.getDailyLogs(days: 7).reversed.toList();
    _weekOf = _s.weekOfFor(DateTime.now());
    _mvdWeekly = _s.getMvdWeeklyPercent(weekOf: _weekOf);
    _predictionAccuracy = _s.getPredictionAccuracy(days: 30);
    _brierScore = _s.getBrierScore(weeks: 12);
    _kneeLoad = _s.getKneeLoadSeries(days: 14);
    _scales = _s.getScaleMeasurements();
    _reports = _s.getReports();
    _wellbeing = _s.getWellbeingScore();
    _planStartDate = _s.getPlanStartDate();
    _phaseInfo = _s.getCurrentPhaseInfo();
    _checkpoint = _s.getCheckpointStatus();
    setState(() {});
  }

  Future<void> _setPlanStartDate() async {
    final initial = _planStartDate != null ? DateTime.parse(_planStartDate!) : DateTime.now();
    final picked = await showDatePicker(
      context: context, initialDate: initial,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
    );
    if (picked != null) {
      await _s.setPlanStartDate(DateFormat('yyyy-MM-dd').format(picked));
      _load();
    }
  }

  void _openDailySheet(String date) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => DailyLogSheet(date: date, onSaved: _load),
    );
  }

  void _openWeeklySheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => WeeklyReviewSheet(weekOf: _weekOf, onSaved: _load),
    );
  }

  void _openScaleSheet(String date, String type) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ScaleMeasurementSheet(date: date, type: type, onSaved: _load),
    );
  }

  Future<void> _uploadReport() async {
    final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
    if (picked?.path == null) return;

    setState(() => _uploading = true);
    try {
      final document = await PdfDocument.openFile(picked!.path!);
      final buffer = StringBuffer();
      for (final page in document.pages) {
        final pageText = await page.loadStructuredText();
        buffer.writeln(pageText.fullText);
      }
      await document.dispose();
      final text = buffer.toString();

      await _s.addReport(ReportModel(
        id: _s.newId(),
        title: picked.name,
        filename: picked.name,
        uploadedAt: _todayStr,
        extractedText: text,
      ));
      _load();

      final detected = detectScaleScores(text);
      if (detected.isNotEmpty && mounted) await _offerPrefill(detected);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read that PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _offerPrefill(Map<String, int> detected) async {
    const labels = {'pss10': 'PSS-10', 'ucla': 'UCLA', 'ptq': 'PTQ', 'spin': 'SPIN'};
    final c = appColors(context);
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Detected scores', style: TextStyle(color: c.textPrimary)),
        content: Text(
          detected.entries.map((e) => '${labels[e.key]}: ${e.value}').join('\n'),
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Dismiss')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply to today')),
        ],
      ),
    );
    if (apply != true) return;
    final existing = _scales.where((m) => m.date == _todayStr).isEmpty
        ? ScaleMeasurementModel(date: _todayStr)
        : _scales.firstWhere((m) => m.date == _todayStr);
    await _s.saveScaleMeasurement(ScaleMeasurementModel(
      date: _todayStr,
      type: existing.type,
      pss10: detected['pss10'] ?? existing.pss10,
      ucla: detected['ucla'] ?? existing.ucla,
      ptq: detected['ptq'] ?? existing.ptq,
      spin: detected['spin'] ?? existing.spin,
      rhr: existing.rhr, sleepAvg: existing.sleepAvg,
      screenAvg: existing.screenAvg, weight: existing.weight,
      soiRBehavior: existing.soiRBehavior, soiRAttitude: existing.soiRAttitude,
      soiRDesire: existing.soiRDesire,
    ));
    _load();
  }

  void _viewReport(ReportModel r) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _ReportViewSheet(report: r, onDeleted: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        color: c.accent,
        child: ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16, left: 16, right: 16, bottom: 80,
          ),
          children: [
            Row(children: [
              const Text('🧭', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Text('Plan', style: TextStyle(color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 16),

            _PhaseHeroCard(
              info: _phaseInfo, wellbeing: _wellbeing,
              planStartDate: _planStartDate, onSetStartDate: _setPlanStartDate,
            ),

            if (_checkpoint.week4Due || _checkpoint.week4Done) ...[
              const SizedBox(height: 12),
              _CheckpointBanner(
                week: 4, due: _checkpoint.week4Due, done: _checkpoint.week4Done,
                ptqDelta: _checkpoint.week4PtqDelta, spinDelta: _checkpoint.week4SpinDelta,
                pss10Delta: _checkpoint.week4Pss10Delta, allImproved: _checkpoint.week4AllImproved,
                onLogNow: () => _openScaleSheet(_todayStr, 'checkpoint'),
              ),
            ],
            if (_checkpoint.week8Triggered && (_checkpoint.week8Due || _checkpoint.week8Done)) ...[
              const SizedBox(height: 12),
              _CheckpointBanner(
                week: 8, due: _checkpoint.week8Due, done: _checkpoint.week8Done,
                onLogNow: () => _openScaleSheet(_todayStr, 'checkpoint'),
              ),
            ],

            const SizedBox(height: 16),

            // ── Today ────────────────────────────────────────────────────────
            _SectionHeader(label: 'TODAY', icon: Icons.today_rounded, color: const Color(0xFF00E5A0)),
            const SizedBox(height: 10),
            _TodayCard(log: _today, mvdPct: _s.mvdPercentForDate(_today), onTap: () => _openDailySheet(_todayStr)),
            const SizedBox(height: 10),
            _HistoryRow(logs: _history7, today: _todayStr, storage: _s, onTapDate: _openDailySheet),

            const SizedBox(height: 24),

            // ── This week ────────────────────────────────────────────────────
            _SectionHeader(label: 'THIS WEEK', icon: Icons.calendar_view_week_rounded, color: const Color(0xFF7C6EFF)),
            const SizedBox(height: 10),
            Row(children: [
              _StatCard(icon: Icons.checklist_rounded, iconColor: const Color(0xFF00C48C),
                label: 'MVD %', value: '${(_mvdWeekly * 100).round()}%'),
              const SizedBox(width: 10),
              _StatCard(icon: Icons.psychology_rounded, iconColor: const Color(0xFF00BFFF),
                label: 'Prediction accuracy', value: '${(_predictionAccuracy * 100).round()}%'),
              const SizedBox(width: 10),
              _StatCard(icon: Icons.rule_rounded, iconColor: const Color(0xFFFFB800),
                label: 'Brier score', value: _brierScore.toStringAsFixed(2)),
            ]),
            const SizedBox(height: 10),
            _ActionButton(label: 'Weekly review — week of $_weekOf', icon: Icons.rate_review_rounded,
              color: const Color(0xFF7C6EFF), onTap: _openWeeklySheet),

            const SizedBox(height: 24),

            // ── Measurements ─────────────────────────────────────────────────
            _SectionHeader(label: 'MEASUREMENTS', icon: Icons.monitor_heart_rounded, color: const Color(0xFFFF6B35)),
            const SizedBox(height: 10),
            if (_scales.isEmpty)
              _EmptyHint(text: 'No baseline yet — add week 1, week 6, week 12 checkpoints.')
            else
              _ScaleTable(scales: _scales, onTapRow: (m) => _openScaleSheet(m.date, m.type)),
            const SizedBox(height: 10),
            _ActionButton(label: 'Add measurement', icon: Icons.add_chart_rounded,
              color: const Color(0xFFFF6B35), onTap: () => _openScaleSheet(_todayStr, 'baseline')),

            const SizedBox(height: 24),

            // ── Load ──────────────────────────────────────────────────────────
            _SectionHeader(label: 'KNEE LOAD (14 DAYS)', icon: Icons.timeline_rounded, color: const Color(0xFFFF4D6D)),
            const SizedBox(height: 10),
            _KneeLoadChart(series: _kneeLoad),

            const SizedBox(height: 24),

            // ── Reports ───────────────────────────────────────────────────────
            _SectionHeader(label: 'REPORTS', icon: Icons.description_rounded, color: const Color(0xFF00BFFF)),
            const SizedBox(height: 10),
            _ActionButton(
              label: _uploading ? 'Reading PDF…' : 'Upload PDF report',
              icon: Icons.upload_file_rounded, color: const Color(0xFF00BFFF),
              onTap: _uploading ? null : _uploadReport,
            ),
            const SizedBox(height: 10),
            if (_reports.isEmpty)
              _EmptyHint(text: 'Upload questionnaire exports, physio notes, or lab PDFs — text stays on this device.')
            else
              ..._reports.map((r) => _ReportTile(report: r, onTap: () => _viewReport(r))),
          ],
        ),
      ),
    );
  }
}

// ─── Phase hero card ─────────────────────────────────────────────────────────

class _PhaseHeroCard extends StatelessWidget {
  final PlanPhaseInfo info;
  final double? wellbeing;
  final String? planStartDate;
  final VoidCallback onSetStartDate;
  const _PhaseHeroCard({required this.info, required this.wellbeing, required this.planStartDate, required this.onSetStartDate});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);

    if (planStartDate == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.accent.withValues(alpha: 0.18), c.accent.withValues(alpha: 0.04)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.accent.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.flag_circle_rounded, color: c.accent, size: 28),
          const SizedBox(height: 10),
          Text('Set Week 1, Day 1', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Anchors the phase, ladder, and checkpoint reminders to your actual calendar.',
            style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onSetStartDate,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent, foregroundColor: Colors.black, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Set start date', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      );
    }

    final week = info.currentWeek!.clamp(1, 12);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.accent.withValues(alpha: 0.14), c.surface],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProgressRing(progress: week / 12, size: 84, strokeWidth: 8, label: 'WEEK', centerText: '$week/12'),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: onSetStartDate,
                child: Text(info.phaseName!, style: TextStyle(color: c.textPrimary, fontSize: 19, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 4),
              Text(info.phaseTheme!, style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        _StatusRow(icon: Icons.stairs_rounded, active: true, text: info.rungStatus!, color: const Color(0xFF00E5A0)),
        const SizedBox(height: 8),
        _StatusRow(icon: Icons.bolt_rounded, active: info.stressActive,
          text: 'Stress inoculation: ${info.stressStatus}', color: const Color(0xFFFFB800)),
        const SizedBox(height: 8),
        _StatusRow(icon: Icons.menu_book_rounded, active: true, text: info.reading.join(' · '), color: const Color(0xFF00BFFF)),
        if (wellbeing != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.favorite_rounded, color: c.accent, size: 16),
              const SizedBox(width: 8),
              Text('Wellbeing ${wellbeing!.round()}/100', style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String text;
  final Color color;
  const _StatusRow({required this.icon, required this.active, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: active ? color : c.textDisabled),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
        style: TextStyle(color: active ? c.textPrimary : c.textDisabled, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4))),
    ]);
  }
}

// ─── Checkpoint banner ────────────────────────────────────────────────────────

class _CheckpointBanner extends StatelessWidget {
  final int week; // 4 or 8
  final bool due;
  final bool done;
  final double? ptqDelta;
  final double? spinDelta;
  final double? pss10Delta;
  final bool? allImproved;
  final VoidCallback onLogNow;

  const _CheckpointBanner({
    required this.week, required this.due, required this.done,
    this.ptqDelta, this.spinDelta, this.pss10Delta, this.allImproved,
    required this.onLogNow,
  });

  String _fmtDelta(double d) => '${d >= 0 ? '-' : '+'}${d.abs().round()}%';

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);

    if (due) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB800).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.notifications_active_rounded, color: Color(0xFFFFB800), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('Week $week checkpoint due — retest PTQ / SPIN / PSS-10',
            style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700))),
          TextButton(onPressed: onLogNow, child: const Text('Log now')),
        ]),
      );
    }

    if (week == 4 && done) {
      final hasDeltas = ptqDelta != null && spinDelta != null && pss10Delta != null;
      final movedCount = hasDeltas
          ? [ptqDelta! >= 20, spinDelta! >= 20, pss10Delta! >= 20].where((b) => b).length
          : 0;
      final verdictColor = allImproved == true ? const Color(0xFF00C48C)
          : allImproved == false ? const Color(0xFFFFB800) : c.textSecondary;
      final verdict = !hasDeltas
          ? 'Logged — add a Week 1 baseline to compute deltas.'
          : allImproved == true
              ? 'All three improved ≥20% — continue solo, advance to Rung 2.'
              : movedCount > 0
                  ? 'Partial improvement — continue solo, flagged for Week 8 retest.'
                  : 'None moved meaningfully — start therapist search. Tracker continues as adjunct.';
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: verdictColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: verdictColor.withValues(alpha: 0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WEEK 4 RESULT', style: TextStyle(color: verdictColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          if (hasDeltas)
            Text('PTQ ${_fmtDelta(ptqDelta!)} · SPIN ${_fmtDelta(spinDelta!)} · PSS-10 ${_fmtDelta(pss10Delta!)}',
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(verdict, style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
    }

    if (week == 8 && done) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF00C48C).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF00C48C).withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF00C48C), size: 18),
          const SizedBox(width: 10),
          Text('Week 8 checkpoint logged.', style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
    }

    return const SizedBox.shrink();
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
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
    ]);
  }
}

// ─── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: iconColor, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: iconColor.withValues(alpha: 0.75), fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─── Action button ──────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: enabled ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: enabled ? 0.4 : 0.15)),
        ),
        child: Row(children: [
          Icon(icon, color: color.withValues(alpha: enabled ? 1 : 0.5), size: 18),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color.withValues(alpha: enabled ? 1 : 0.5), fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: TextStyle(color: c.textDisabled, fontSize: 12)),
    );
  }
}

// ─── Today card ─────────────────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  final DailyLogModel log;
  final double mvdPct;
  final VoidCallback onTap;
  const _TodayCard({required this.log, required this.mvdPct, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MVD ${(mvdPct * 100).round()}%', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Training ${log.trainingMin}m · Device-free ${log.deviceFreeMin}m · Mood ${log.mood == 0 ? '—' : log.mood}',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ]),
          ),
          Icon(Icons.edit_rounded, color: c.textDisabled, size: 18),
        ]),
      ),
    );
  }
}

// ─── 7-day history row ───────────────────────────────────────────────────────

class _HistoryRow extends StatelessWidget {
  final List<DailyLogModel> logs;
  final String today;
  final StorageService storage;
  final void Function(String date) onTapDate;
  const _HistoryRow({required this.logs, required this.today, required this.storage, required this.onTapDate});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return SizedBox(
      height: 64,
      child: Row(children: logs.map((log) {
        final pct = storage.mvdPercentForDate(log);
        final isToday = log.date == today;
        return Expanded(
          child: GestureDetector(
            onTap: () => onTapDate(log.date),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isToday ? c.accent.withValues(alpha: 0.15) : c.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
                border: isToday ? Border.all(color: c.accent) : null,
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(DateFormat('E').format(DateTime.parse(log.date)).substring(0, 1),
                  style: TextStyle(color: isToday ? c.accent : c.textDisabled, fontSize: 10, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${(pct * 100).round()}%',
                  style: TextStyle(color: isToday ? c.accent : c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        );
      }).toList()),
    );
  }
}

// ─── Scale checkpoint table ───────────────────────────────────────────────────

class _ScaleTable extends StatelessWidget {
  final List<ScaleMeasurementModel> scales;
  final void Function(ScaleMeasurementModel m) onTapRow;
  const _ScaleTable({required this.scales, required this.onTapRow});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            const SizedBox(width: 36),
            const SizedBox(width: 74),
            Expanded(child: Text('PSS-10', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w700))),
            Expanded(child: Text('UCLA', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w700))),
            Expanded(child: Text('PTQ', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w700))),
            Expanded(child: Text('SPIN', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
        ),
        ...scales.map((m) {
          final isCheckpoint = m.type == 'checkpoint';
          final badgeColor = isCheckpoint ? const Color(0xFFFFB800) : const Color(0xFF7C6EFF);
          return GestureDetector(
            onTap: () => onTapRow(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              child: Row(children: [
                SizedBox(
                  width: 36,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text(isCheckpoint ? 'CP' : 'BL', textAlign: TextAlign.center,
                      style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ),
                SizedBox(width: 74, child: Text(m.date, style: TextStyle(color: c.textPrimary, fontSize: 11, fontWeight: FontWeight.w600))),
                Expanded(child: Text('${m.pss10 ?? '—'}', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12))),
                Expanded(child: Text('${m.ucla ?? '—'}', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12))),
                Expanded(child: Text('${m.ptq ?? '—'}', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12))),
                Expanded(child: Text('${m.spin ?? '—'}', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12))),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ─── Knee load dual bars ───────────────────────────────────────────────────────

class _KneeLoadChart extends StatelessWidget {
  final List<({String date, int kneePain, int trainingMin})> series;
  const _KneeLoadChart({required this.series});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final maxTrain = series.map((e) => e.trainingMin).fold(1, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: SizedBox(
        height: 100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: series.map((e) {
            final trainPct = maxTrain == 0 ? 0.0 : e.trainingMin / maxTrain;
            final painPct = e.kneePain / 10;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    height: (60 * trainPct).clamp(2.0, 60.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFFF).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: (16 * painPct).clamp(1.0, 16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D6D),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Report tile ────────────────────────────────────────────────────────────────

class _ReportTile extends StatelessWidget {
  final ReportModel report;
  final VoidCallback onTap;
  const _ReportTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
        child: Row(children: [
          Icon(Icons.picture_as_pdf_rounded, color: const Color(0xFF00BFFF), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(report.title, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          Text(report.uploadedAt, style: TextStyle(color: c.textDisabled, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _ReportViewSheet extends StatelessWidget {
  final ReportModel report;
  final VoidCallback onDeleted;
  const _ReportViewSheet({required this.report, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(report.title, style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          Text('Uploaded ${report.uploadedAt}', style: TextStyle(color: c.textDisabled, fontSize: 11)),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Text(
                report.extractedText.trim().isEmpty ? '(no text extracted)' : report.extractedText,
                style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Spacer(),
            TextButton(
              onPressed: () async {
                await StorageService.instance.deleteReport(report.id);
                onDeleted();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ]),
        ]),
      ),
    );
  }
}
