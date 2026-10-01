import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/theme/dagacs_theme.dart';

/// Shared optional date-range filter for every HOD screen.
///
/// The widget keys, the date-picker bounds and the inline validation copy are
/// carried over verbatim from the previous HOD dashboard so the existing
/// date-filter behaviour (including "an invalid range issues no request and
/// preserves already-loaded data") is unchanged.
class HodDateFilterBar extends StatelessWidget {
  const HodDateFilterBar({
    super.key,
    required this.context,
    required this.onRangeChanged,
  });

  final HodAcademicContext context;

  /// Invoked after a valid date change or a clear. Never invoked while the
  /// range is invalid, mirroring the previous request-blocking behaviour.
  final VoidCallback onRangeChanged;

  Future<void> _pickStart(BuildContext buildContext) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: buildContext,
      initialDate: context.startDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select start date',
    );
    if (picked == null) return;
    context.setStartDate(picked);
    if (context.datesInvalid) return;
    onRangeChanged();
  }

  Future<void> _pickEnd(BuildContext buildContext) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: buildContext,
      initialDate: context.endDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select end date',
    );
    if (picked == null) return;
    context.setEndDate(picked);
    if (context.datesInvalid) return;
    onRangeChanged();
  }

  void _clear() {
    context.clearDates();
    onRangeChanged();
  }

  static String formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final invalid = this.context.datesInvalid;
    return Padding(
      padding: const EdgeInsets.fromLTRB(DagacsSpace.md, 0, DagacsSpace.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('start-date-button'),
                  onPressed: () => _pickStart(context),
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    this.context.startDate == null
                        ? 'Start date'
                        : formatDate(this.context.startDate!),
                  ),
                ),
              ),
              const SizedBox(width: DagacsSpace.sm),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('end-date-button'),
                  onPressed: () => _pickEnd(context),
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    this.context.endDate == null
                        ? 'End date'
                        : formatDate(this.context.endDate!),
                  ),
                ),
              ),
              if (this.context.hasDateFilter) ...[
                const SizedBox(width: DagacsSpace.xs),
                IconButton(
                  key: const Key('clear-dates-button'),
                  onPressed: _clear,
                  tooltip: 'Clear dates',
                  icon: const Icon(Icons.clear),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: DagacsSpace.xs),
            child: Text(
              invalid
                  ? 'Start date must not be after end date.'
                  : 'The selected range applies to this view.',
              key: const Key('hod-date-filter-hint'),
              style: TextStyle(
                color: invalid ? Colors.red : DagacsColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
