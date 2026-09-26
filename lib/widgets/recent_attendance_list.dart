import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../core/theme/dagacs_theme.dart';
import 'dagacs_widgets.dart';

/// Recent attendance for the student dashboard, grouped by the day the
/// record was marked. Only records returned by the API are ever rendered.
class RecentAttendanceList extends StatelessWidget {
  const RecentAttendanceList({
    super.key,
    required this.records,
    required this.subjectNamesById,
    this.maxDays = 5,
  });

  final List<AttendanceRecord> records;
  final Map<int, String> subjectNamesById;

  /// Upper bound on distinct day groups, keeping the dashboard compact.
  final int maxDays;

  /// Groups records newest-day-first, preserving intra-day ordering.
  List<MapEntry<String, List<AttendanceRecord>>> _grouped() {
    final sorted = List<AttendanceRecord>.from(records)
      ..sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));

    final groups = <String, List<AttendanceRecord>>{};
    for (final record in sorted) {
      groups.putIfAbsent(record.date ?? '', () => <AttendanceRecord>[]).add(record);
    }
    final entries = groups.entries.toList();
    return entries.length > maxDays ? entries.sublist(0, maxDays) : entries;
  }

  /// "Today" / "Yesterday" when the day matches, otherwise `12 Sep 2026`.
  String _dayLabel(String? rawDate) {
    final parsed = _parse(rawDate);
    if (parsed == null) return 'Unknown date';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return _formatDate(rawDate);
  }

  /// Accepts both `yyyy-M-d` and zero-padded `yyyy-MM-dd` calendar keys.
  static DateTime? _parse(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return null;
    final parts = rawDate.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped();

    if (groups.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: DagacsSpace.md),
            const Text(
              'No recent attendance records',
              style: TextStyle(color: DagacsColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: DagacsSpace.sm),
          for (final group in groups) ...[
            const SizedBox(height: DagacsSpace.md),
            _buildDayHeader(group.key),
            for (final record in group.value)
              Padding(
                padding: const EdgeInsets.only(top: DagacsSpace.sm),
                child: _buildRecentItem(record, context),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const AppIconBadge(
          icon: Icons.history,
          color: DagacsColors.brandPrimary,
          backgroundColor: DagacsColors.brandSoft,
          size: 32,
        ),
        const SizedBox(width: DagacsSpace.md),
        Expanded(
          child: Text(
            'Recent Attendance',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildDayHeader(String rawDate) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: DagacsSpace.xs),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: DagacsColors.border, width: 1),
        ),
      ),
      child: Text(
        _dayLabel(rawDate).toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: DagacsColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildRecentItem(AttendanceRecord r, BuildContext context) {
    final isPresent = r.isPresent == true || r.status == 'PRESENT';
    final subjectName = subjectNamesById.containsKey(r.subjectId)
        ? subjectNamesById[r.subjectId]!
        : 'Subject ${r.subjectId ?? "-"}';

    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: isPresent ? DagacsColors.success : DagacsColors.error,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: DagacsSpace.md),
        Expanded(
          child: Text(
            subjectName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: DagacsSpace.sm),
        _StatusChip(isPresent: isPresent),
      ],
    );
  }

  String _formatDate(String? date) {
    final parsed = _parse(date);
    if (parsed == null) return '-';
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${parsed.day} ${monthNames[parsed.month - 1]} ${parsed.year}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isPresent});

  final bool isPresent;

  @override
  Widget build(BuildContext context) {
    final color =
        isPresent ? DagacsColors.success : DagacsColors.error;
    final background =
        isPresent ? DagacsColors.successBg : DagacsColors.errorBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DagacsRadius.pill),
      ),
      child: Text(
        isPresent ? 'Present' : 'Absent',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
