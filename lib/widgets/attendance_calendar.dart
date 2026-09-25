import 'package:flutter/material.dart';

import '../models/calendar_attendance.dart';

enum CalendarAttendanceState {
  presentOnly,
  absentOnly,
  mixed,
  noRecord,
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

class AttendanceCalendar extends StatefulWidget {
  const AttendanceCalendar({
    super.key,
    required this.calendarData,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onDateSelected,
    this.selectedDate,
  });

  final List<CalendarAttendance> calendarData;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<String> onDateSelected;
  final String? selectedDate;

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
     final todayStr =
         '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
     widget.onDateSelected(todayStr);
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
      days.add('$year-$month-${i.toString().padLeft(2, '0')}');
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
                      )),
                )
              else if (widget.error != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: widget.onRetry, child: const Text('Retry')),
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
    return SizedBox(
      height: MediaQuery.of(context).size.width * 0.85,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
        ),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final date = days[index];
          if (date.isEmpty) {
            return Container();
          }
          final attendance = _getAttendanceForDate(date);
          final state = classifyAttendanceState(
            attendance?.presentCount ?? 0,
            attendance?.absentCount ?? 0,
          );
          final isSelected = widget.selectedDate == date;
          return _buildDayCell(date, state, isSelected);
        },
      ),
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
