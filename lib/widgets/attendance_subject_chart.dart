import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/subject_attendance.dart';

class AttendanceSubjectChart extends StatelessWidget {
  const AttendanceSubjectChart({
    super.key,
    required this.subjects,
    this.loading = false,
    this.error,
    required this.onRetry,
  });

  final List<SubjectAttendance> subjects;
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
                  const Icon(Icons.bar_chart, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Subject Attendance',
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
              else if (subjects.isEmpty)
                const Text('No subject attendance data available'),
              if (subjects.isNotEmpty) ...[
                _buildBarChart(subjects, context),
                const SizedBox(height: 12),
                ...subjects.map((s) => _buildSubjectItem(s, context)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(List<SubjectAttendance> subjects, BuildContext context) {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final subject = subjects[groupIndex];
                return BarTooltipItem(
                  '${subject.percentage?.toStringAsFixed(0) ?? "N/A"}%',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, interval: 25),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < subjects.length) {
                    final name = subjects[index].subjectName;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        name.length > 8 ? '${name.substring(0, 8)}...' : name,
                        style: const TextStyle(fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: subjects.asMap().entries.map((entry) {
            final index = entry.key;
            final subject = entry.value;
            final value = subject.percentage ?? 0.0;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: value,
                  color: _getColor(value),
                  width: 20,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getColor(double percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSubjectItem(SubjectAttendance subject, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              subject.subjectName,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '${subject.presentCount}/${subject.totalRecordedCount}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          Text(
            '${subject.percentage?.toStringAsFixed(0) ?? "N/A"}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getColor(subject.percentage ?? 0),
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
