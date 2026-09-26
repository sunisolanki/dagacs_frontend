import 'package:flutter/material.dart';

import '../models/calendar_attendance.dart';
import '../models/attendance_record.dart';

enum CalendarAttendanceState {
  presentOnly,
  absentOnly,
  mixed,
  noRecord,
}

/// Canonical ISO calendar date (`yyyy-MM-dd`) used for every date this widget
/// emits - tapped day cells, month navigation and the Today action.
///
/// The backend serves `AttendanceRecord.date` and the calendar-summary keys in
/// this exact zero-padded form, so a single shared formatter guarantees the two
/// can never diverge again (an earlier `yyyy-M-d` day-cell format meant tapped
/// dates never matched a record).
String _isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

CalendarAttendanceState classifyAttendanceState(int presentCount, int absentCount) {
  if (presentCount > 0 && absentCount == 0) return CalendarAttendanceState.presentOnly;
  if (presentCount == 0 && absentCount > 0) return CalendarAttendanceState.absentOnly;
  if (presentCount > 0 && absentCount > 0) return CalendarAttendanceState.mixed;
  return CalendarAttendanceState.noRecord;
}

Color getStateColor(CalendarAttendanceState state) {
  switch (state) {
    case CalendarAttendanceState.presentOnly:
      return Colors.green;
    case CalendarAttendanceState.absentOnly:
      return Colors.red;
    case CalendarAttendanceState.mixed:
      return Colors.orange;
    case CalendarAttendanceState.noRecord:
      return Colors.grey;
  }
}

CalendarAttendanceState _classifySubjectState(int presentCount, int absentCount) {
  if (presentCount > 0 && absentCount == 0) return CalendarAttendanceState.presentOnly;
  if (presentCount == 0 && absentCount > 0) return CalendarAttendanceState.absentOnly;
  if (presentCount > 0 && absentCount > 0) return CalendarAttendanceState.mixed;
  return CalendarAttendanceState.noRecord;
}

CalendarAttendanceState _getStateForDate(
  String date,
  CalendarAttendance? aggregate,
  int? subjectId,
  List<AttendanceRecord>? allRecords,
) {
  if (subjectId != null && allRecords != null) {
    final subjectRecords = allRecords.where((r) =>
        r.subjectId == subjectId && r.date == date).toList();
    if (subjectRecords.isEmpty) return CalendarAttendanceState.noRecord;
    final presentCount = subjectRecords.where((r) => r.isPresent == true || r.status == 'PRESENT').length;
    final absentCount = subjectRecords.length - presentCount;
    return _classifySubjectState(presentCount, absentCount);
  }
  return classifyAttendanceState(
    aggregate?.presentCount ?? 0,
    aggregate?.absentCount ?? 0,
  );
}

class AttendanceCalendar extends StatefulWidget {
  const AttendanceCalendar({
    super.key,
    required this.calendarData,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onDateSelected,
    this.selectedDate,
    this.subjectId,
    this.allRecords,
  });

  final List<CalendarAttendance> calendarData;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<String> onDateSelected;
  final String? selectedDate;
  final int? subjectId;
  final List<AttendanceRecord>? allRecords;

  @override
  State<AttendanceCalendar> createState() => _AttendanceCalendarState();
}

class _AttendanceCalendarState extends State<AttendanceCalendar> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime.now();
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    });
    widget.onDateSelected('');
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    });
    widget.onDateSelected('');
  }

  void _today() {
    final now = DateTime.now();
    setState(() {
      _displayedMonth = now;
    });
    widget.onDateSelected(_isoDate(now));
  }

  String _getMonthYearString() {
    return '${_displayedMonth.year} ${_displayedMonth.month.toString().padLeft(2, '0')}';
  }

  List<String> _getDaysInMonth() {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startDayOfWeek = firstDay.weekday;
    final totalDays = lastDay.day;

    final days = <String>[];
    for (int i = 1; i < startDayOfWeek; i++) {
      days.add('');
    }
    for (int i = 1; i <= totalDays; i++) {
      // ISO yyyy-MM-dd so a tapped cell matches AttendanceRecord.date and the
      // calendar-summary keys returned by the backend.
      days.add(_isoDate(DateTime(year, month, i)));
    }
    while (days.length % 7 != 0) {
      days.add('');
    }
    return days;
  }

  CalendarAttendance? _getAttendanceForDate(String date) {
    if (date.isEmpty) return null;
    return widget.calendarData.firstWhere(
      (d) => d.date == date,
      orElse: () => CalendarAttendance(
        date: '',
        presentCount: 0,
        absentCount: 0,
        totalRecordedCount: 0,
        percentage: null,
      ),
    );
  }

  CalendarAttendanceState _computeStateForDate(String date) {
    final aggregate = _getAttendanceForDate(date);
    return _getStateForDate(date, aggregate, widget.subjectId, widget.allRecords);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Attendance Calendar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (widget.error != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      OutlinedButton(
                          onPressed: widget.onRetry, child: const Text('Retry')),
                    ],
                  )
                else ...[
                  _buildMonthNavigation(),
                  const SizedBox(height: 8),
                  _buildWeekdayHeader(),
                  const SizedBox(height: 4),
                  _buildCalendarGrid(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _previousMonth,
        ),
        Text(
          _getMonthYearString(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        TextButton(onPressed: _today, child: const Text('Today')),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _nextMonth,
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final days = _getDaysInMonth();
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final date = days[index];
        if (date.isEmpty) {
          return Container();
        }
        final state = _computeStateForDate(date);
        final isSelected = widget.selectedDate == date;
        return _buildDayCell(date, state, isSelected);
      },
    );
  }

  Widget _buildDayCell(String date, CalendarAttendanceState state, bool isSelected) {
    final dayNumber = int.tryParse(date.split('-').last) ?? 0;
    final displayDay = dayNumber == 0 ? '' : '$dayNumber';
    final color = getStateColor(state);

    return GestureDetector(
      onTap: () {
        if (date.isNotEmpty) {
          widget.onDateSelected(date);
        }
      },
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(color: Colors.blue, width: 2)
              : Border.all(color: Colors.grey.shade300, width: 0.5),
          borderRadius: BorderRadius.circular(4),
          color: isSelected ? Colors.blue.withValues(alpha: 0.15) : null,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayDay,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.blue : Colors.black,
                ),
              ),
              if (displayDay.isNotEmpty)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
