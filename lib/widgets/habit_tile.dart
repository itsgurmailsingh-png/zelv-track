import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

// ignore: unused_import
export '../models/models.dart' show HabitModel;

class HabitTile extends StatelessWidget {
  final HabitModel habit;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const HabitTile({
    super.key,
    required this.habit,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onChanged(!checked);
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: checked ? c.accentDim : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: checked ? c.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: checked ? c.accent : c.border,
                    width: 1.5,
                  ),
                ),
                child: checked
                    ? const Icon(Icons.check, size: 16, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  habit.label,
                  style: TextStyle(
                    color: checked ? c.textSecondary : c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: checked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: c.textSecondary,
                  ),
                ),
              ),
              if (habit.isNonNeg) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warn.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.warn.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'MUST',
                    style: TextStyle(
                      color: AppColors.warn,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TimeBlockHeader extends StatelessWidget {
  final String label;
  final String timeRange;
  final int total;
  final int done;

  const TimeBlockHeader({
    super.key,
    required this.label,
    required this.timeRange,
    required this.total,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeRange,
            style: TextStyle(color: c.textDisabled, fontSize: 11),
          ),
          const Spacer(),
          Text(
            '$done / $total',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
