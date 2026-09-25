import 'package:flutter/material.dart';

import '../models/attendance_record.dart';

class AttendanceDateDetail extends StatelessWidget {
  const AttendanceDateDetail({
    super.key,
    required this.date,
    required this.records,
  });

  final String? date;
  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    if (date == null || date!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Select a date to view details')),
      );
    }

    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('No attendance records for this date')),
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
                  const Icon(Icons.date_range, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    date!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...records.map((r) => _buildRecordTile(r)),
              const SizedBox(height: 8),
              _buildSummaryBar(records, context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordTile(AttendanceRecord r) {
    final isPresent = r.isPresent == true || r.status == 'PRESENT';
    return ListTile(
      leading: Icon(
        isPresent ? Icons.check_circle : Icons.cancel,
        color: isPresent ? Colors.green : Colors.red,
      ),
      title: Text('Subject ${r.subjectId ?? "-"}'),
      subtitle: Text('${r.lecturePeriod ?? "-"} | ${r.status ?? "-"}'),
      trailing: Text(
        isPresent ? 'Present' : 'Absent',
        style: TextStyle(
          color: isPresent ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSummaryBar(List<AttendanceRecord> records, BuildContext context) {
    final presentCount = records.where((r) => r.isPresent == true || r.status == 'PRESENT').length;
    final totalCount = records.length;
    final absentCount = totalCount - presentCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildSummaryItem('Present', presentCount, Colors.green, context),
        _buildSummaryItem('Absent', absentCount, Colors.red, context),
        _buildSummaryItem('Total', totalCount, Colors.blue, context),
      ],
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color, BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
