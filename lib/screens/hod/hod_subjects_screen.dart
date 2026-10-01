import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/session/session_controller.dart';
import '../../models/hod_subject_attendance.dart';
import '../../network/api_exception.dart';
import '../../repositories/hod_attendance_repository.dart';
import '../../repositories/hod_repository.dart';
import '../../services/hod_hierarchy_loader.dart';
import '../../widgets/hod/hod_common.dart';
import '../../widgets/hod/hod_scaffold.dart';

/// Subject-wise attendance, migrated from the previous HOD dashboard's
/// "Subjects" tab onto its own route. Data source and date filter unchanged.
///
/// When [attendanceRepository] is supplied, a row that carries a verified subject
/// id becomes tappable and opens that subject's student-wise attendance detail
/// in the current academic context.
class HodSubjectsScreen extends StatefulWidget {
  const HodSubjectsScreen({
    super.key,
    required this.hodRepository,
    required this.session,
    required this.academicContext,
    this.hierarchyLoader,
    this.attendanceRepository,
    this.onOpenSubject,
  });

  final HodRepository hodRepository;
  final SessionController session;
  final HodAcademicContext academicContext;

  /// Supplies the real academic hierarchy to the context bar.
  final HodHierarchyLoader? hierarchyLoader;

  /// Enables the student-wise attendance drill-down. Optional so a host without
  /// it keeps the previous list-only behaviour.
  final HodAttendanceRepository? attendanceRepository;

  final ValueChanged<int>? onOpenSubject;

  @override
  State<HodSubjectsScreen> createState() => _HodSubjectsScreenState();
}

class _HodSubjectsScreenState extends State<HodSubjectsScreen> {
  static const String _errorCopy = 'Failed to load data.';

  bool _loading = true;
  String? _error;
  List<HodSubjectAttendance> _subjects = [];

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
      final data = await widget.hodRepository.getSubjects(
        startDate: ctx.startDate,
        endDate: ctx.endDate,
        academicSessionId: ctx.academicSessionId,
        programId: ctx.programId,
        semesterId: ctx.semesterId,
        sectionId: ctx.sectionId,
      );
      if (!mounted) return;
      setState(() {
        _subjects = data;
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

  /// Faculty names for [subject] when a section is selected and the hierarchy
  /// supplied them. Empty otherwise — never invented.
  List<String> _facultyFor(HodSubjectAttendance subject) {
    final semesterId = widget.academicContext.semesterId;
    final loader = widget.hierarchyLoader;
    if (semesterId == null || loader == null) return const [];
    return loader
        .subjectsWithFaculty(semesterId: semesterId)
        .where((s) => s.code == subject.subjectCode)
        .expand((s) => s.facultyNames)
        .toSet()
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return HodScaffold(
      session: widget.session,
      academicContext: widget.academicContext,
      title: 'Subjects',
      subtitle: 'Subject-wise attendance across your department.',
      icon: Icons.book_outlined,
      onRangeChanged: _load,
      hierarchyLoader: widget.hierarchyLoader,
      onContextChanged: _load,
      body: HodListPanel(
        loading: _loading,
        errorMessage: _error,
        onRetry: _load,
        emptyMessage: 'No subject data yet.',
        loadingMessage: 'Loading subjects...',
        showScopeNotice: !widget.academicContext.hasAcademicContext,
        itemCount: _subjects.length,
        itemBuilder: (context, index) {
          final s = _subjects[index];
          final faculty = _facultyFor(s);
          final canDrillDown =
              widget.attendanceRepository != null &&
                  widget.onOpenSubject != null &&
                  s.subjectId != null;
          return ListTile(
            leading: const Icon(Icons.book),
            title: Text('${s.subjectName} (${s.subjectCode})'),
            subtitle: Text([
              if (s.hasAcademicContext) ...[
                s.programName ?? '-',
                s.semesterName ?? '-',
              ],
              '${s.presentCount} present / ${s.totalRecordedCount} recorded',
              if (faculty.isNotEmpty) 'Faculty: ${faculty.join(', ')}',
            ].join(' · ')),
            trailing: Text(
              formatHodPercentage(s.percentage),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: hodPercentageColor(s.percentage),
                  ),
            ),
            // Only offered when the backend identified the subject in this
            // context, so no drill-down can target a guessed or foreign id.
            onTap:
                canDrillDown ? () => widget.onOpenSubject!(s.subjectId!) : null,
          );
        },
      ),
    );
  }
}
