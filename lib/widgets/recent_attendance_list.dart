import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../core/theme/dagacs_theme.dart';

class RecentAttendanceList extends StatelessWidget {
  const RecentAttendanceList({
    super.key,
    required this.records,
    required this.subjectNamesById,
  });

  final List<AttendanceRecord> records;
  final Map<int, String> subjectNamesById;

  @override
  Widget build(BuildContext context) {
    final recent = List<AttendanceRecord>.from(records)
      ..sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));
    final displayed = recent.take(10).toList();

    if (displayed.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('No recent attendance records')),
      );
    }

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
                  const Icon(Icons.access_time, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Attendance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...displayed.map((r) => _buildRecentItem(r, context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentItem(AttendanceRecord r, BuildContext context) {
    final isPresent = r.isPresent == true || r.status == 'PRESENT';
    final dateStr = _formatDate(r.date);
    final subjectName = subjectNamesById.containsKey(r.subjectId)
        ? subjectNamesById[r.subjectId]!
        : 'Subject ${r.subjectId ?? "-"}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isPresent ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$dateStr — $subjectName',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isPresent ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DagacsRadius.pill),
            ),
            child: Text(
              isPresent ? 'Present' : 'Absent',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isPresent ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    final parts = date.split('-');
    if (parts.length != 3) return date;
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = int.tryParse(parts[1]) ?? 0;
    final day = parts[2];
    final year = parts[0];
    final monthStr = month >= 1 && month <= 12 ? monthNames[month - 1] : parts[1];
    return '$day $monthStr $year';
  }
}
