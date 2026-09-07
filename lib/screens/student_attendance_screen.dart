import 'package:flutter/material.dart';

import '../models/attendance_percentage.dart';
import '../models/attendance_record.dart';
import '../network/api_exception.dart';
import '../repositories/attendance_repository.dart';

/// Read-only student attendance view. The backend resolves the student
/// identity from the JWT — no studentId is accepted from the client.
///
/// Three independent data states:
///   A. Attendance records (frozen M3 behavior) — always renders on success.
///   B. Overall attendance calculation — loading / data / error, isolated.
///   C. Per-subject attendance calculation — isolated per subject.
///
/// A failure in B or C must never invalidate the records (A). Calculation
/// values come straight from the backend M4.1 API — Flutter never recomputes
/// the percentage.
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

  // Optional inclusive date-range filter (M4.3). Applies to the calculation
  // requests only — GET /student/attendance/my stays undated.
  DateTime? _startDate;
  DateTime? _endDate;

  // Overall calculation (B) — independent of records.
  bool _overallLoading = true;
  String? _overallError;
  AttendancePercentage? _overall;

  // Per-subject calculations (C) — independent per subject.
  Map<int, _SubjectCalc> _subjectCalcs = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      // Reset calculation states so a pull-to-refresh does not show stale data.
      _overallLoading = true;
      _overallError = null;
      _overall = null;
      _subjectCalcs = {};
    });

    // A) Attendance records — isolated from calculation failures.
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

    // B + C) Calculations — isolated overall and per-subject states.
    await _fetchCalculations();

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  /// Fetches overall (B) and per-subject (C) calculations, honoring the
  /// selected date range. Uses the already-loaded [_records] for the subject
  /// list so a date change refreshes only the calculation state — the
  /// attendance-record retrieval is never re-triggered here.
  Future<void> _fetchCalculations() async {
    final start = _startDate;
    final end = _endDate;

    // B) Overall calculation — isolated.
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

    if (!mounted) return;

    // C) Per-subject calculations — derive real subjectIds only from records,
    // deduplicate, and fetch in parallel. Each subject is isolated.
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

    if (!mounted) return;

    setState(() {
      _overall = overall;
      _overallError = overallError;
      _overallLoading = false;
      _subjectCalcs = subjectCalcs;
    });
  }

  Future<void> _applyDates() async {
    setState(() {
      _overallLoading = true;
      _overallError = null;
      _overall = null;
      _subjectCalcs = {};
    });
    await _fetchCalculations();
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
    setState(() => _startDate = picked);
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
    setState(() => _endDate = picked);
    await _applyDates();
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _applyDates();
  }

  String _messageFor(ApiException e) {
    switch (e.statusCode) {
      case 401:
        return 'Session expired. Please sign in again.';
      case -1:
        return 'Network error. Check your connection and retry.';
      default:
        return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Records failure is still a hard error for the whole screen (frozen behavior).
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_records.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [_buildDateBar(), _buildOverallCard(), _buildEmptyRecords()],
        ),
      );
    }

    final grouped = <int, List<AttendanceRecord>>{};
    for (final r in _records) {
      final id = r.subjectId;
      if (id == null) continue;
      grouped.putIfAbsent(id, () => []).add(r);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          _buildDateBar(),
          _buildOverallCard(),
          for (final entry in grouped.entries) ...[
            _buildSubjectHeader(entry.key, entry.value),
            for (final r in entry.value) _buildRecordTile(r),
          ],
          if (grouped.isEmpty) _buildEmptyRecords(),
        ],
      ),
    );
  }

  Widget _buildDateBar() {
    final hasFilter = _startDate != null || _endDate != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
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
                // percentage == null -> no recorded attendance.
                const Text('No attendance records available'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectHeader(int subjectId, List<AttendanceRecord> records) {
    final calc = _subjectCalcs[subjectId];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject $subjectId',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (calc == null || calc.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (calc.error != null)
            Text(
              calc.error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            )
          else if (calc.data != null && calc.data!.percentage != null)
            Text(
              'Present: ${calc.data!.presentCount}  |  '
              'Recorded: ${calc.data!.totalRecordedCount}  |  '
              'Percentage: ${_formatPercentage(calc.data!.percentage!)}',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            const Text('No attendance records available'),
        ],
      ),
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
          Text('No attendance records found.'),
        ],
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
      subtitle: Text(
          '${r.date ?? "-"} | ${r.lecturePeriod ?? "-"} | ${r.status ?? "-"}'),
      trailing: Text(
        isPresent ? 'Present' : 'Absent',
        style: TextStyle(
          color: isPresent ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
