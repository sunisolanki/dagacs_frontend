import 'package:flutter/material.dart';

import '../core/navigation/navigator.dart';
import '../core/theme/dagacs_theme.dart';
import '../models/attendance_session.dart';
import '../models/teacher_assignment.dart';
import '../network/api_exception.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/teacher_repository.dart';
import '../widgets/dagacs_widgets.dart';

/// Teacher home dashboard.
///
/// An orchestration layer: it surfaces the teacher's own classes, attendance
/// sessions and report entry points using two existing JWT-scoped endpoints.
/// It deliberately does NOT reimplement My Classes or Attendance Sessions - it
/// links into those screens.
class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({
    super.key,
    required this.teacherRepository,
    required this.attendanceRepository,
  });

  final TeacherRepository teacherRepository;
  final AttendanceRepository attendanceRepository;

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  bool _loading = true;
  String? _error;
  List<TeacherAssignment> _assignments = const [];
  List<AttendanceSession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Both calls are self-scoped server-side; no teacher id is sent.
      final results = await Future.wait([
        widget.teacherRepository.getMyAssignments(),
        widget.attendanceRepository.getSessions(),
      ]);
      if (!mounted) return;
      setState(() {
        _assignments = results[0] as List<TeacherAssignment>;
        _sessions = results[1] as List<AttendanceSession>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userMessageFor(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while loading your dashboard.';
        _loading = false;
      });
    }
  }

  int get _conductedCount =>
      _sessions.where((s) => s.status == 'CONDUCTED').length;

  int get _scheduledCount =>
      _sessions.where((s) => s.status == 'SCHEDULED').length;

  /// Most recent sessions first.
  List<AttendanceSession> get _recentSessions {
    final sorted = List<AttendanceSession>.from(_sessions)
      ..sort((a, b) {
        final byDate = (b.date ?? '').compareTo(a.date ?? '');
        return byDate != 0 ? byDate : (b.id ?? 0).compareTo(a.id ?? 0);
      });
    return sorted.take(4).toList();
  }

  String _classLabel(TeacherAssignment a) {
    final subject =
        '${a.subjectCode ?? ''} ${a.subjectName ?? ''}'.trim();
    final klass = (a.sectionName?.trim().isNotEmpty == true)
        ? a.sectionName!.trim()
        : (a.batchCode?.trim() ?? '');
    return [subject, klass].where((p) => p.isNotEmpty).join(' - ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: DagacsSpace.lg),
        child: AppLoadingState(message: 'Loading your dashboard...'),
      );
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }

    // Deliberately NOT scrollable: this widget is embedded in the home screen's
    // own ListView, and a nested viewport would be given unbounded height. The
    // host supplies the scrolling and the pull-to-refresh.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStats(),
        const SizedBox(height: DagacsSpace.lg),
        _buildClasses(),
        const SizedBox(height: DagacsSpace.lg),
        _buildRecentSessions(),
      ],
    );
  }

  Widget _buildStats() {
    return AppResponsiveGrid(
      crossAxisCount: 3,
      gap: DagacsSpace.sm,
      children: [
        _buildStatCard('Classes', _assignments.length, Icons.class_outlined),
        _buildStatCard(
            'Conducted', _conductedCount, Icons.event_available_outlined),
        _buildStatCard('Scheduled', _scheduledCount, Icons.schedule_outlined),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
          vertical: DagacsSpace.md, horizontal: DagacsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconBadge(
            icon: icon,
            color: DagacsColors.brandPrimary,
            backgroundColor: DagacsColors.brandSoft,
            size: 32,
          ),
          const SizedBox(height: DagacsSpace.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: DagacsColors.textPrimary,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DagacsColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClasses() {
    if (_assignments.isEmpty) {
      return _buildSection(
        key: const Key('teacher-dashboard-classes'),
        title: 'My Classes',
        icon: Icons.class_outlined,
        child: Text(
          'No classes assigned yet. Contact your administrator.',
          style: const TextStyle(color: DagacsColors.textSecondary),
        ),
      );
    }
    return _buildSection(
      key: const Key('teacher-dashboard-classes'),
      title: 'My Classes',
      icon: Icons.class_outlined,
      child: Column(
        children: [
          for (final a in _assignments.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: DagacsSpace.sm),
              child: _buildClassRow(a),
            ),
          if (_assignments.length > 3)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('teacher-dashboard-all-classes'),
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.teacherClasses),
                child: Text('View all ${_assignments.length} classes'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassRow(TeacherAssignment a) {
    final button = OutlinedButton.icon(
      key: Key('teacher-dashboard-take-attendance-${a.id}'),
      onPressed: () => Navigator.pushNamed(
          context, AppRoutes.createSession, arguments: a),
      icon: const Icon(Icons.event_available_outlined, size: 18),
      label: const Text('Take Attendance'),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          a.subjectName ?? 'Subject',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: DagacsColors.textPrimary,
          ),
        ),
        Text(
          _classLabel(a),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 12, color: DagacsColors.textSecondary),
        ),
      ],
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: DagacsSpace.md, vertical: DagacsSpace.md),
      // On a narrow phone the action cannot share the row with the label
      // without clipping, so it drops to its own full-width line.
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 380) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                details,
                const SizedBox(height: DagacsSpace.sm),
                button,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: DagacsSpace.sm),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentSessions() {
    if (_sessions.isEmpty) {
      return _buildSection(
        key: const Key('teacher-dashboard-sessions'),
        title: 'Attendance Sessions',
        icon: Icons.event_note_outlined,
        child: Text(
          'No attendance sessions yet.',
          style: const TextStyle(color: DagacsColors.textSecondary),
        ),
      );
    }
    return _buildSection(
      key: const Key('teacher-dashboard-sessions'),
      title: 'Attendance Sessions',
      icon: Icons.event_note_outlined,
      child: Column(
        children: [
          for (final s in _recentSessions)
            Padding(
              padding: const EdgeInsets.only(bottom: DagacsSpace.sm),
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: DagacsSpace.md, vertical: DagacsSpace.sm),
                onTap: s.id == null
                    ? null
                    : () => Navigator.pushNamed(
                        context, AppRoutes.markAttendance, arguments: s.id),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s.subjectName ?? "Subject"} - ${s.sectionName ?? s.batchName ?? "-"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            '${s.date ?? "-"} - ${s.lecturePeriod ?? "-"}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: DagacsColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DagacsSpace.sm),
                    AppStatusBadge(
                      label: s.status ?? 'UNKNOWN',
                      active: s.status == 'CONDUCTED',
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('teacher-dashboard-all-sessions'),
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.teacherAttendance),
              child: const Text('View all sessions'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required Key key,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return AppCard(
      key: key,
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
