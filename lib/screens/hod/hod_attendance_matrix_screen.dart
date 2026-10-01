import 'package:flutter/material.dart';

import '../../core/context/hod_academic_context.dart';
import '../../core/hod_report_export_kind.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/dagacs_theme.dart';
import '../../repositories/hod_attendance_repository.dart';
import '../../services/hod_hierarchy_loader.dart';
import '../../services/report_file_downloader.dart';
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

  /// False until the matrix has loaded, so a download can never be triggered for
  /// a context the table is not yet showing.
  bool _exportReady = false;

  /// True while a file is being generated; locks the academic context.
  bool _exportBusy = false;

  /// The context the table on screen was actually loaded for.
  ///
  /// <b>Phase 4A.</b> The export used to read the live academic context at click
  /// time, so switching section between a load and an export produced a file for
  /// the <i>new</i> section while the table still showed the <i>old</i> one.
  /// Exporting the snapshot the table was rendered from makes that impossible.
  HodExportContext? _loadedContext;

  bool get _hasContext =>
      widget.academicContext.academicSessionId != null &&
      widget.academicContext.programId != null &&
      widget.academicContext.semesterId != null &&
      widget.academicContext.sectionId != null;

  void _reload() => setState(() {
        _reloadToken++;
        _exportReady = false;
        _loadedContext = null;
      });

  /// Downloads the cross-tab, for the exact context the table is showing.
  Future<String> _export(String format) async {
    final ctx = _loadedContext;
    if (!_hasContext || ctx == null) {
      throw StateError(
          widget.academicContext.datesInvalid
              ? 'Start date must not be after end date.'
              : HodAttendanceRepository.matrixContextRequiredMessage);
    }
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
      // Locked for the duration of a generation so the section cannot change
      // while a file is being produced for it.
      controlsEnabled: !_exportBusy,
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
              reportLabel: HodReportExportKind.matrix.label,
              onBusyChanged: (busy) {
                if (mounted) setState(() => _exportBusy = busy);
              },
              onExport: (format) => _export(format.name),
            ),
          ),
          Expanded(
            child: HodAttendanceMatrixPanel(
              repository: widget.repository,
              academicContext: widget.academicContext,
              reloadToken: _reloadToken,
              onReportLoaded: _captureLoadedContext,
            ),
          ),
        ],
      ),
    );
  }

  /// Snapshots the context the panel has just successfully loaded.
  void _captureLoadedContext() {
    if (!mounted) return;
    final ctx = widget.academicContext;
    setState(() {
      _exportReady = true;
      _loadedContext = HodExportContext(
        academicSessionId: ctx.academicSessionId,
        programId: ctx.programId,
        semesterId: ctx.semesterId,
        sectionId: ctx.sectionId,
        subjectId: ctx.subjectId,
        startDate: ctx.startDate,
        endDate: ctx.endDate,
      );
    });
  }
}
