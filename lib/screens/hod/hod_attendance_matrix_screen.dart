import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/dagacs_theme.dart';
import '../../network/api_exception.dart';
import '../../repositories/hod_attendance_repository.dart';
import '../../services/hod_hierarchy_loader.dart';
import '../../services/report_file_downloader.dart';
import '../../widgets/report_widgets.dart';
import '../../widgets/hod/hod_attendance_panels.dart';
import '../../widgets/hod/hod_export_bar.dart';
import '../../widgets/hod/hod_scaffold.dart';

/// The HOD attendance matrix as a first-class route.
///
/// The same [HodAttendanceMatrixPanel] backs this route and the "Attendance
/// Matrix" section of the Reports screen, so the wide cross-tab is reachable
/// directly and can never drift between the two entry points.
///
/// Excel and PDF are real downloads of the same cross-tab the table shows: the
/// export is produced by the backend from the identical data model and is
/// always unpaged, so the file contains every row of the selected context.
class HodAttendanceMatrixScreen extends StatefulWidget {
  const HodAttendanceMatrixScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.academicContext,
    this.hierarchyLoader,
    this.downloadFile = downloadReportFile,
  });

  final HodAttendanceRepository repository;
  final SessionController session;
  final HodAcademicContext academicContext;
  final HodHierarchyLoader? hierarchyLoader;

  /// Injected so the download can be asserted without touching the platform.
  final ReportFileDownloader downloadFile;

  @override
  State<HodAttendanceMatrixScreen> createState() =>
      _HodAttendanceMatrixScreenState();
}

class _HodAttendanceMatrixScreenState extends State<HodAttendanceMatrixScreen> {
  /// Bumped on every context or date change; the panel refetches when it moves.
  int _reloadToken = 0;
  bool _exporting = false;

  /// False until the matrix has loaded, so a download can never be triggered for
  /// a context the table is not yet showing.
  bool _exportReady = false;

  bool get _hasContext =>
      widget.academicContext.academicSessionId != null &&
      widget.academicContext.programId != null &&
      widget.academicContext.semesterId != null &&
      widget.academicContext.sectionId != null;

  void _reload() => setState(() {
        _reloadToken++;
        _exportReady = false;
      });

  /// Downloads the cross-tab. The date range is sent so the file matches exactly
  /// what the table is showing.
  Future<String> _export(String format) async {
    if (!_hasContext) {
      throw StateError(HodAttendanceRepository.matrixContextRequiredMessage);
    }
    final ctx = widget.academicContext;
    final payload = await widget.repository.exportMatrix(
      format,
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

  @override
  Widget build(BuildContext context) {
    return HodScaffold(
      session: widget.session,
      academicContext: widget.academicContext,
      title: 'Attendance Matrix',
      subtitle: 'Student x subject attendance cross-tab for the selected context.',
      icon: Icons.table_chart_outlined,
      onRangeChanged: _reload,
      hierarchyLoader: widget.hierarchyLoader,
      onContextChanged: _reload,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DagacsSpace.md, DagacsSpace.sm, DagacsSpace.md, DagacsSpace.sm),
            // Phase 4A: the same professional control as every other HOD report,
            // with its own idle/generating/success/failure states. Duplicate
            // clicks are blocked and the selected context is preserved.
            child: HodExportBar(
              enabled: _hasContext && _exportReady,
              disabledReason: _hasContext
                  ? 'The matrix is still loading.'
                  : HodAttendanceRepository.matrixContextRequiredMessage,
              onExport: (format) => _export(format.name),
            ),
          ),
          Expanded(
            child: HodAttendanceMatrixPanel(
              repository: widget.repository,
              academicContext: widget.academicContext,
              reloadToken: _reloadToken,
              onReportLoaded: () => setState(() => _exportReady = true),
            ),
          ),
        ],
      ),
    );
  }
}
