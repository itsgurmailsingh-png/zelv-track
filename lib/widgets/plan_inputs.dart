import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Shared bottom-sheet scaffold (drag handle, title, scrollable body, actions) ─

class PlanSheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final String saveLabel;
  final VoidCallback? onDelete;

  const PlanSheetScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.saveLabel = 'Save',
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
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
            Text(title, style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              if (onDelete != null)
                TextButton(onPressed: onDelete, child: const Text('Delete', style: TextStyle(color: Colors.red))),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accent, foregroundColor: Colors.black, elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(saveLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class PlanSectionLabel extends StatelessWidget {
  final String text;
  const PlanSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text.toUpperCase(), style: TextStyle(
        color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2,
      )),
    );
  }
}

// ─── Number stepper (replaces checkboxes — the value itself is the record) ────

class PlanNumberStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const PlanNumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label,
          style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w500))),
        _RoundIconButton(
          icon: Icons.remove_rounded,
          onTap: value > min ? () => onChanged((value - step).clamp(min, max)) : null,
        ),
        SizedBox(width: 44, child: Text('$value', textAlign: TextAlign.center,
          style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
        _RoundIconButton(
          icon: Icons.add_rounded,
          onTap: value < max ? () => onChanged((value + step).clamp(min, max)) : null,
        ),
      ]),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: enabled ? c.textPrimary : c.textDisabled),
      ),
    );
  }
}

// ─── Labeled slider (mood, pain, confidence, probability) ─────────────────────

class PlanSlider extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final Color color;
  final ValueChanged<int> onChanged;
  final String Function(int)? valueLabel;

  const PlanSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 10,
    this.color = const Color(0xFF7C6EFF),
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label,
          style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w500))),
        Text(valueLabel?.call(value) ?? '$value',
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: color,
          inactiveTrackColor: c.surfaceHigh,
          thumbColor: color,
          overlayColor: color.withValues(alpha: 0.15),
          trackHeight: 4,
        ),
        child: Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
    ]);
  }
}

// ─── Segmented chip picker (enum-like fields) ──────────────────────────────────

class PlanChips extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final bool allowDeselect;

  const PlanChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.allowDeselect = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Wrap(spacing: 8, runSpacing: 8, children: options.map((opt) {
      final sel = selected == opt;
      return GestureDetector(
        onTap: () => onChanged(sel && allowDeselect ? null : opt),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: sel ? c.accent : c.surfaceHigh, borderRadius: BorderRadius.circular(8)),
          child: Text(opt, style: TextStyle(
            color: sel ? Colors.black : c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600,
          )),
        ),
      );
    }).toList());
  }
}

// ─── Toggle row (genuinely binary fields — social_initiation, knee_swelling) ──

class PlanToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;

  const PlanToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.color = const Color(0xFF00E5A0),
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(child: Text(label,
            style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w500))),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 26,
            decoration: BoxDecoration(color: value ? color : c.border, borderRadius: BorderRadius.circular(13)),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(3),
                width: 20, height: 20,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Text field ────────────────────────────────────────────────────────────────

class PlanTextField extends StatelessWidget {
  final String? label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;

  const PlanTextField({
    super.key,
    this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label != null) ...[
          Text(label!, style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: c.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: c.textDisabled),
            filled: true, fillColor: c.surfaceHigh,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ]),
    );
  }
}
