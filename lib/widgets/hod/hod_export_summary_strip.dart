import 'package:flutter/material.dart';

import '../../core/theme/dagacs_theme.dart';

/// A one-line summary of what the report on screen actually contains.
///
/// <b>No API call.</b> Every value is handed in by the caller from the data it
/// has already loaded, so this is a genuine preview of the export rather than a
/// second request that could return a different context or a different moment
/// in time. A report preview that re-queried the server would defeat the whole
/// purpose of showing what is about to be downloaded.
class HodExportSummaryStrip extends StatelessWidget {
  const HodExportSummaryStrip({
    super.key,
    this.subjectCount,
    this.studentCount,
    this.rangeText,
    this.generatedAt,
  });

  /// Distinct subjects currently in the report, if the report has any.
  final int? subjectCount;

  /// Students currently in the report, if the report has any.
  final int? studentCount;

  /// The applied date range, or null when no date filter is active.
  final String? rangeText;

  /// When the displayed data was fetched.
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (subjectCount != null) '$subjectCount subject(s)',
      if (studentCount != null) '$studentCount student(s)',
      if (rangeText != null && rangeText!.isNotEmpty) rangeText!,
      if (generatedAt != null) 'as of ${_clock(generatedAt!)}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: 'Report summary: ${parts.join(', ')}',
      excludeSemantics: true,
      child: Container(
        key: const Key('hod-export-summary'),
        padding: const EdgeInsets.symmetric(
            horizontal: DagacsSpace.sm, vertical: DagacsSpace.xs),
        decoration: BoxDecoration(
          color: DagacsColors.textSecondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(DagacsRadius.sm),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                size: 16, color: DagacsColors.textSecondary),
            const SizedBox(width: DagacsSpace.xs),
            Expanded(
              child: Text(
                parts.join(' · '),
                style: DagacsTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
