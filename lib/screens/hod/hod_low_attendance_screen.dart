import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/dagacs_theme.dart';
import '../../models/hod_low_attendance.dart';
import '../../network/api_exception.dart';
import '../../repositories/hod_attendance_repository.dart';
import '../../repositories/hod_repository.dart';
import '../../services/hod_hierarchy_loader.dart';
import '../../services/report_file_downloader.dart';
import '../../widgets/dagacs_widgets.dart';
import '../../widgets/hod/hod_attendance_panels.dart';
import '../../widgets/hod/hod_common.dart';
import '../../widgets/hod/hod_export_bar.dart';
import '../../widgets/hod/hod_scaffold.dart';

/// Students below the fixed 75% threshold, migrated from the previous HOD
/// dashboard's "Low Attendance" tab onto its own route.
///
/// The threshold remains the backend's fixed 75.0% rule; nothing about the
/// calculation changes here.
///
/// When [attendanceRepository] is supplied, a complete academic context switches
/// the body to [HodLowAttendancePanel], which additionally names the subjects
/// responsible for each student. Those subject percentages come from the same
/// backend aggregate as the matrix cells, so the breakdown can never disagree
/// with the cross-tab.
class HodLowAttendanceScreen extends StatefulWidget {
  const HodLowAttendanceScreen({
    super.key,
    required this.hodRepository,
    required this.session,
    required this.academicContext,
    this.hierarchyLoader,
    this.attendanceRepository,
    this.onOpenStudent,
    this.downloadFile = downloadReportFile,
  });

  final HodRepository hodRepository;
  final SessionController session;
  final HodAcademicContext academicContext;
  final HodHierarchyLoader? hierarchyLoader;

  /// Enables the subject-level breakdown. Optional so a host without it keeps
  /// the previous list-only behaviour.
  final HodAttendanceRepository? attendanceRepository;

  final ValueChanged<int>? onOpenStudent;

  /// Injected so a download can be asserted without touching the platform.
  final ReportFileDownloader downloadFile;

  @override
  State<HodLowAttendanceScreen> createState() => _HodLowAttendanceScreenState();
}

class _HodLowAttendanceScreenState extends State<HodLowAttendanceScreen> {
  static const String _errorCopy = 'Failed to load low-attendance students.';

  bool _loading = true;
  String? _error;
  List<HodLowAttendance> _students = [];

  /// Bumped on every academic-context change so the panel refetches.
  int _contextReloadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.academicContext.datesInvalid) return;
    // The context panel owns its own request; this list is only the fallback
    // for a partial context or a host without the Phase 3 repository.
    if (_usesContextPanel) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = widget.academicContext;
      final data = await widget.hodRepository.getLowAttendance(
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
      title: 'Low Attendance',
      subtitle: 'Students below the attendance threshold.',
      icon: Icons.warning_amber_outlined,
      onRangeChanged: _load,
      hierarchyLoader: widget.hierarchyLoader,
      onContextChanged: _onContextChanged,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DagacsSpace.md, DagacsSpace.sm, DagacsSpace.md, 0),
            // Phase 4A: the context report can be filed from its own route as
            // well as from the Reports hub. The legacy department-wide feed keeps
            // its existing controls and gains none.
            child: _usesContextPanel
                ? HodExportBar(
                    enabled: _contextReportLoaded,
                    disabledReason: 'The low-attendance report is still loading.',
                    onExport: (format) => _exportContextReport(format.name),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: _usesContextPanel
                ? HodLowAttendancePanel(
                    repository: widget.attendanceRepository!,
                    academicContext: widget.academicContext,
                    reloadToken: _contextReloadToken,
                    onOpenStudent: widget.onOpenStudent,
                    onReportLoaded: _onContextReportLoaded,
                  )
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  bool _contextReportLoaded = false;

  void _onContextReportLoaded() => setState(() => _contextReportLoaded = true);

  /// Exports the canonical low-attendance report for the selected context.
  Future<String> _exportContextReport(String format) async {
    final ctx = widget.academicContext;
    final payload = await widget.attendanceRepository!.exportLowAttendance(
      format,
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

  /// The subject breakdown is only offered for a fully-resolved context: without
  /// one the report would be department-wide and its "subjects responsible" list
  /// would span unrelated semesters, which would be misleading.
  bool get _usesContextPanel =>
      widget.attendanceRepository != null &&
      widget.academicContext.academicSessionId != null &&
      widget.academicContext.programId != null &&
      widget.academicContext.semesterId != null &&
      widget.academicContext.sectionId != null;

  void _onContextChanged() {
    setState(() {
      _contextReloadToken++;
      // A new context must not be exportable until it has actually loaded.
      _contextReportLoaded = false;
    });
    if (_usesContextPanel) return;
    _load();
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(message: 'Loading low-attendance students...');
    }
    if (_error != null) {
      return HodErrorView(message: _error!, onRetry: _load);
    }
    return ListView(
      key: const Key('hod-list'),
      padding: const EdgeInsets.only(bottom: DagacsSpace.lg),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            DagacsSpace.md,
            DagacsSpace.sm,
            DagacsSpace.md,
            DagacsSpace.sm,
          ),
          child: Text(
            'Students below the fixed 75.0% attendance threshold.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(
            DagacsSpace.md,
            0,
            DagacsSpace.md,
            DagacsSpace.sm,
          ),
          child: HodScopeNotice(),
        ),
        if (_students.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                SizedBox(height: 16),
                Text('No students below the threshold.'),
              ],
            ),
          )
        else
          for (final s in _students)
            ListTile(
              leading: const Icon(Icons.warning_amber),
              title: Text('${s.studentName} (${s.rollNumber})'),
              subtitle: Text([
                if (s.enrollmentNumber != null && s.enrollmentNumber!.isNotEmpty)
                  'Enrollment: ${s.enrollmentNumber}',
                if (s.hasAcademicContext)
                  '${s.programName} · ${s.semesterName} · ${s.sectionName}'
                else
                  s.sectionName,
                '${s.presentCount} / ${s.totalRecordedCount} recorded',
              ].join(' · ')),
              trailing: Text(
                formatHodPercentage(s.percentage),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: hodPercentageColor(s.percentage),
                    ),
              ),
            ),
      ],
    );
  }
}
