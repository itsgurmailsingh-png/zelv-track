import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'plan_inputs.dart';

class WeeklyReviewSheet extends StatefulWidget {
  final String weekOf;
  final VoidCallback onSaved;
  const WeeklyReviewSheet({super.key, required this.weekOf, required this.onSaved});

  @override
  State<WeeklyReviewSheet> createState() => _WeeklyReviewSheetState();
}

class _WeeklyReviewSheetState extends State<WeeklyReviewSheet> {
  final _s = StorageService.instance;
  late WeeklyReviewModel _review;
  late final List<TextEditingController> _forecastTextCtrls;
  late final List<TextEditingController> _forecastOutcomeCtrls;
  late final TextEditingController _certaintyCtrl;
  late final TextEditingController _oppositeCtrl;
  late final TextEditingController _stressWhatCtrl;
  late final TextEditingController _stressDebriefCtrl;

  @override
  void initState() {
    super.initState();
    _review = _s.getWeeklyReview(widget.weekOf);
    while (_review.forecasts.length < 3) {
      _review.forecasts.add(ForecastModel());
    }
    _forecastTextCtrls = _review.forecasts.map((f) => TextEditingController(text: f.text)).toList();
    _forecastOutcomeCtrls = _review.forecasts.map((f) => TextEditingController(text: f.outcome ?? '')).toList();
    _certaintyCtrl = TextEditingController(text: _review.greyDrillCertainty);
    _oppositeCtrl = TextEditingController(text: _review.greyDrillOpposite);
    _stressWhatCtrl = TextEditingController(text: _review.stressInoculationWhat);
    _stressDebriefCtrl = TextEditingController(text: _review.stressInoculationDebrief);
  }

  @override
  void dispose() {
    for (final c in _forecastTextCtrls) { c.dispose(); }
    for (final c in _forecastOutcomeCtrls) { c.dispose(); }
    _certaintyCtrl.dispose();
    _oppositeCtrl.dispose();
    _stressWhatCtrl.dispose();
    _stressDebriefCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    for (int i = 0; i < _review.forecasts.length; i++) {
      _review.forecasts[i].text = _forecastTextCtrls[i].text.trim();
      final outcome = _forecastOutcomeCtrls[i].text.trim();
      _review.forecasts[i].outcome = outcome.isEmpty ? null : outcome;
    }
    _review.greyDrillCertainty = _certaintyCtrl.text.trim();
    _review.greyDrillOpposite = _oppositeCtrl.text.trim();
    _review.stressInoculationWhat = _stressWhatCtrl.text.trim();
    _review.stressInoculationDebrief = _stressDebriefCtrl.text.trim();
    await _s.saveWeeklyReview(_review);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return PlanSheetScaffold(
      title: 'Weekly review — week of ${widget.weekOf}',
      onSave: _save,
      children: [
        const PlanSectionLabel('Forecasts'),
        for (int i = 0; i < _review.forecasts.length; i++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Forecast ${i + 1}', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
              PlanTextField(hint: 'What I predict…', controller: _forecastTextCtrls[i]),
              PlanSlider(
                label: 'Probability', value: _review.forecasts[i].probability, max: 100,
                color: const Color(0xFF00BFFF),
                valueLabel: (v) => '$v%',
                onChanged: (v) => setState(() => _review.forecasts[i].probability = v),
              ),
              PlanTextField(hint: 'Later outcome…', controller: _forecastOutcomeCtrls[i]),
              Row(children: [
                Expanded(child: Text('Correct?', style: TextStyle(color: c.textPrimary, fontSize: 13))),
                PlanChips(
                  options: const ['yes', 'no'],
                  selected: _review.forecasts[i].correct == null ? null : (_review.forecasts[i].correct! ? 'yes' : 'no'),
                  onChanged: (v) => setState(() => _review.forecasts[i].correct = v == null ? null : v == 'yes'),
                ),
              ]),
            ]),
          ),
        ],

        const PlanSectionLabel('Grey thinking drill'),
        PlanTextField(label: 'What I was certain about', hint: '…', controller: _certaintyCtrl),
        PlanTextField(label: 'The opposite case (≥5 sentences)', hint: '…', controller: _oppositeCtrl, maxLines: 4),

        const PlanSectionLabel('Stress inoculation'),
        PlanTextField(label: 'What I did', hint: '…', controller: _stressWhatCtrl),
        PlanTextField(label: 'Debrief', hint: '…', controller: _stressDebriefCtrl, maxLines: 3),

        const PlanSectionLabel('Social ladder'),
        PlanNumberStepper(
          label: 'Follow-ups sent', value: _review.followUpsSent, max: 50,
          onChanged: (v) => setState(() => _review.followUpsSent = v),
        ),
        PlanNumberStepper(
          label: 'People at 3+ contacts', value: _review.peopleAt3PlusContacts, max: 50,
          onChanged: (v) => setState(() => _review.peopleAt3PlusContacts = v),
        ),
      ],
    );
  }
}
