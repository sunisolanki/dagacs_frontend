import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/dagacs_theme.dart';
import '../../models/hod_subject_attendance_detail.dart';
import '../../network/api_exception.dart';
import '../../repositories/hod_attendance_repository.dart';
import '../../services/hod_hierarchy_loader.dart';
import '../../services/report_file_downloader.dart';
import '../../widgets/attendance_summary_cards.dart';
import '../../widgets/dagacs_widgets.dart';
import '../../widgets/hod/hod_common.dart';
import '../../widgets/hod/hod_export_bar.dart';
import '../../widgets/hod/hod_scaffold.dart';

/// Attendance detail for one subject, inside the currently selected HOD academic
/// context.
///
/// The student list is the enrolled population of the context, not only the
/// students who happen to have marks, so a student who was never marked in this
/// subject is still listed — as `0 / 40` against the conducted classes, never as
/// a meaningless `0 / 0`. Faculty comes from the real teaching-assignment data
/// and is stated as unassigned when there is none — it is never invented.
class HodSubjectDetailScreen extends StatefulWidget {
  const HodSubjectDetailScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.academicContext,
    required this.subjectId,
    this.hierarchyLoader,
    this.downloadFile = downloadReportFile,
  });

  final HodAttendanceRepository repository;
  final SessionController session;
  final HodAcademicContext academicContext;

  /// The subject to open. Taken from the tapped row, never typed in by hand.
  final int subjectId;

  final HodHierarchyLoader? hierarchyLoader;

  /// Injected so a download can be asserted without touching the platform.
  final ReportFileDownloader downloadFile;

  @override
  State<HodSubjectDetailScreen> createState() => _HodSubjectDetailScreenState();
}

class _HodSubjectDetailScreenState extends State<HodSubjectDetailScreen> {
  static const String _errorCopy = 'Failed to load the subject attendance detail.';

  bool _loading = true;
  String? _error;
  bool _scopeViolation = false;
  HodSubjectAttendanceDetail? _detail;

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
      final detail = await widget.repository.getSubjectDetail(
        subjectId: widget.subjectId,
        academicSessionId: ctx.academicSessionId,
        programId: ctx.programId,
        semesterId: ctx.semesterId,
        sectionId: ctx.sectionId,
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
        // A scope violation is terminal: no retry affordance is offered.
        _scopeViolation = e.statusCode == 403;
        _error = _scopeViolation
            ? 'This subject is outside the selected academic context.'
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
      title: 'Subject Attendance',
      subtitle: 'Student-wise attendance of one subject in this context.',
      icon: Icons.menu_book_outlined,
      onRangeChanged: _load,
      hierarchyLoader: widget.hierarchyLoader,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DagacsSpace.md, DagacsSpace.sm, DagacsSpace.md, 0),
            child: HodExportBar(
              // Phase 4A: this screen is the only place a single subject's report
              // can be filed, because only here is one subject in focus.
              enabled: _detail != null && !_loading,
              disabledReason: _detail == null
                  ? 'The subject report is still loading.'
                  : null,
              onExport: (format) => _export(format.name),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// Exports this subject's report from the same endpoint the screen rendered.
  Future<String> _export(String format) async {
    final ctx = widget.academicContext;
    final payload = await widget.repository.exportSubject(
      format,
      subjectId: widget.subjectId,
      academicSessionId: ctx.academicSessionId,
      programId: ctx.programId,
      semesterId: ctx.semesterId,
      sectionId: ctx.sectionId,
      startDate: ctx.startDate,
      endDate: ctx.endDate,
    );
    return widget.downloadFile(
        payload.bytes, payload.fileName, payload.contentType);
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(message: 'Loading subject attendance...');
    }
    if (_error != null) {
      if (_scopeViolation) return HodScopeViolationView(message: _error!);
      return HodErrorView(message: _error!, onRetry: _load);
    }
    final detail = _detail;
    if (detail == null) {
      return HodErrorView(message: 'No subject data.', onRetry: _load);
    }

    return SingleChildScrollView(
      key: const Key('hod-subject-detail'),
      padding: const EdgeInsets.fromLTRB(
          DagacsSpace.md, DagacsSpace.sm, DagacsSpace.md, DagacsSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summaryCard(detail),
          const SizedBox(height: DagacsSpace.lg),
          _studentsCard(detail),
        ],
      ),
    );
  }

  Widget _summaryCard(HodSubjectAttendanceDetail detail) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${detail.label} — ${detail.subjectName}',
              key: const Key('hod-subject-detail-name'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: DagacsSpace.xs),
          Text(
            [
              if (detail.programName != null) detail.programName!,
              if (detail.semesterName != null) detail.semesterName!,
              if (detail.sectionName != null) detail.sectionName!,
            ].join(' · '),
            style: DagacsTextStyles.caption,
          ),
          const SizedBox(height: DagacsSpace.xs),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 16, color: DagacsColors.textSecondary),
              const SizedBox(width: DagacsSpace.xs),
              Expanded(
                child: Text(detail.facultyLabel,
                    key: const Key('hod-subject-detail-faculty'),
                    style: DagacsTextStyles.caption),
              ),
            ],
          ),
          const SizedBox(height: DagacsSpace.md),
          AppResponsiveGrid(
            crossAxisCount: 2,
            gap: DagacsSpace.md,
            children: [
              AppStatCard(
                icon: Icons.event_available_outlined,
                value: '${detail.totalClasses}',
                label: 'Classes Conducted',
              ),
              AppStatCard(
                icon: Icons.groups_outlined,
                value: '${detail.students}',
                label: 'Students',
              ),
              AppStatCard(
                icon: Icons.percent,
                value: formatHodPercentage(detail.averageAttendance),
                label: 'Average Attendance',
                valueColor: AttendanceSummaryCards.bandColor(
                    detail.averageAttendance),
              ),
              AppStatCard(
                icon: Icons.trending_down,
                value: '${detail.studentsBelowThreshold}',
                label: 'Below Threshold',
                valueColor: DagacsColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _studentsCard(HodSubjectAttendanceDetail detail) {
    if (detail.studentRows.isEmpty) {
      return const AppCard(
        child: Text('No students are enrolled in the selected academic context.'),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Student-wise attendance',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DagacsSpace.xs),
              Text('${detail.presentCount} / ${detail.totalClassesAcrossStudents} conducted',
              style: DagacsTextStyles.caption),
          const SizedBox(height: DagacsSpace.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              key: const Key('hod-subject-detail-table'),
              columns: const [
                DataColumn(label: Text('Enrollment No.')),
                DataColumn(label: Text('Student')),
                DataColumn(label: Text('Present'), numeric: true),
                DataColumn(label: Text('Total'), numeric: true),
                DataColumn(label: Text('Attendance %'), numeric: true),
              ],
              rows: [
                for (final row in detail.studentRows)
                  DataRow(
                    key: ValueKey('hod-subject-detail-student-${row.studentId}'),
                    cells: [
                      DataCell(Text(row.identity)),
                      DataCell(Text(row.studentName)),
                      DataCell(Text('${row.present}')),
                      DataCell(Text('${row.total}')),
                      DataCell(Text(formatHodPercentage(row.percentage))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
