import 'package:flutter/material.dart';

import '../models/attendance_percentage.dart';
import '../models/subject_attendance.dart';
import '../models/attendance_record.dart';
import '../repositories/attendance_repository.dart';
import '../core/theme/dagacs_theme.dart';
import '../widgets/attendance_summary_cards.dart';
import '../widgets/attendance_subject_chart.dart';
import '../widgets/recent_attendance_list.dart';
import '../widgets/dagacs_widgets.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({
    super.key,
    required this.attendanceRepository,
  });

  final AttendanceRepository attendanceRepository;

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  bool _loading = true;
  String? _error;
  AttendancePercentage? _overall;
  List<SubjectAttendance> _subjects = [];
  List<AttendanceRecord> _records = [];
  bool _overallLoading = true;
  String? _overallError;
  bool _subjectsLoading = true;
  String? _subjectsError;
  bool _recordsLoading = true;

  Map<int, String> get subjectNamesById {
    return {
      for (final s in _subjects) s.subjectId: s.subjectName,
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _overallLoading = true;
      _overallError = null;
      _subjectsLoading = true;
      _subjectsError = null;
      _recordsLoading = true;
    });

    Future<AttendancePercentage?> overallFuture;
    Future<List<SubjectAttendance>> subjectsFuture;
    Future<List<AttendanceRecord>> recordsFuture;

    try {
      overallFuture = widget.attendanceRepository.getOverallAttendanceCalculation();
    } catch (_) {
      overallFuture = Future.value(null);
    }

    try {
      subjectsFuture = widget.attendanceRepository.getSubjectAttendanceSummaries();
    } catch (_) {
      subjectsFuture = Future.value([]);
    }

    try {
      recordsFuture = widget.attendanceRepository.getMyAttendance();
    } catch (_) {
      recordsFuture = Future.value([]);
    }

    final results = await Future.wait([
      overallFuture,
      subjectsFuture,
      recordsFuture,
    ]);

    if (!mounted) return;

    setState(() {
      _overall = results[0] as AttendancePercentage?;
      _overallLoading = false;
      _overallError = null;

      _subjects = results[1] as List<SubjectAttendance>;
      _subjectsLoading = false;
      _subjectsError = null;

      _records = results[2] as List<AttendanceRecord>;
      _recordsLoading = false;

      _loading = false;
    });
  }

  Future<void> _retry() async {
    setState(() {
      _overallLoading = true;
      _subjectsLoading = true;
      _recordsLoading = true;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: DagacsSpace.lg),
        child: AppLoadingState(message: 'Loading attendance summary...'),
      );
    }

    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _retry);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (_overallLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_overallError != null)
            Column(
              children: [
                Text(_overallError!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _retry, child: const Text('Retry')),
              ],
            )
          else if (_overall != null)
            AttendanceSummaryCards(
              overall: _overall,
              loading: false,
              error: null,
              onRetry: _retry,
              showViewFullAttendance: true,
            ),
          if (_subjectsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_subjectsError != null)
            Text(_subjectsError!, style: const TextStyle(color: Colors.red)),
          if (_subjects.isNotEmpty && !_subjectsLoading)
            AttendanceSubjectChart(
              subjects: _subjects,
              loading: false,
              error: _subjectsError,
              onRetry: _retry,
            ),
          if (_recordsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          if (_records.isNotEmpty && !_recordsLoading)
            RecentAttendanceList(
              records: _records,
              subjectNamesById: subjectNamesById,
            ),
        ],
      ),
    );
  }
}
