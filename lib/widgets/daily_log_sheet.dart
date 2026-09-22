import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'plan_inputs.dart';

const kTrainingTypes = ['strength', 'rehab', 'cycle', 'walk', 'hike', 'boxing'];
const kInitiationTypes = ['stranger', 'peer', 'follow-up'];

class DailyLogSheet extends StatefulWidget {
  final String date;
  final VoidCallback onSaved;
  const DailyLogSheet({super.key, required this.date, required this.onSaved});

  @override
  State<DailyLogSheet> createState() => _DailyLogSheetState();
}

class _DailyLogSheetState extends State<DailyLogSheet> {
  final _s = StorageService.instance;
  late DailyLogModel _log;
  late final bool _ruminationFieldActive;
  late final TextEditingController _predictionCtrl;
  late final TextEditingController _outcomeCtrl;
  late final TextEditingController _ruminationNoteCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _log = _s.getDailyLog(widget.date);
    _ruminationFieldActive = _s.isRuminationFieldActive(widget.date);
    _predictionCtrl = TextEditingController(text: _log.prediction);
    _outcomeCtrl = TextEditingController(text: _log.outcome);
    _ruminationNoteCtrl = TextEditingController(text: _log.ruminationPostponementNote);
    _notesCtrl = TextEditingController(text: _log.notes);
  }

  @override
  void dispose() {
    _predictionCtrl.dispose();
    _outcomeCtrl.dispose();
    _ruminationNoteCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _log.prediction = _predictionCtrl.text.trim();
    _log.outcome = _outcomeCtrl.text.trim();
    _log.ruminationPostponementNote = _ruminationNoteCtrl.text.trim();
    _log.notes = _notesCtrl.text.trim();
    await _s.saveDailyLog(_log);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return PlanSheetScaffold(
      title: 'Daily log — ${widget.date}',
      onSave: _save,
      children: [
        const PlanSectionLabel('Body'),
        PlanNumberStepper(
          label: 'Training minutes', value: _log.trainingMin, max: 240, step: 5,
          onChanged: (v) => setState(() => _log.trainingMin = v),
        ),
        const SizedBox(height: 6),
        Text('Type', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        PlanChips(
          options: kTrainingTypes,
          selected: _log.trainingType,
          onChanged: (v) => setState(() => _log.trainingType = v),
        ),
        PlanSlider(
          label: 'Knee pain', value: _log.kneePain, max: 10,
          color: const Color(0xFFFF6B35),
          onChanged: (v) => setState(() => _log.kneePain = v),
        ),
        PlanToggle(
          label: 'Knee swelling', value: _log.kneeSwelling,
          color: const Color(0xFFFF6B35),
          onChanged: (v) => setState(() => _log.kneeSwelling = v),
        ),

        const PlanSectionLabel('Stability'),
        PlanNumberStepper(
          label: 'Meals planned (0–3)', value: _log.mealsPlanned, max: 3,
          onChanged: (v) => setState(() => _log.mealsPlanned = v),
        ),

        const PlanSectionLabel('Presence'),
        PlanNumberStepper(
          label: 'Device-free minutes', value: _log.deviceFreeMin, max: 480, step: 5,
          onChanged: (v) => setState(() => _log.deviceFreeMin = v),
        ),
        PlanNumberStepper(
          label: 'Rumination loops noticed', value: _log.ruminationLoops, max: 50,
          onChanged: (v) => setState(() => _log.ruminationLoops = v),
        ),
        if (_ruminationFieldActive) ...[
          PlanToggle(
            label: 'Rumination postponement used', value: _log.ruminationPostponementUsed,
            color: const Color(0xFF7C6EFF),
            onChanged: (v) => setState(() => _log.ruminationPostponementUsed = v),
          ),
          if (_log.ruminationPostponementUsed)
            PlanTextField(label: 'What the loop was about', hint: '…', controller: _ruminationNoteCtrl),
        ],

        const PlanSectionLabel('Social'),
        PlanToggle(
          label: 'Social initiation', value: _log.socialInitiation,
          onChanged: (v) => setState(() => _log.socialInitiation = v),
        ),
        if (_log.socialInitiation) ...[
          const SizedBox(height: 6),
          PlanChips(
            options: kInitiationTypes,
            selected: _log.initiationType,
            onChanged: (v) => setState(() => _log.initiationType = v),
          ),
          PlanTextField(label: 'Prediction', hint: 'What I predict happens…', controller: _predictionCtrl),
          PlanSlider(
            label: 'Predicted confidence', value: _log.predictedConfidence, max: 100,
            color: const Color(0xFF00BFFF),
            valueLabel: (v) => '$v%',
            onChanged: (v) => setState(() => _log.predictedConfidence = v),
          ),
          PlanTextField(label: 'Outcome', hint: 'What happened…', controller: _outcomeCtrl),
          Row(children: [
            Expanded(child: Text('Prediction correct?',
              style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w500))),
            PlanChips(
              options: const ['yes', 'no'],
              selected: _log.predictionCorrect == null ? null : (_log.predictionCorrect! ? 'yes' : 'no'),
              onChanged: (v) => setState(() => _log.predictionCorrect = v == null ? null : v == 'yes'),
            ),
          ]),
        ],

        const PlanSectionLabel('Evening'),
        PlanSlider(
          label: 'Mood (0 = not logged)', value: _log.mood, max: 10,
          color: const Color(0xFF7C6EFF),
          onChanged: (v) => setState(() => _log.mood = v),
        ),
        PlanTextField(label: 'Notes', hint: 'Anything else…', controller: _notesCtrl, maxLines: 3),
      ],
    );
  }
}
