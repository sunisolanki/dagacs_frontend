import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/session/session_controller.dart';
import '../../models/hod_student_attendance.dart';
import '../../network/api_exception.dart';
import '../../repositories/hod_attendance_repository.dart';
import '../../repositories/hod_repository.dart';
import '../../services/hod_hierarchy_loader.dart';
import '../../widgets/hod/hod_common.dart';
import '../../widgets/hod/hod_scaffold.dart';

/// Per-student attendance, migrated from the previous HOD dashboard's
/// "Students" tab onto its own route. Data source and date filter unchanged.
///
/// When [attendanceRepository] is supplied, a row that carries a verified
/// student id becomes tappable and opens that student's subject-wise attendance
/// detail in the current academic context. The drill-down is only offered when
/// the backend actually identified the student, so the UI never guesses an id.
class HodStudentsScreen extends StatefulWidget {
  const HodStudentsScreen({
    super.key,
    required this.hodRepository,
    required this.session,
    required this.academicContext,
    this.hierarchyLoader,
    this.attendanceRepository,
    this.onOpenStudent,
  });

  final HodRepository hodRepository;
  final SessionController session;
  final HodAcademicContext academicContext;

  /// Supplies the real academic hierarchy to the context bar.
  final HodHierarchyLoader? hierarchyLoader;

  /// Enables the subject-wise attendance drill-down. Optional so a host without
  /// it keeps the previous list-only behaviour.
  final HodAttendanceRepository? attendanceRepository;

  final ValueChanged<int>? onOpenStudent;

  @override
  State<HodStudentsScreen> createState() => _HodStudentsScreenState();
}

class _HodStudentsScreenState extends State<HodStudentsScreen> {
  static const String _errorCopy = 'Failed to load data.';

  bool _loading = true;
  String? _error;
  List<HodStudentAttendance> _students = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.academicContext.datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = widget.academicContext;
      final data = await widget.hodRepository.getStudents(
        startDate: ctx.startDate,
        endDate: ctx.endDate,
        academicSessionId: ctx.academicSessionId,
        programId: ctx.programId,
        semesterId: ctx.semesterId,
        sectionId: ctx.sectionId,
      );
      if (!mounted) return;
      setState(() {
        _students = data;
        _loading = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _error = _errorCopy;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _errorCopy;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return HodScaffold(
      session: widget.session,
      academicContext: widget.academicContext,
      title: 'Students',
      subtitle: 'Student-wise attendance across your department.',
      icon: Icons.people_outline,
      onRangeChanged: _load,
      hierarchyLoader: widget.hierarchyLoader,
      onContextChanged: _load,
      body: HodListPanel(
        loading: _loading,
        errorMessage: _error,
        onRetry: _load,
        emptyMessage: 'No student data yet.',
        loadingMessage: 'Loading students...',
        showScopeNotice: !widget.academicContext.hasAcademicContext,
        itemCount: _students.length,
        itemBuilder: (context, index) {
          final s = _students[index];
          final canDrillDown =
              widget.attendanceRepository != null &&
                  widget.onOpenStudent != null &&
                  s.studentId != null;
          return ListTile(
            leading: const Icon(Icons.person),
            title: Text('${s.studentName} (${s.rollNumber})'),
            subtitle: Text([
              if (s.enrollmentNumber != null && s.enrollmentNumber!.isNotEmpty)
                'Enrollment: ${s.enrollmentNumber}',
              if (s.hasAcademicContext)
                '${s.programName} · ${s.semesterName} · ${s.sectionName}',
              if (!s.hasAcademicContext) s.sectionName,
              '${s.presentCount} / ${s.totalRecordedCount} recorded',
            ].join(' · ')),
            trailing: Text(
              formatHodPercentage(s.percentage),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: hodPercentageColor(s.percentage),
                  ),
            ),
            // Only offered when the backend identified the student in this
            // context, so no drill-down can target a guessed or foreign id.
            onTap: canDrillDown ? () => widget.onOpenStudent!(s.studentId!) : null,
          );
        },
      ),
    );
  }
}
