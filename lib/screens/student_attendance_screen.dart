import 'package:flutter/material.dart';

import '../models/attendance_percentage.dart';
import '../models/attendance_record.dart';
import '../models/calendar_attendance.dart';
import '../models/subject_attendance.dart';
import '../network/api_exception.dart';
import '../repositories/attendance_repository.dart';
import '../widgets/dagacs_widgets.dart';
import '../widgets/attendance_calendar.dart';
import '../widgets/attendance_date_detail.dart';
import '../widgets/attendance_subject_chart.dart';

/// M9.14: inline date-range validation message shown when the selected start
/// date is after the selected end date.
const String kInvertedDateRangeMessage =
    'End date must be on or after the start date.';

/// True when the optional inclusive date range is inverted (start after end).
/// An equal range (start == end) is a valid single-day filter.
bool isInvertedDateRange(DateTime? start, DateTime? end) =>
    start != null && end != null && start.isAfter(end);

/// Read-only student attendance view. The backend resolves the student
/// identity from the JWT — no studentId is accepted from the client.
///
/// Features:
///   A. Attendance records (frozen M3 behavior) — always renders on success.
///   B. Overall attendance calculation — loading / data / error, isolated.
///   C. Per-subject attendance calculation — isolated per subject.
///   D. Interactive calendar (GridView.builder) — date-wise summary.
///   E. Subject-wise chart — bar chart of percentages.
///   F. Selected-date details — subject-level attendance for chosen date.
///   G. Subject filter dropdown — filter calendar and date details by subject.
///
/// A failure in B, C, D, or E must never invalidate the records (A).
/// Calculation values come straight from the backend API — Flutter never
/// recomputes the percentage.
class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen(
      {super.key, required this.attendanceRepository});

  final AttendanceRepository attendanceRepository;

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _SubjectCalc {
  _SubjectCalc._success(AttendancePercentage value)
      : data = value,
        error = null;
  _SubjectCalc._error(String message)
      : data = null,
        error = message;

  final AttendancePercentage? data;
  final String? error;

  bool get loading => data == null && error == null;
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  bool _loading = true;
  String? _error;
  List<AttendanceRecord> _records = [];

  DateTime? _startDate;
  DateTime? _endDate;
  String? _dateError;

  bool _overallLoading = true;
  String? _overallError;
  AttendancePercentage? _overall;

  Map<int, _SubjectCalc> _subjectCalcs = {};

  bool _calendarLoading = true;
  String? _calendarError;
  List<CalendarAttendance> _calendarData = [];

  bool _chartLoading = true;
  String? _chartError;
  List<SubjectAttendance> _subjectChartData = [];

  String? _selectedDate;
  List<AttendanceRecord> _selectedDateRecords = [];

  int? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Map<int, String> get subjectNamesById {
    return {
      for (final s in _subjectChartData) s.subjectId: s.subjectName,
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _overallLoading = true;
      _overallError = null;
      _overall = null;
      _subjectCalcs = {};
      _calendarLoading = true;
      _calendarError = null;
      _calendarData = [];
      _chartLoading = true;
      _chartError = null;
      _subjectChartData = [];
    });

    String? recordsError;
    List<AttendanceRecord> records = [];
    try {
      records = await widget.attendanceRepository.getMyAttendance();
    } on ApiException catch (e) {
      recordsError = _messageFor(e);
    } catch (_) {
      recordsError = 'Something went wrong while loading attendance.';
    }

    if (!mounted) return;
    setState(() {
      _records = records;
      _error = recordsError;
    });

    final calcResult = await _fetchCalculations();
    final calendarResult = await _fetchCalendarData();
    final chartResult = await _fetchSubjectChartData();

    if (!mounted) return;
    setState(() {
      _overall = calcResult.$1;
      _overallError = calcResult.$2;
      _overallLoading = false;
      _subjectCalcs = calcResult.$3;
      _calendarData = calendarResult.$1 ?? <CalendarAttendance>[];
      _calendarError = calendarResult.$2;
      _calendarLoading = false;
      _subjectChartData = chartResult.$1 ?? <SubjectAttendance>[];
      _chartError = chartResult.$2;
      _chartLoading = false;
      _loading = false;
    });
  }

  Future<(AttendancePercentage?, String?, Map<int, _SubjectCalc>)> _fetchCalculations() async {
    final start = _startDate;
    final end = _endDate;

    AttendancePercentage? overall;
    String? overallError;
    try {
      overall = await widget.attendanceRepository
          .getOverallAttendanceCalculation(startDate: start, endDate: end);
    } on ApiException catch (e) {
      overallError = _messageFor(e);
    } catch (_) {
      overallError = 'Something went wrong while loading your attendance summary.';
    }

    final subjectIds = <int>{
      for (final r in _records)
        if (r.subjectId != null) r.subjectId!,
    };
    final subjectCalcs = <int, _SubjectCalc>{};
    if (subjectIds.isNotEmpty) {
      final results = await Future.wait(
        subjectIds.map((id) async {
          try {
            final value = await widget.attendanceRepository
                .getSubjectAttendanceCalculation(id, startDate: start, endDate: end);
            return MapEntry(id, _SubjectCalc._success(value));
          } on ApiException catch (e) {
            return MapEntry(id, _SubjectCalc._error(_messageFor(e)));
          } catch (_) {
            return MapEntry(
                id,
                _SubjectCalc._error(
                    'Failed to load this subject\u2019s attendance.'));
          }
        }),
      );
      for (final entry in results) {
        subjectCalcs[entry.key] = entry.value;
      }
    }

    return (overall, overallError, subjectCalcs);
  }

  Future<(List<CalendarAttendance>?, String?)> _fetchCalendarData() async {
    try {
      final data = await widget.attendanceRepository
          .getCalendarAttendanceSummary(startDate: _startDate, endDate: _endDate);
      if (!mounted) return (null, null);
      return (data, null);
    } on ApiException catch (e) {
      if (!mounted) return (null, null);
      return (null, _messageFor(e));
    } catch (_) {
      if (!mounted) return (null, null);
      return (null, 'Something went wrong while loading the calendar.');
    }
  }

  Future<(List<SubjectAttendance>?, String?)> _fetchSubjectChartData() async {
    try {
      final data = await widget.attendanceRepository
          .getSubjectAttendanceSummaries(startDate: _startDate, endDate: _endDate);
      if (!mounted) return (null, null);
      return (data, null);
    } on ApiException catch (e) {
      if (!mounted) return (null, null);
      return (null, _messageFor(e));
    } catch (_) {
      if (!mounted) return (null, null);
      return (null, 'Something went wrong while loading subject data.');
    }
  }

  Future<void> _applyDates() async {
    if (isInvertedDateRange(_startDate, _endDate)) {
      setState(() => _dateError = kInvertedDateRangeMessage);
      return;
    }
    setState(() {
      _overallLoading = true;
      _overallError = null;
      _overall = null;
      _subjectCalcs = {};
      _calendarLoading = true;
      _calendarError = null;
      _calendarData = [];
      _chartLoading = true;
      _chartError = null;
      _subjectChartData = [];
    });
    final calcResult = await _fetchCalculations();
    final calendarResult = await _fetchCalendarData();
    final chartResult = await _fetchSubjectChartData();

    if (!mounted) return;
    setState(() {
      _overall = calcResult.$1;
      _overallError = calcResult.$2;
      _overallLoading = false;
      _subjectCalcs = calcResult.$3;
      _calendarData = calendarResult.$1 ?? <CalendarAttendance>[];
      _calendarError = calendarResult.$2;
      _calendarLoading = false;
      _subjectChartData = chartResult.$1 ?? <SubjectAttendance>[];
      _chartError = chartResult.$2;
      _chartLoading = false;
    });
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select start date',
    );
    if (picked == null) return;
    if (isInvertedDateRange(picked, _endDate)) {
      setState(() => _dateError = kInvertedDateRangeMessage);
      return;
    }
    setState(() {
      _startDate = picked;
      _dateError = null;
    });
    await _applyDates();
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select end date',
    );
    if (picked == null) return;
    if (isInvertedDateRange(_startDate, picked)) {
      setState(() => _dateError = kInvertedDateRangeMessage);
      return;
    }
    setState(() {
      _endDate = picked;
      _dateError = null;
    });
    await _applyDates();
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _dateError = null;
    });
    _applyDates();
  }

  /// Records shown in the selected-date detail panel.
  ///
  /// Applies the selected date, and additionally the active subject filter when
  /// one is chosen, so the detail panel always agrees with the calendar (which
  /// colours its day cells with the same subject scope). Purely a record
  /// lookup - no percentage/aggregation logic lives here.
  List<AttendanceRecord> _filterRecordsForSelectedDate() {
    final date = _selectedDate;
    if (date == null || date.isEmpty) return const <AttendanceRecord>[];
    final subjectId = _selectedSubjectId;
    return _records
        .where((r) =>
            r.date == date &&
            (subjectId == null || r.subjectId == subjectId))
        .toList();
  }

  void _onDateSelected(String date) {
    setState(() {
      _selectedDate = date;
      _selectedDateRecords =
          date.isEmpty ? const <AttendanceRecord>[] : _filterRecordsForSelectedDate();
    });
  }

  void _onSubjectChanged(int? subjectId) {
    setState(() {
      _selectedSubjectId = subjectId;
      // The selected date is intentionally preserved; the records for it are
      // re-derived under the new subject so the panel stays open. When the
      // newly selected subject has nothing on that date the panel shows the
      // "no records" state instead of silently resetting the selection.
      _selectedDateRecords = _filterRecordsForSelectedDate();
    });
  }

  String _messageFor(ApiException e) {
    return userMessageFor(e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            _buildDateBar(),
            _buildOverallCard(),
            _buildSubjectFilter(),
            if (_subjectChartData.isNotEmpty && !_chartLoading)
              _buildSubjectChartSection(),
            _buildCalendarSection(),
            if (_selectedDate != null && _selectedDateRecords.isNotEmpty)
              _buildDateDetailSection(),
            if (_selectedDate != null && _selectedDateRecords.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No attendance records for this date')),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppErrorState(message: _error!, onRetry: _load),
              ),
            if (_records.isEmpty && _error == null && !_loading)
              _buildEmptyRecords(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBar() {
    final hasFilter = _startDate != null || _endDate != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('start-date-button'),
                  onPressed: _pickStartDate,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _startDate == null ? 'Start date' : _formatDate(_startDate!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('end-date-button'),
                  onPressed: _pickEndDate,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _endDate == null ? 'End date' : _formatDate(_endDate!),
                  ),
                ),
              ),
              if (hasFilter) ...[
                const SizedBox(width: 4),
                IconButton(
                  key: const Key('clear-dates-button'),
                  onPressed: _clearDates,
                  tooltip: 'Clear dates',
                  icon: const Icon(Icons.clear),
                ),
              ],
            ],
          ),
          if (_dateError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _dateError!,
                key: const Key('date-range-error'),
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Widget _buildOverallCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
              if (_overallLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )),
                )
              else if (_overallError != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_overallError!,
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _retryOverall,
                      child: const Text('Retry summary'),
                    ),
                  ],
                )
              else if (_overall != null && _overall!.percentage != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_overall!.presentCount} / ${_overall!.totalRecordedCount}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      _formatPercentage(_overall!.percentage!),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.blue),
                    ),
                  ],
                )
              else
                const Text('No attendance records available'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectFilter() {
    final subjectIds = _subjectCalcs.keys.toList();
    if (subjectIds.isEmpty) return const SizedBox.shrink();

    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem(
        value: null,
        child: Text('All Subjects'),
      ),
      ...subjectIds.map((id) {
        final name = subjectNamesById[id] ?? 'Subject $id';
        return DropdownMenuItem(
          value: id,
          child: Text(name),
        );
      }),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subject Filter',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: _selectedSubjectId,
                items: items,
                onChanged: _onSubjectChanged,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                isExpanded: true,
                hint: const Text('All Subjects'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectChartSection() {
    return AttendanceSubjectChart(
      subjects: _subjectChartData,
      loading: _chartLoading,
      error: _chartError,
      onRetry: _fetchSubjectChartData,
    );
  }

  Widget _buildCalendarSection() {
    return AttendanceCalendar(
      calendarData: _calendarData,
      loading: _calendarLoading,
      error: _calendarError,
      onRetry: _fetchCalendarData,
      onDateSelected: _onDateSelected,
      selectedDate: _selectedDate,
      subjectId: _selectedSubjectId,
      allRecords: _records.isNotEmpty ? _records : null,
    );
  }

  Widget _buildDateDetailSection() {
    return AttendanceDateDetail(
      date: _selectedDate,
      records: _selectedDateRecords,
      subjectNamesById: subjectNamesById.isNotEmpty ? subjectNamesById : null,
    );
  }

  String _formatPercentage(double value) {
    final text = value.toString();
    final trimmed = text.endsWith('.0')
        ? text.substring(0, text.length - 2)
        : text;
    return '$trimmed%';
  }

  Future<void> _retryOverall() async {
    setState(() {
      _overallLoading = true;
      _overallError = null;
      _overall = null;
    });
    try {
      final value = await widget.attendanceRepository
          .getOverallAttendanceCalculation(
              startDate: _startDate, endDate: _endDate);
      if (!mounted) return;
      setState(() {
        _overall = value;
        _overallLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _overallError = _messageFor(e);
        _overallLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _overallError =
            'Something went wrong while loading your attendance summary.';
        _overallLoading = false;
      });
    }
  }

  Widget _buildEmptyRecords() {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('No attendance records found.', key: const Key('empty_records')),
        ],
      ),
    );
  }
}
