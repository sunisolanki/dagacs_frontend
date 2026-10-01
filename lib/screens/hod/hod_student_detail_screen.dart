import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/dagacs_theme.dart';
import '../../models/hod_student_attendance_detail.dart';
import '../../network/api_exception.dart';
import '../../repositories/hod_attendance_repository.dart';
import '../../services/hod_hierarchy_loader.dart';
import '../../services/report_file_downloader.dart';
import '../../widgets/attendance_summary_cards.dart';
import '../../widgets/dagacs_widgets.dart';
import '../../widgets/hod/hod_common.dart';
import '../../widgets/hod/hod_export_bar.dart';
import '../../widgets/hod/hod_scaffold.dart';

/// One student's attendance detail, inside the currently selected HOD academic
/// context.
///
/// The context travels with the request, so the detail can never describe a
/// different semester or section than the one the HOD is looking at. Changing
/// the student id in the request yields 403 with no data: the server proves the
/// student belongs to the authenticated HOD's department *and* to this exact
/// context before it runs a single query.
class HodStudentDetailScreen extends StatefulWidget {
  const HodStudentDetailScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.academicContext,
    required this.studentId,
    this.hierarchyLoader,
    this.downloadFile = downloadReportFile,
  });

  final HodAttendanceRepository repository;
  final SessionController session;
  final HodAcademicContext academicContext;

  /// The student to open. Taken from the tapped row, never typed in by hand.
  final int studentId;

  final HodHierarchyLoader? hierarchyLoader;

  /// Injected so a download can be asserted without touching the platform.
  final ReportFileDownloader downloadFile;

  @override
  State<HodStudentDetailScreen> createState() => _HodStudentDetailScreenState();
}

class _HodStudentDetailScreenState extends State<HodStudentDetailScreen> {
  static const String _errorCopy = 'Failed to load the student attendance detail.';

  bool _loading = true;
  String? _error;
  bool _scopeViolation = false;
  HodStudentAttendanceDetail? _detail;

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
      _scopeViolation = false;
    });
    try {
      final ctx = widget.academicContext;
      final detail = await widget.repository.getStudentDetail(
        studentId: widget.studentId,
        academicSessionId: ctx.academicSessionId,
        programId: ctx.programId,
        semesterId: ctx.semesterId,
        sectionId: ctx.sectionId,
        subjectId: ctx.subjectId,
        startDate: ctx.startDate,
        endDate: ctx.endDate,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // 403 is a scope violation, not a generic failure. It is reported
        // without a retry affordance, because retrying cannot make a student
        // from another context become part of this one.
        _scopeViolation = e.statusCode == 403;
        _error = _scopeViolation
            ? 'This student is outside the selected academic context.'
            : _errorCopy;
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
      title: 'Student Attendance',
      subtitle: 'Subject-wise attendance of one student in this context.',
      icon: Icons.person_search_outlined,
      onRangeChanged: _load,
      hierarchyLoader: widget.hierarchyLoader,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DagacsSpace.md, DagacsSpace.sm, DagacsSpace.md, 0),
            child: HodExportBar(
              // Phase 4A: this screen is the only place a single student's
              // report can be filed, because only here is one student in focus.
              enabled: _detail != null && !_loading,
              disabledReason: _detail == null
                  ? 'The student report is still loading.'
                  : null,
              onExport: (format) => _export(format.name),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// Exports this student's report, using the context the loaded detail belongs
  /// to. The report is the same data the screen shows, from the same endpoint.
  Future<String> _export(String format) async {
    final ctx = widget.academicContext;
    final payload = await widget.repository.exportStudent(
      format,
      studentId: widget.studentId,
      academicSessionId: ctx.academicSessionId,
      programId: ctx.programId,
      semesterId: ctx.semesterId,
      sectionId: ctx.sectionId,
      subjectId: ctx.subjectId,
      startDate: ctx.startDate,
      endDate: ctx.endDate,
    );
    return widget.downloadFile(
        payload.bytes, payload.fileName, payload.contentType);
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(message: 'Loading student attendance...');
    }
    if (_error != null) {
      if (_scopeViolation) return HodScopeViolationView(message: _error!);
      return HodErrorView(message: _error!, onRetry: _load);
    }
    final detail = _detail;
    if (detail == null) {
      return HodErrorView(message: 'No student data.', onRetry: _load);
    }
    if (detail.subjects.isEmpty) {
      return const HodEmptyView(
          message: 'No subjects are offered in the selected semester.');
    }

    return SingleChildScrollView(
      key: const Key('hod-student-detail'),
      padding: const EdgeInsets.fromLTRB(
          DagacsSpace.md, DagacsSpace.sm, DagacsSpace.md, DagacsSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _identityCard(detail),
          const SizedBox(height: DagacsSpace.lg),
          _subjectsCard(detail),
        ],
      ),
    );
  }

  Widget _identityCard(HodStudentAttendanceDetail detail) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.studentName,
              key: const Key('hod-student-detail-name'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: DagacsSpace.xs),
          Text(
            [
              'Enrollment: ${detail.identity}',
              if (detail.programName != null) detail.programName!,
              if (detail.semesterName != null) detail.semesterName!,
              if (detail.sectionName != null) detail.sectionName!,
            ].join(' · '),
            style: DagacsTextStyles.caption,
          ),
          const SizedBox(height: DagacsSpace.md),
          Row(
            children: [
              Text(
                '${detail.totalPresent} / ${detail.totalClasses}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(width: DagacsSpace.md),
              Text(
                formatHodPercentage(detail.overallPercentage),
                key: const Key('hod-student-detail-overall'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AttendanceSummaryCards.bandColor(
                          detail.overallPercentage),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subjectsCard(HodStudentAttendanceDetail detail) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subject-wise attendance',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DagacsSpace.sm),
          for (final subject in detail.subjects)
            Padding(
              padding: const EdgeInsets.only(bottom: DagacsSpace.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 108,
                    child: Text(
                      subject.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DagacsTextStyles.body,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      subject.subjectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DagacsTextStyles.caption,
                    ),
                  ),
                  Tooltip(
                    message: '${subject.present} present · '
                        '${subject.notAttended} not attended of '
                        '${subject.classes} conducted',
                    child: Text(
                      '${subject.present} / ${subject.classes}',
                      key: Key('hod-student-detail-subject-${subject.subjectId}'),
                      style: DagacsTextStyles.body,
                    ),
                  ),
                  const SizedBox(width: DagacsSpace.md),
                  SizedBox(
                    width: 76,
                    child: Text(
                      formatHodPercentage(subject.percentage),
                      textAlign: TextAlign.right,
                      style: DagacsTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AttendanceSummaryCards.bandColor(
                            subject.percentage),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
