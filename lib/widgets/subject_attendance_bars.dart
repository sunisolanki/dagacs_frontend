import 'package:flutter/material.dart';

import '../core/theme/dagacs_theme.dart';
import '../models/subject_attendance.dart';
import 'attendance_summary_cards.dart';
import 'dagacs_widgets.dart';

/// Compact subject-wise attendance for the student dashboard.
///
/// One row per subject: name, present/total, percentage and a slim animated
/// bar. Deliberately not a bar chart — an axis adds height and label clutter
/// without adding information at this density.
class SubjectAttendanceBars extends StatelessWidget {
  const SubjectAttendanceBars({
    super.key,
    required this.subjects,
    this.emptyMessage = 'No subject attendance data available',
  });

  final List<SubjectAttendance> subjects;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) {
      return AppCard(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: DagacsColors.textSecondary),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = DagacsBreakpoints.columnsFor(constraints.maxWidth) >= 2
            ? 2
            : 1;
        const gap = DagacsSpace.md;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < subjects.length; i++)
              SizedBox(
                width: itemWidth,
                child: _SubjectBar(
                  subject: subjects[i],
                  // Slight stagger keeps the reveal calm rather than abrupt.
                  delay: Duration(milliseconds: 40 * i),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SubjectBar extends StatelessWidget {
  const _SubjectBar({required this.subject, required this.delay});

  final SubjectAttendance subject;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final percentage = subject.percentage;
    final color = AttendanceSummaryCards.bandColor(percentage);
    final ratio = (percentage ?? 0).clamp(0.0, 100.0) / 100.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: ratio),
      duration: Duration(milliseconds: 450) + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject.subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: DagacsColors.textPrimary,
                        ),
                  ),
                ),
                const SizedBox(width: DagacsSpace.sm),
                Text(
                  '${subject.presentCount}/${subject.totalRecordedCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DagacsColors.textSecondary,
                  ),
                ),
                const SizedBox(width: DagacsSpace.sm),
                SizedBox(
                  width: 42,
                  child: Text(
                    percentage == null ? 'N/A' : '${percentage.toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DagacsSpace.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(DagacsRadius.pill),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(color: DagacsColors.surfaceAlt),
                    FractionallySizedBox(
                      widthFactor: value,
                      child: Container(color: color),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
