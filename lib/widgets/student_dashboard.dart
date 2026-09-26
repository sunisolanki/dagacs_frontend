import 'package:flutter/material.dart';

import '../models/attendance_percentage.dart';
import '../models/subject_attendance.dart';
import '../models/attendance_record.dart';
import '../repositories/attendance_repository.dart';
import '../core/navigation/navigator.dart';
import '../core/theme/dagacs_theme.dart';
import '../widgets/attendance_summary_cards.dart';
import '../widgets/recent_attendance_list.dart';
import '../widgets/subject_attendance_bars.dart';
import '../widgets/dagacs_widgets.dart';

/// Student home dashboard: live attendance at a glance.
///
/// Loads once and derives the overall summary, subject statistics and recent
/// attendance from three existing student-scoped endpoints. The backend
/// resolves the student from the JWT, so no identity is supplied here.
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

    // Nothing recorded at all: one clean empty state rather than three empty
    // sections, and the CTA to the full view stays reachable.
    if (_overall == null && _subjects.isEmpty && _records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DagacsSpace.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppEmptyState(
              icon: Icons.event_busy_outlined,
              message: 'No attendance records yet',
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: DagacsSpace.xl),
              child: SizedBox(
                width: 260,
                child: AppPrimaryButton(
                  onPressed: () => Navigator.pushNamed(
                      context, AppRoutes.studentAttendance),
                  child: const Text('View Full Attendance →'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            DagacsSpace.lg, 0, DagacsSpace.lg, DagacsSpace.xl),
        children: [
          // 1. Overall attendance hero - the dominant signal.
          _Reveal(index: 0, child: _buildOverallSection()),
          const SizedBox(height: DagacsSpace.md),
          // 2. Subject-wise attendance.
          _Reveal(index: 1, child: _buildSubjectSection()),
          const SizedBox(height: DagacsSpace.md),
          // 3. Recent attendance.
          _Reveal(index: 2, child: _buildRecentSection()),
        ],
      ),
    );
  }

  Widget _buildOverallSection() {
    if (_overallLoading) {
      return const _SectionSkeleton(lines: 3);
    }
    if (_overallError != null) {
      return _SectionShell(
        title: 'Overall Attendance',
        icon: Icons.insights_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_overallError!,
                style: const TextStyle(color: DagacsColors.error)),
            const SizedBox(height: DagacsSpace.sm),
            OutlinedButton(onPressed: _retry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_overall == null) {
      return _SectionShell(
        title: 'Overall Attendance',
        icon: Icons.insights_outlined,
        child: const Text(
          'No attendance records yet',
          style: TextStyle(color: DagacsColors.textSecondary),
        ),
      );
    }
    return AttendanceSummaryCards(
      overall: _overall,
      loading: false,
      error: null,
      onRetry: _retry,
      showViewFullAttendance: true,
    );
  }

  Widget _buildSubjectSection() {
    if (_subjectsLoading) {
      return const _SectionSkeleton(lines: 4);
    }
    if (_subjectsError != null) {
      return _SectionShell(
        title: 'Subject Attendance',
        icon: Icons.bar_chart_outlined,
        child: Text(_subjectsError!,
            style: const TextStyle(color: DagacsColors.error)),
      );
    }
    if (_subjects.isEmpty) {
      return _SectionShell(
        title: 'Subject Attendance',
        icon: Icons.bar_chart_outlined,
        child: const Text(
          'No attendance records yet',
          style: TextStyle(color: DagacsColors.textSecondary),
        ),
      );
    }
    return _SectionShell(
      title: 'Subject Attendance',
      icon: Icons.bar_chart_outlined,
      child: SubjectAttendanceBars(subjects: _subjects),
    );
  }

  Widget _buildRecentSection() {
    if (_recordsLoading) {
      return const _SectionSkeleton(lines: 3);
    }
    if (_records.isEmpty) {
      return _SectionShell(
        title: 'Recent Attendance',
        icon: Icons.history,
        child: const Text(
          'No attendance records yet',
          style: TextStyle(color: DagacsColors.textSecondary),
        ),
      );
    }
    return RecentAttendanceList(
      records: _records,
      subjectNamesById: subjectNamesById,
    );
  }
}

/// Section heading + content, used for the non-hero blocks so the dashboard
/// does not read as a stack of unrelated floating cards.
class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: icon,
                color: DagacsColors.brandPrimary,
                backgroundColor: DagacsColors.brandSoft,
                size: 32,
              ),
              const SizedBox(width: DagacsSpace.md),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DagacsSpace.md),
          child,
        ],
      ),
    );
  }
}

/// Static placeholder block shown while a section loads. Matches the final
/// geometry closely so the dashboard does not jump when content arrives.
class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton({required this.lines});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 148,
            height: 16,
            decoration: BoxDecoration(
              color: DagacsColors.surfaceAlt,
              borderRadius: BorderRadius.circular(DagacsRadius.sm),
            ),
          ),
          const SizedBox(height: DagacsSpace.lg),
          for (var i = 0; i < lines; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: DagacsSpace.sm),
              child: Container(
                height: 12,
                width: i.isEven ? double.infinity : 180,
                decoration: BoxDecoration(
                  color: DagacsColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(DagacsRadius.sm),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Staggered fade + slide entrance. Matches the house motion used by the
/// login and change-password screens; decorative only, so all content stays
/// present for assistive technology.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + 60 * index),
      curve: Interval(
        (60 * index) / (360 + 60 * index),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
