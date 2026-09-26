import 'package:flutter/material.dart';

import '../models/attendance_percentage.dart';
import '../core/navigation/navigator.dart';
import '../core/theme/dagacs_theme.dart';
import 'dagacs_widgets.dart';

/// Compact overall-attendance summary.
///
/// Reads as a single dense block: a dominant percentage, the present/total
/// ratio, a slim progress bar and the three counts. Deliberately avoids a
/// large donut so the dashboard stays information-dense and short on screen.
class AttendanceSummaryCards extends StatelessWidget {
  const AttendanceSummaryCards({
    super.key,
    required this.overall,
    required this.loading,
    required this.error,
    required this.onRetry,
    this.showViewFullAttendance = false,
  });

  final AttendancePercentage? overall;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final bool showViewFullAttendance;

  /// Attendance bands drive the hero/progress colour. `null` percentage means
  /// "no recorded attendance" and must never be presented as 0%.
  static Color bandColor(double? percentage) {
    if (percentage == null) return DagacsColors.textSecondary;
    if (percentage >= 75) return DagacsColors.success;
    if (percentage >= 50) return DagacsColors.warning;
    return DagacsColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(DagacsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(
                icon: Icons.insights_outlined,
                color: DagacsColors.brandPrimary,
                backgroundColor: DagacsColors.brandSoft,
                size: 36,
              ),
              const SizedBox(width: DagacsSpace.md),
              Expanded(
                child: Text(
                  'Overall Attendance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DagacsColors.textPrimary,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DagacsSpace.lg),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: DagacsSpace.md),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(error!,
                    style: const TextStyle(color: DagacsColors.error)),
                const SizedBox(height: DagacsSpace.sm),
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            )
          else if (overall != null) ...[
            _buildHero(context, overall!),
            const SizedBox(height: DagacsSpace.lg),
            _buildStatCards(overall!),
            if (showViewFullAttendance) ...[
              const SizedBox(height: DagacsSpace.lg),
              SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  onPressed: () => Navigator.pushNamed(
                      context, AppRoutes.studentAttendance),
                  child: const Text('View Full Attendance →'),
                ),
              ),
            ],
          ]
          else
            const Text('No attendance records available'),
        ],
      ),
    );
  }

  /// Dominant percentage + present/total ratio + slim animated progress bar.
  Widget _buildHero(BuildContext context, AttendancePercentage overall) {
    final percentage = overall.percentage;
    final color = bandColor(percentage);
    final hasData = percentage != null;

    return TweenAnimationBuilder<double>(
      tween: Tween(
          begin: 0, end: hasData ? (percentage / 100).clamp(0.0, 1.0) : 0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  hasData ? '${percentage.toStringAsFixed(0)}%' : '—',
                  style: TextStyle(
                    fontSize: 40,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: hasData ? color : DagacsColors.textSecondary,
                  ),
                ),
                const SizedBox(width: DagacsSpace.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${overall.presentCount} / ${overall.totalRecordedCount} classes attended',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DagacsColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DagacsSpace.md),
            _ProgressTrack(progress: progress, color: color),
          ],
        );
      },
    );
  }

  Widget _buildStatCards(AttendancePercentage overall) {
    return Row(
      children: [
        Expanded(
          child: AppStatCard(
            icon: Icons.check_circle_outline,
            value: '${overall.presentCount}',
            label: 'Present',
            iconColor: DagacsColors.success,
            iconBackgroundColor: DagacsColors.successBg,
          ),
        ),
        const SizedBox(width: DagacsSpace.sm),
        Expanded(
          child: AppStatCard(
            icon: Icons.cancel_outlined,
            value: '${overall.totalRecordedCount - overall.presentCount}',
            label: 'Absent',
            iconColor: DagacsColors.error,
            iconBackgroundColor: DagacsColors.errorBg,
          ),
        ),
        const SizedBox(width: DagacsSpace.sm),
        Expanded(
          child: AppStatCard(
            icon: Icons.event_note_outlined,
            value: '${overall.totalRecordedCount}',
            label: 'Total',
            iconColor: DagacsColors.brandPrimary,
            iconBackgroundColor: DagacsColors.brandSoft,
          ),
        ),
      ],
    );
  }
}

/// Slim rounded progress track. Sized from its parent so it never overflows.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DagacsRadius.pill),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Container(color: DagacsColors.surfaceAlt),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
