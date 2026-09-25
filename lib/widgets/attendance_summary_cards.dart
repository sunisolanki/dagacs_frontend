import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/attendance_percentage.dart';
import 'dagacs_widgets.dart';

class AttendanceSummaryCards extends StatelessWidget {
  const AttendanceSummaryCards({
    super.key,
    required this.overall,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final AttendancePercentage? overall;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Overall Attendance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )),
                )
              else if (error != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                )
              else if (overall != null) ...[
                _buildDonut(overall!),
                const SizedBox(height: 16),
                _buildStatCards(overall!),
              ]
              else
                const Text('No attendance records available'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonut(AttendancePercentage overall) {
    final presentPercentage = overall.percentage ?? 0.0;
    final absentPercentage = 100.0 - presentPercentage;

    return SizedBox(
      height: 160,
      child: PieChart(
        PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: 50,
          sections: [
            PieChartSectionData(
              value: presentPercentage,
              color: Colors.green,
              title: presentPercentage > 0 ? '${presentPercentage.toStringAsFixed(0)}%' : '',
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              value: absentPercentage,
              color: Colors.red,
              title: absentPercentage > 0 ? '${absentPercentage.toStringAsFixed(0)}%' : '',
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(AttendancePercentage overall) {
    return Row(
      children: [
        Expanded(
          child: AppStatCard(
            icon: Icons.check_circle,
            value: '${overall.presentCount}',
            label: 'Present',
            iconColor: Colors.green,
            iconBackgroundColor: Colors.green.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppStatCard(
            icon: Icons.cancel,
            value: '${overall.totalRecordedCount - overall.presentCount}',
            label: 'Absent',
            iconColor: Colors.red,
            iconBackgroundColor: Colors.red.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppStatCard(
            icon: Icons.event,
            value: '${overall.totalRecordedCount}',
            label: 'Total',
            iconColor: Colors.blue,
            iconBackgroundColor: Colors.blue.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }
}
