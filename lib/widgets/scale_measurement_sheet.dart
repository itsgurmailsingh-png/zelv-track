import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import 'plan_inputs.dart';

class ScaleMeasurementSheet extends StatefulWidget {
  final String date;
  final String type; // 'baseline' | 'checkpoint'
  final VoidCallback onSaved;
  const ScaleMeasurementSheet({super.key, required this.date, required this.type, required this.onSaved});

  @override
  State<ScaleMeasurementSheet> createState() => _ScaleMeasurementSheetState();
}

class _ScaleMeasurementSheetState extends State<ScaleMeasurementSheet> {
  final _s = StorageService.instance;
  late ScaleMeasurementModel _existing;
  bool get _isCheckpoint => widget.type == 'checkpoint';

  int _pss10 = 0, _ucla = 0, _ptq = 0, _spin = 0, _rhr = 0;
  int _soiBehavior = 0, _soiAttitude = 0, _soiDesire = 0;
  late final TextEditingController _sleepCtrl;
  late final TextEditingController _screenCtrl;
  late final TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    _existing = _s.getScaleMeasurements().firstWhere(
      (m) => m.date == widget.date,
      orElse: () => ScaleMeasurementModel(date: widget.date, type: widget.type),
    );
    _pss10 = _existing.pss10 ?? 0;
    _ucla = _existing.ucla ?? 0;
    _ptq = _existing.ptq ?? 0;
    _spin = _existing.spin ?? 0;
    _rhr = _existing.rhr ?? 0;
    _soiBehavior = _existing.soiRBehavior ?? 0;
    _soiAttitude = _existing.soiRAttitude ?? 0;
    _soiDesire = _existing.soiRDesire ?? 0;
    _sleepCtrl = TextEditingController(text: _existing.sleepAvg?.toString() ?? '');
    _screenCtrl = TextEditingController(text: _existing.screenAvg?.toString() ?? '');
    _weightCtrl = TextEditingController(text: _existing.weight?.toString() ?? '');
  }

  @override
  void dispose() {
    _sleepCtrl.dispose();
    _screenCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final m = ScaleMeasurementModel(
      date: widget.date,
      type: widget.type,
      pss10: _pss10 == 0 ? null : _pss10,
      ucla: _isCheckpoint ? _existing.ucla : (_ucla == 0 ? null : _ucla),
      ptq: _ptq == 0 ? null : _ptq,
      spin: _spin == 0 ? null : _spin,
      rhr: _isCheckpoint ? _existing.rhr : (_rhr == 0 ? null : _rhr),
      sleepAvg: _isCheckpoint ? _existing.sleepAvg : double.tryParse(_sleepCtrl.text.trim()),
      screenAvg: _isCheckpoint ? _existing.screenAvg : double.tryParse(_screenCtrl.text.trim()),
      weight: _isCheckpoint ? _existing.weight : double.tryParse(_weightCtrl.text.trim()),
      soiRBehavior: _isCheckpoint ? _existing.soiRBehavior : (_soiBehavior == 0 ? null : _soiBehavior),
      soiRAttitude: _isCheckpoint ? _existing.soiRAttitude : (_soiAttitude == 0 ? null : _soiAttitude),
      soiRDesire: _isCheckpoint ? _existing.soiRDesire : (_soiDesire == 0 ? null : _soiDesire),
    );
    await _s.saveScaleMeasurement(m);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await _s.deleteScaleMeasurement(widget.date);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasExisting = _s.getScaleMeasurements().any((m) => m.date == widget.date);
    return PlanSheetScaffold(
      title: _isCheckpoint ? 'Checkpoint retest — ${widget.date}' : 'Measurement — ${widget.date}',
      onSave: _save,
      onDelete: hasExisting ? _delete : null,
      children: [
        PlanSectionLabel(_isCheckpoint ? 'Retest (PTQ / SPIN / PSS-10 only)' : 'Clinical scales (0 = skip)'),
        PlanNumberStepper(label: 'PSS-10', value: _pss10, max: 40, onChanged: (v) => setState(() => _pss10 = v)),
        PlanNumberStepper(label: 'PTQ', value: _ptq, max: 60, onChanged: (v) => setState(() => _ptq = v)),
        PlanNumberStepper(label: 'SPIN', value: _spin, max: 68, onChanged: (v) => setState(() => _spin = v)),
        if (!_isCheckpoint) ...[
          PlanNumberStepper(label: 'UCLA Loneliness', value: _ucla, max: 80, onChanged: (v) => setState(() => _ucla = v)),

          const PlanSectionLabel('Physiology'),
          PlanNumberStepper(label: 'Resting HR', value: _rhr, min: 0, max: 220, onChanged: (v) => setState(() => _rhr = v)),
          PlanTextField(label: 'Sleep avg (hrs)', hint: 'e.g. 7.2', controller: _sleepCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          PlanTextField(label: 'Screen avg (hrs)', hint: 'e.g. 3.5', controller: _screenCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          PlanTextField(label: 'Weight (kg)', hint: 'e.g. 74.0', controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),

          const PlanSectionLabel('SOI-R (baseline only)'),
          PlanNumberStepper(label: 'Behavior', value: _soiBehavior, max: 90, onChanged: (v) => setState(() => _soiBehavior = v)),
          PlanNumberStepper(label: 'Attitude', value: _soiAttitude, max: 90, onChanged: (v) => setState(() => _soiAttitude = v)),
          PlanNumberStepper(label: 'Desire', value: _soiDesire, max: 90, onChanged: (v) => setState(() => _soiDesire = v)),
        ],
      ],
    );
  }
}
