import 'package:flutter/material.dart';

import '../core/context/hod_academic_context.dart';
import '../core/hod_report_export_kind.dart';
import '../core/session/session_controller.dart';
import '../core/theme/dagacs_theme.dart';
import '../models/hod_coverage_row.dart';
import '../models/hod_daily_lecture_row.dart';
import '../models/hod_low_attendance.dart';
import '../models/hod_rollup.dart';
import '../models/report_page.dart';
import '../network/api_exception.dart';
import '../repositories/hod_attendance_repository.dart';
import '../repositories/hod_repository.dart';
import '../repositories/report_repository.dart';
import '../services/hod_hierarchy_loader.dart';
import '../services/report_file_downloader.dart';
import '../widgets/hod/hod_attendance_panels.dart';
import '../widgets/hod/hod_common.dart';
import '../widgets/hod/hod_export_bar.dart';
import '../widgets/hod/hod_export_summary_strip.dart';
import '../widgets/hod/hod_scaffold.dart';
import '../widgets/report_widgets.dart';

/// The HOD reporting hub.
///
/// Two groups of reports share this screen:
///
/// 1. <b>Academic context reports</b> — the Phase 3 attendance intelligence:
///    overview, matrix, student attendance, subject attendance and low
///    attendance, all driven by the context bar above them and all served by
///    `/api/hod/attendance/**`. These are the reports a HOD uses to review one
///    academic context.
/// 2. <b>Department reports</b> — the pre-existing M7.1/M7.2 feeds and exports
///    (daily lecture, coverage, monthly, quarterly, low attendance). Their
///    behaviour, keys, pagination and exports are unchanged; Phase 3 only gives
///    them a home inside the hub.
///
/// <b>The department id is never selected.</b> It is derived from the JWT, and
/// every academic id is a selection that the server proves belongs to the HOD's
/// department and to the exact context before any data is returned.
///
/// Semester is still not offered as a rollup dimension: it is NOT DERIVABLE by
/// the backend, exactly as before.
class HodReportsScreen extends StatefulWidget {
  const HodReportsScreen({
    super.key,
    required this.hodRepository,
    required this.reportRepository,
    this.attendanceRepository,
    this.session,
    this.academicContext,
    this.hierarchyLoader,
    this.downloadFile = downloadReportFile,
    this.onOpenStudent,
    this.onOpenSubject,
  });

  final HodRepository hodRepository;
  final ReportRepository reportRepository;

  /// Phase 3 attendance intelligence. Optional so a host without it still gets
  /// the pre-existing department reports unchanged.
  final HodAttendanceRepository? attendanceRepository;

  final SessionController? session;
  final HodAcademicContext? academicContext;
  final HodHierarchyLoader? hierarchyLoader;

  final ReportFileDownloader downloadFile;

  /// Drill-down callbacks. Null disables the tap affordance rather than
  /// navigating to nothing.
  final ValueChanged<int>? onOpenStudent;
  final ValueChanged<int>? onOpenSubject;

  @override
  State<HodReportsScreen> createState() => _HodReportsScreenState();
}

class _ReportOption {
  const _ReportOption(this.value, this.label);

  final String value;
  final String label;
}

/// Context report sections.
///
/// The keys come from [HodReportExportKind], so the section a reader selects and
/// the report an export button downloads can never drift apart. They are
/// deliberately prefixed: the pre-existing department report types keep their own
/// keys, and sharing one (notably `low-attendance`) would make a section switch
/// ambiguous and silently send the reader to the other report.
final List<_ReportOption> _contextReportOptions = [
  for (final kind in HodReportExportKind.values)
    _ReportOption(kind.reportType, kind.label),
];

const _departmentReportOptions = [
  _ReportOption('daily-lecture', 'Daily Lecture'),
  _ReportOption('coverage', 'Coverage'),
  _ReportOption('monthly', 'Monthly'),
  _ReportOption('quarterly', 'Quarterly'),
  _ReportOption('low-attendance', 'Low Attendance'),
];

/// The name the Pack button uses on screen and in its tooltip.
///
/// <b>Deliberately not a [HodReportExportKind].</b> The Pack is not one of the
/// five reports - it is a workbook bundling several of them - so putting it in
/// that closed set would either make it a sixth "report type" or break the
/// mapping the enum guarantees. Naming it here keeps the set at exactly five.
const String contextPackLabel = 'Attendance Context Pack';

/// The sheets the Pack contains, stated on the button so a HOD knows what they
/// are about to download before spending the wait.
const List<String> contextPackSheets = [
  'Executive Summary',
  'Attendance Matrix',
  'Low Attendance',
  'Subject Summary',
  'Student Summary',
];

class _HodReportsScreenState extends State<HodReportsScreen> {
  /// Without a shared session/context the screen falls back to the pre-existing
  /// department reports, so it must also start on the pre-existing default.
  late String _reportType = _legacyMode ? 'daily-lecture' : 'context-overview';
  DateTime? _startDate;
  DateTime? _endDate;

  /// Bumped on every academic-context change so the embedded panels refetch.
  int _reloadToken = 0;

  int _page = 0;
  static const int _pageSize = 20;

  bool _loading = true;
  String? _error;

  bool _exporting = false;

  ReportPage<HodDailyLectureRow>? _daily;
  ReportPage<HodCoverageRow>? _coverage;
  List<HodRollup>? _rollups;
  List<HodLowAttendance>? _low;

  /// True while one of the academic-context reports is selected.
  bool get _isContextReport =>
      _contextReportOptions.any((option) => option.value == _reportType);

  /// True when the host did not supply the shared session and academic context,
  /// so the screen keeps its original date-scoped department-report shell.
  bool get _legacyMode => widget.session == null || widget.academicContext == null;

  bool get _hasAttendanceRepository => widget.attendanceRepository != null;

  /// The date range actually sent with a department-report request.
  ///
  /// In the shared-context shell the HOD date filter already lives in the
  /// academic context, so the same range drives both the context reports and the
  /// department reports. The two filters are never combined with OR; the server
  /// ANDs the context with the range.
  DateTime? get _effectiveStart =>
      _legacyMode ? _startDate : widget.academicContext?.startDate;

  DateTime? get _effectiveEnd =>
      _legacyMode ? _endDate : widget.academicContext?.endDate;

  bool get _datesInvalid =>
      _legacyMode ? _localDatesInvalid : (widget.academicContext?.datesInvalid ?? false);

  bool get _localDatesInvalid =>
      _startDate != null &&
      _endDate != null &&
      _startDate!.isAfter(_endDate!);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_datesInvalid) return;
    // A context report is loaded by its own panel; this screen only drives the
    // department reports, so there is nothing to wait for here.
    if (_isContextReport) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (_reportType) {
        case 'monthly':
          _rollups = await widget.hodRepository.getRollups(
              type: 'monthly', startDate: _effectiveStart, endDate: _effectiveEnd);
          break;
        case 'quarterly':
          _rollups = await widget.hodRepository.getRollups(
              type: 'quarterly', startDate: _effectiveStart, endDate: _effectiveEnd);
          break;
        case 'low-attendance':
          _low = await widget.hodRepository
              .getLowAttendance(startDate: _effectiveStart, endDate: _effectiveEnd);
          break;
        case 'coverage':
          _coverage = await widget.reportRepository.getCoverage(
              page: _page, size: _pageSize,
              startDate: _effectiveStart, endDate: _effectiveEnd);
          break;
        case 'daily-lecture':
        default:
          _daily = await widget.reportRepository.getDailyLecture(
              page: _page, size: _pageSize,
              startDate: _effectiveStart, endDate: _effectiveEnd);
          break;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load the report. Please try again.';
        _loading = false;
      });
    }
  }

  /// A context level change invalidates the export snapshot in the same state
  /// update that refetches the report, so the export control is disabled again
  /// until the newly-selected context has actually loaded. Without this, a HOD
  /// could export the new context while still looking at the old data.
  ///
  /// <b>It deliberately does not refetch the department reports.</b> Those are
  /// department-wide and take no academic level, so a section switch cannot
  /// change what they return - refetching would be a pointless request.
  void _onContextChanged() => setState(() {
        _reloadToken++;
        _invalidateExportSnapshot();
      });

  /// A date-range change additionally refetches the department reports.
  ///
  /// <b>Phase 4A.</b> These reports read the applied range from the shared
  /// academic context ([_effectiveStart] / [_effectiveEnd]), so without a reload
  /// the screen would keep showing rows filtered by the <i>previous</i> range
  /// while the date bar displayed the new one. `_load` is a no-op for a context
  /// report, which loads through its own panel, so this is safe for both.
  void _onRangeChanged() {
    setState(() {
      _reloadToken++;
      _invalidateExportSnapshot();
    });
    _load();
  }

  void _invalidateExportSnapshot() {
    _loadedContext = null;
    _loadedAt = null;
    _summary = HodReportSummary.none;
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select start date',
    );
    if (picked == null) return;
    setState(() => _startDate = picked);
    if (_datesInvalid) return;
    _page = 0;
    await _load();
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select end date',
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
    if (_datesInvalid) return;
    _page = 0;
    await _load();
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _page = 0;
    _load();
  }

  void _selectType(String value) {
    if (value == _reportType) return;
    setState(() {
      _reportType = value;
      _page = 0;
      _daily = null;
      _coverage = null;
      _rollups = null;
      _low = null;
      // Switching sections invalidates the export snapshot, so the control is
      // disabled again until the newly selected report has actually loaded.
      // Without this the previous section's file could be produced from a chip
      // tap alone - the wrong-report bug in its purest form.
      _reloadToken++;
      _invalidateExportSnapshot();
    });
    _load();
  }

  Future<void> _export(String format) async {
    if (_exporting) return;
    if (_datesInvalid) {
      _showSnack('Start date must not be after end date.');
      return;
    }
    if (_isContextReport) {
      // The context reports are exported by the HodExportBar, which owns its own
      // lifecycle; reaching here means a legacy caller, so run it and surface the
      // outcome rather than silently doing nothing.
      try {
        final status = await _exportContextReport(format);
        if (!mounted) return;
        _showSnack(status);
      } on ApiException catch (e) {
        if (!mounted) return;
        _showSnack(_messageFor(e));
      } catch (_) {
        if (!mounted) return;
        _showSnack('Export failed. Please try again.');
      }
      return;
    }
    setState(() => _exporting = true);
    try {
      final payload = await widget.reportRepository.exportHodReport(
        _reportType,
        format,
        startDate: _effectiveStart,
        endDate: _effectiveEnd,
      );
      final status = await widget.downloadFile(
          payload.bytes, payload.fileName, payload.contentType);
      if (!mounted) return;
      _showSnack(status);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(_messageFor(e));
    } catch (_) {
      if (!mounted) return;
      _showSnack('Export failed. Please try again.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// The academic context whose data is currently on screen, captured when the
  /// panel last reported a successful load.
  ///
  /// <b>Why this exists.</b> An export is a second, independent request. If it
  /// read the live context object, a HOD who changed the section and hit Export
  /// before the panel finished refetching would have downloaded a file for the
  /// <i>new</i> section while looking at the <i>old</i> one - a silently wrong
  /// file. Exporting the snapshot the screen was actually rendered from makes
  /// that impossible, and the control stays disabled until a load succeeds.
  HodExportContext? _loadedContext;

  /// What the loaded panel reported it is showing, for the export summary strip.
  ///
  /// Published by the panel from the data it already holds, so it costs no extra
  /// request and cannot describe a different moment in time.
  HodReportSummary _summary = HodReportSummary.none;

  /// True while an export file is being generated.
  ///
  /// Drives [HodScaffold.controlsEnabled], which locks the academic-context bar
  /// and the date filter for the duration. Without it a HOD could switch section
  /// mid-request and the file would be produced for the old context while the
  /// screen already showed the new one.
  bool _exportBusy = false;

  void _onReportLoaded() {
    final ctx = widget.academicContext;
    if (ctx == null) return;
    setState(() {
      _loadedContext = HodExportContext(
        academicSessionId: ctx.academicSessionId,
        programId: ctx.programId,
        semesterId: ctx.semesterId,
        sectionId: ctx.sectionId,
        subjectId: ctx.subjectId,
        startDate: ctx.startDate,
        endDate: ctx.endDate,
      );
      _loadedAt = DateTime.now();
    });
  }

  /// Adopts the panel's own counts so the strip previews the real dataset.
  void _onReportSummary(HodReportSummary summary) {
    if (!mounted) return;
    setState(() => _summary = summary);
  }

  /// Exports the report the HOD is actually looking at.
  ///
  /// Phase 4A fixes a real defect here: every academic-context report used to be
  /// routed to the matrix exporter, so choosing "Attendance Overview" and
  /// clicking Excel silently produced the attendance matrix.
  ///
  /// <b>There is deliberately no default branch.</b> [HodReportExportKind] is a
  /// closed set and this switch covers every one of its members, so adding a
  /// sixth report type is a compile error rather than a silently wrong file -
  /// which is the only way this bug stays fixed. The two list sections are
  /// refused explicitly, with the action that would let a HOD export them.
  Future<String> _exportContextReport(String format) async {
    final repository = widget.attendanceRepository;
    final ctx = _loadedContext;
    if (repository == null || ctx == null) {
      throw const ApiException.badRequest(
          'The report is still loading. Try again in a moment.');
    }

    final kind = HodReportExportKind.forReportType(_reportType);
    if (kind == null) {
      throw StateError('This report cannot be exported.');
    }
    if (!kind.isExportableFromHub) {
      throw StateError(kind.openAnEntityToExportMessage);
    }

    if (kind == HodReportExportKind.matrix &&
        (ctx.academicSessionId == null ||
            ctx.programId == null ||
            ctx.semesterId == null ||
            ctx.sectionId == null)) {
      throw const ApiException.badRequest(
          HodAttendanceRepository.matrixContextRequiredMessage);
    }

    final payload = await switch (kind) {
      // A cross-tab needs the full four-level context; the repository enforces
      // the same rule, so the guard above only saves a pointless round trip.
      HodReportExportKind.matrix => repository.exportMatrix(
          format,
          academicSessionId: ctx.academicSessionId,
          programId: ctx.programId,
          semesterId: ctx.semesterId,
          sectionId: ctx.sectionId,
          subjectId: ctx.subjectId,
          startDate: ctx.startDate,
          endDate: ctx.endDate,
        ),
      // A context-wide subject summary. Never the matrix - that was the bug.
      HodReportExportKind.overview => repository.exportOverview(
          format,
          academicSessionId: ctx.academicSessionId,
          programId: ctx.programId,
          semesterId: ctx.semesterId,
          sectionId: ctx.sectionId,
          startDate: ctx.startDate,
          endDate: ctx.endDate,
        ),
      // The canonical threshold report, with the subjects responsible.
      HodReportExportKind.lowAttendance => repository.exportLowAttendance(
          format,
          academicSessionId: ctx.academicSessionId,
          programId: ctx.programId,
          semesterId: ctx.semesterId,
          sectionId: ctx.sectionId,
          startDate: ctx.startDate,
          endDate: ctx.endDate,
        ),
      // Unreachable: refused above with an actionable message. Listed so the
      // compiler enforces that a new kind is handled deliberately.
      HodReportExportKind.studentList ||
      HodReportExportKind.subjectList =>
        throw StateError(kind.openAnEntityToExportMessage),
    };
    return widget.downloadFile(
        payload.bytes, payload.fileName, payload.contentType);
  }

  /// The reports that have their own file representation in this hub.
  ///
  /// <b>Why the student and subject lists are not here.</b> Those sections show
  /// every student / every subject in the context, not one of them. There is no
  /// single entity to file, and silently exporting "the first student" would be
  /// exactly the kind of wrong-file bug Phase 4A exists to remove. Each of those
  /// reports is exported from its own detail screen, where the entity is the one
  /// the HOD actually opened.
  static final Set<String> _hubExportableReports = {
    for (final kind in HodReportExportKind.exportableFromHub) kind.reportType,
  };

  String? _exportBlockedReason() {
    if (_isContextReport) {
      if (!_hasAttendanceRepository) {
        return 'Academic context reports are not available.';
      }
      if (_loadedContext == null) {
        return 'The report is still loading. Export is available once it has loaded.';
      }
      if (!_hubExportableReports.contains(_reportType)) {
        final kind = HodReportExportKind.forReportType(_reportType);
        return kind?.openAnEntityToExportMessage ??
            'This report cannot be exported from here.';
      }
      if (_datesInvalid) {
        return 'Start date must not be after end date.';
      }
      return null;
    }
    return _datesInvalid ? 'Start date must not be after end date.' : null;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFor(ApiException e) {
    switch (e.statusCode) {
      case 401:
        return 'Session expired. Please sign in again.';
      case 403:
        return 'You are not authorized to access this report.';
      case 404:
        return 'Report not found.';
      case -1:
        return 'Network error. Check your connection and try again.';
      default:
        return e.message.isNotEmpty ? e.message : 'Request failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final academicContext = widget.academicContext;
    if (session == null || academicContext == null) {
      // Legacy shell: a host without the shared session/context still gets the
      // pre-existing date-scoped department reports, byte-for-byte.
      return _buildLegacyShell();
    }

    return HodScaffold(
      session: session,
      academicContext: academicContext,
      title: 'Reports',
      subtitle: 'Attendance reporting for the selected academic context.',
      icon: Icons.assessment_outlined,
      hierarchyLoader: widget.hierarchyLoader,
      onContextChanged: _onContextChanged,
      onRangeChanged: _onRangeChanged,
      // Locked for the duration of a generation, so the context and the range
      // provably cannot change while a file is being produced for them.
      controlsEnabled: !_exportBusy,
      body: Column(
        children: [
          Expanded(child: _buildReportArea()),
          _buildExportBar(),
        ],
      ),
    );
  }

  Widget _buildReportArea() {
    if (_isContextReport) {
      return _buildContextReport();
    }
    return _buildDepartmentReport();
  }

  // ── Context reports ───────────────────────────────────────────────────

  Widget _buildContextReport() {
    if (!_hasAttendanceRepository) {
      return const HodEmptyView(
        message: 'Academic context reports are not available.',
      );
    }
    final repository = widget.attendanceRepository!;
    final academicContext = widget.academicContext!;

    return Column(
      children: [
        _reportTypeChips([
          ..._contextReportOptions,
          // One entry point back to the pre-existing department reports, so the
          // hub is the single reporting destination without hiding them.
          const _ReportOption('daily-lecture', 'Department Reports'),
        ]),
        Expanded(
          child: switch (_reportType) {
            'context-matrix' => HodAttendanceMatrixPanel(
                repository: repository,
                academicContext: academicContext,
                reloadToken: _reloadToken,
                onReportLoaded: _onReportLoaded,
                onReportSummary: _onReportSummary,
                onOpenStudent: widget.onOpenStudent,
              ),
            'context-students' => HodStudentAttendancePanel(
                repository: repository,
                academicContext: academicContext,
                reloadToken: _reloadToken,
                onReportLoaded: _onReportLoaded,
                onReportSummary: _onReportSummary,
                onOpenStudent: widget.onOpenStudent,
              ),
            'context-subjects' => HodSubjectAttendancePanel(
                repository: repository,
                academicContext: academicContext,
                reloadToken: _reloadToken,
                onReportLoaded: _onReportLoaded,
                onReportSummary: _onReportSummary,
                onOpenSubject: widget.onOpenSubject,
              ),
            'context-low-attendance' => HodLowAttendancePanel(
                repository: repository,
                academicContext: academicContext,
                reloadToken: _reloadToken,
                onReportLoaded: _onReportLoaded,
                onReportSummary: _onReportSummary,
                onOpenStudent: widget.onOpenStudent,
              ),
            _ => HodAttendanceOverviewPanel(
                repository: repository,
                academicContext: academicContext,
                reloadToken: _reloadToken,
                onReportLoaded: _onReportLoaded,
                onReportSummary: _onReportSummary,
                onOpenStudent: widget.onOpenStudent,
                onOpenSubject: widget.onOpenSubject,
              ),
          },
        ),
      ],
    );
  }

  // ── Department reports (pre-existing behaviour) ──────────────────────

  Widget _buildDepartmentReport() {
    return Column(
      children: [
        _reportTypeChips(_departmentReportOptions),
        Expanded(
          child: Column(
            children: [
              Expanded(child: _buildBody()),
              _buildPaginationBar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reportTypeChips(List<_ReportOption> options) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DagacsSpace.md, DagacsSpace.sm,
          DagacsSpace.md, DagacsSpace.sm),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: DagacsSpace.sm,
          runSpacing: DagacsSpace.xs,
          children: [
            for (final option in options)
              ChoiceChip(
                key: Key('report-type-${option.value}'),
                label: Text(option.label),
                selected: _reportType == option.value,
                onSelected: (_) => _selectType(option.value),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ReportErrorState(message: _error!, onRetry: _load);
    }
    return Column(
      children: [
        Expanded(child: _buildPreview()),
      ],
    );
  }

  Widget _buildPaginationBar() {
    if (!_isPaginatedDepartmentReport) return const SizedBox.shrink();
    final page = _reportType == 'daily-lecture' ? _daily : _coverage;
    final current = page?.page ?? 0;
    final total = page?.totalPages ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const Key('report-prev-page'),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
            onPressed: current > 0 ? () => _goToPage(current - 1) : null,
          ),
          Text('Page ${current + 1} of ${total == 0 ? 1 : total}'),
          IconButton(
            key: const Key('report-next-page'),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
            onPressed: total > 0 && current < total - 1
                ? () => _goToPage(current + 1)
                : null,
          ),
        ],
      ),
    );
  }

  bool get _isPaginatedDepartmentReport =>
      _reportType == 'daily-lecture' || _reportType == 'coverage';

  void _goToPage(int page) {
    setState(() => _page = page);
    _load();
  }

  Widget _buildPreview() {
    _Preview? preview;
    switch (_reportType) {
      case 'coverage':
        final page = _coverage;
        preview = page == null ? null : _coveragePreview(page.items);
      case 'monthly' || 'quarterly':
        final list = _rollups;
        preview = list == null ? null : _rollupPreview(list);
      case 'low-attendance':
        final list = _low;
        preview = list == null ? null : _lowPreview(list);
      default:
        final page = _daily;
        preview = page == null ? null : _dailyPreview(page.items);
    }
    if (preview == null || preview.rows.isEmpty) {
      return ReportEmptyState(
        message:
            'No ${_currentLabel.toLowerCase()} data for the current filter.',
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DataTable(columns: preview.columns, rows: preview.rows),
    );
  }

  String get _currentLabel =>
      _departmentReportOptions.firstWhere((o) => o.value == _reportType).label;

  // ── Export ────────────────────────────────────────────────────────────

  Widget _buildExportBar() {
    // Phase 4A: the academic-context reports use the professional export control,
    // which owns the idle/generating/success/failure lifecycle, names the report
    // it will actually download, and is disabled until the report has loaded. The
    // pre-existing department reports keep their own two buttons, unchanged.
    if (_isContextReport) {
      final blocked = _exportBlockedReason();
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            DagacsSpace.md, DagacsSpace.xs, DagacsSpace.md, DagacsSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HodExportBar(
              enabled: blocked == null,
              disabledReason: blocked,
              reportLabel: _activeReportLabel,
              onBusyChanged: (busy) {
                if (mounted) setState(() => _exportBusy = busy);
              },
              leading: HodExportSummaryStrip(
                subjectCount: _summary.subjectCount,
                studentCount: _summary.studentCount,
                rangeText: _rangeText,
                generatedAt: _loadedAt,
              ),
              onExport: (format) => _exportContextReport(format.name),
            ),
            // Phase 4B: the Context Pack.
            //
            // <b>It lives on the hub, not inside HodExportBar.</b> The bar is the
            // per-report control Phase 4A froze, and its tests assert that it
            // offers exactly two formats and no third control. The Pack is not a
            // third format of the selected report either - it is a bundle of the
            // whole context - so adding it to the bar would have bent the
            // section-to-file guarantee that Phase 4A exists to protect.
            _buildContextPackButton(blocked),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DagacsSpace.md, DagacsSpace.xs, DagacsSpace.md, DagacsSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReportExportButtons(
            exporting: _exporting,
            onExcel: () => _export('xlsx'),
            onPdf: () => _export('pdf'),
          ),
        ],
      ),
    );
  }

  /// The name of the report the export control is currently offering.
///
/// The button is disabled for the same reasons the per-report export is - the
/// report has not loaded, the dates are inverted, or the full four-level context
/// has not been chosen - and it exports the same [_loadedContext] the on-screen
/// report was rendered from, so the workbook provably describes what the reader
/// is looking at rather than whatever they selected mid-generation.
Widget _buildContextPackButton(String? blocked) {
  final repository = widget.attendanceRepository;
  // The two list sections have no single entity, and the pack needs a full
  // context, so it is offered only where a full context can exist.
  final contextComplete = _loadedContext?.hasFullContext ?? false;
  final packBlockedReason = blocked ??
      (repository == null
          ? 'Academic context reports are not available.'
          : 'Choose Academic Session, Program, Semester and Section to build the '
              '${contextPackLabel.toLowerCase()}.');

  return Padding(
    padding: const EdgeInsets.only(top: DagacsSpace.xs),
    child: Row(
      children: [
        Expanded(
          child: _ContextPackButton(
            buttonKey: const Key('hod-export-pack'),
            format: 'xlsx',
            blockedReason: contextComplete ? null : packBlockedReason,
            busy: _exportBusy,
            onPressed: () => _exportContextPack('xlsx'),
          ),
        ),
        const SizedBox(width: DagacsSpace.sm),
        // Phase 4C.3: the same five reports as one PDF. A second control beside
        // the first rather than a third format inside HodExportBar, for the same
        // reason the bar was left alone in 4B: the bar is frozen at exactly the
        // two formats of the selected report, and the Pack is a separate
        // deliverable, not a third format of it. Both buttons share one disabled
        // reason and one busy flag, so neither can be offered where the other
        // would be refused.
        Expanded(
          child: _ContextPackButton(
            buttonKey: const Key('hod-export-pack-pdf'),
            format: 'pdf',
            blockedReason: contextComplete ? null : packBlockedReason,
            busy: _exportBusy,
            onPressed: () => _exportContextPack('pdf'),
          ),
        ),
      ],
    ),
  );
}

/// Generates the Context Pack for the loaded snapshot, in the requested format.
///
/// Phase 4C.3: [format] is the path segment the backend already serves, so the
/// one repository method covers both files and the two are guaranteed to be the
/// same five reports of the same authorized context.
Future<void> _exportContextPack(String format) async {
  if (_exporting) return;
  final repository = widget.attendanceRepository;
  final ctx = _loadedContext;
  if (repository == null || ctx == null) {
    _showSnack('The report is still loading. Try again in a moment.');
    return;
  }
  // Phase 4B raises BOTH flags. `_exporting` drives this button's own spinner,
  // and `_exportBusy` is what the Phase 4A scaffold uses to lock the academic
  // context and the date filter - so the context provably cannot change under an
  // in-flight workbook generation, exactly as it cannot under a single report.
  setState(() {
    _exporting = true;
    _exportBusy = true;
  });
  try {
    final payload = await repository.exportContextPack(
      format,
      academicSessionId: ctx.academicSessionId,
      programId: ctx.programId,
      semesterId: ctx.semesterId,
      sectionId: ctx.sectionId,
      startDate: ctx.startDate,
      endDate: ctx.endDate,
    );
    final status = await widget.downloadFile(
        payload.bytes, payload.fileName, payload.contentType);
    if (!mounted) return;
    _showSnack('Downloaded $status');
  } on ApiException catch (e) {
    if (!mounted) return;
    _showSnack(_messageFor(e));
  } catch (_) {
    if (!mounted) return;
    _showSnack('Export failed. Please try again.');
  } finally {
    if (mounted) {
      setState(() {
        _exporting = false;
        _exportBusy = false;
      });
    }
  }
}

/// The name of the report the export control is currently offering.
  ///
  /// It comes from the same [HodReportExportKind] that the section chip was
  /// selected from and that the dispatch switches on, so the label, the endpoint
  /// and the file can never describe three different reports.
  String get _activeReportLabel {
    if (!_isContextReport) return _currentLabel;
    return HodReportExportKind.forReportType(_reportType)?.label ??
        'this report';
  }

  /// The applied date range, in the same wording the export prints.
  String? get _rangeText {
    final start = _loadedContext?.startDate;
    final end = _loadedContext?.endDate;
    if (start == null && end == null) return null;
    String d(DateTime v) =>
        '${v.year.toString().padLeft(4, '0')}-'
        '${v.month.toString().padLeft(2, '0')}-'
        '${v.day.toString().padLeft(2, '0')}';
    if (start != null && end != null) return '${d(start)} to ${d(end)}';
    if (start != null) return 'from ${d(start)}';
    return 'until ${d(end!)}';
  }

  /// When the displayed data was fetched, so the reader knows how fresh it is.
  DateTime? _loadedAt;

  // ── Legacy shell ──────────────────────────────────────────────────────

  Widget _buildLegacyShell() {
    return Scaffold(
      appBar: AppBar(title: const Text('HOD Reports')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ReportDateBar(
                startDate: _startDate,
                endDate: _endDate,
                onPickStart: _pickStartDate,
                onPickEnd: _pickEndDate,
                onClear: _clearDates,
              ),
            ),
            if (_datesInvalid)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Start date must not be after end date.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in _departmentReportOptions)
                      ChoiceChip(
                        key: Key('report-type-${option.value}'),
                        label: Text(option.label),
                        selected: _reportType == option.value,
                        onSelected: (_) => _selectType(option.value),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReportExportButtons(
                    exporting: _exporting,
                    onExcel: () => _export('xlsx'),
                    onPdf: () => _export('pdf'),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
            _buildPaginationBar(),
          ],
        ),
      ),
    );
  }

  // ── Department report previews (unchanged) ───────────────────────────

  _Preview _dailyPreview(List<HodDailyLectureRow> items) {
    final columns = const [
      DataColumn(label: Text('Date')),
      DataColumn(label: Text('Period')),
      DataColumn(label: Text('Subject')),
      DataColumn(label: Text('Section')),
      DataColumn(label: Text('Present')),
      DataColumn(label: Text('Total')),
      DataColumn(label: Text('Percentage')),
    ];
    final rows = items
        .map((r) => DataRow(cells: [
              DataCell(Text(r.date)),
              DataCell(Text(r.lecturePeriod)),
              DataCell(Text('${r.subjectName} (${r.subjectCode})')),
              DataCell(Text('${r.sectionName} (${r.sectionCode})')),
              DataCell(Text('${r.presentCount}')),
              DataCell(Text('${r.totalRecordedCount}')),
              DataCell(
                  Text(formatReportPercentage(r.percentage),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
            ]))
        .toList();
    return _Preview(columns, rows);
  }

  _Preview _coveragePreview(List<HodCoverageRow> items) {
    final columns = const [
      DataColumn(label: Text('Subject')),
      DataColumn(label: Text('Section')),
      DataColumn(label: Text('Recorded Dates')),
      DataColumn(label: Text('Sessions')),
    ];
    final rows = items
        .map((r) => DataRow(cells: [
              DataCell(Text('${r.subjectName} (${r.subjectCode})')),
              DataCell(Text('${r.sectionName} (${r.sectionCode})')),
              DataCell(Text('${r.recordedDateCount}')),
              DataCell(Text('${r.sessionCount}')),
            ]))
        .toList();
    return _Preview(columns, rows);
  }

  _Preview _rollupPreview(List<HodRollup> items) {
    final columns = const [
      DataColumn(label: Text('Period')),
      DataColumn(label: Text('Present')),
      DataColumn(label: Text('Total')),
      DataColumn(label: Text('Percentage')),
    ];
    final rows = items
        .map((r) => DataRow(cells: [
              DataCell(Text(r.period)),
              DataCell(Text('${r.presentCount}')),
              DataCell(Text('${r.totalRecordedCount}')),
              DataCell(
                  Text(formatReportPercentage(r.percentage),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
            ]))
        .toList();
    return _Preview(columns, rows);
  }

  _Preview _lowPreview(List<HodLowAttendance> items) {
    final columns = const [
      DataColumn(label: Text('Roll No')),
      DataColumn(label: Text('Student')),
      DataColumn(label: Text('Section')),
      DataColumn(label: Text('Present')),
      DataColumn(label: Text('Total')),
      DataColumn(label: Text('Percentage')),
    ];
    final rows = items
        .map((r) => DataRow(cells: [
              DataCell(Text(r.rollNumber)),
              DataCell(Text(r.studentName)),
              DataCell(Text(r.sectionName)),
              DataCell(Text('${r.presentCount}')),
              DataCell(Text('${r.totalRecordedCount}')),
              DataCell(
                  Text(formatReportPercentage(r.percentage),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
            ]))
        .toList();
    return _Preview(columns, rows);
  }
}

class _Preview {
  const _Preview(this.columns, this.rows);

  final List<DataColumn> columns;
  final List<DataRow> rows;
}

/// Phase 4B: the Context Pack control.
/// Phase 4C.3: one control per format - the same five reports as a workbook or as
/// a single PDF.
///
/// <b>Separate from [HodExportBar] on purpose.</b> The bar is the per-report
/// control Phase 4A froze, and it offers exactly the two formats of the selected
/// report. The Pack is not a third format of that report - it is a separate
/// deliverable bundling several of them - so it gets its own controls rather than
/// being forced into the bar, which would have weakened the guarantee that a
/// control never advertises a file it does not produce.
///
/// <b>Two buttons, not a menu.</b> The alternative was one button that opens a
/// format choice, which would have meant replacing the single control Phase 4B
/// shipped and every key its tests use. Two side-by-side buttons mirror the
/// Excel/PDF pair the per-report bar already uses, so the pattern a HOD learns in
/// one place is the pattern in both.
///
/// <b>Both controls share one disabled reason and one busy flag</b>, inherited
/// from the caller, so neither can be offered where the other would be refused, and
/// neither stays live while a generation is in flight.
class _ContextPackButton extends StatelessWidget {
  const _ContextPackButton({
    required this.buttonKey,
    required this.format,
    required this.blockedReason,
    required this.busy,
    required this.onPressed,
  });

  /// Identifies this control's button, so a test can tell the two formats apart.
  final Key buttonKey;

  /// `xlsx` or `pdf` - the path segment the backend serves, and the label suffix.
  final String format;

  final String? blockedReason;
  final bool busy;
  final VoidCallback onPressed;

  bool get _isPdf => format == 'pdf';

  /// The resting label.
  ///
  /// The spreadsheet control keeps the exact wording Phase 4B shipped, so the
  /// existing hub and pack tests that look for the text 'Context Pack' keep
  /// meaning what they meant.
  String get _label => _isPdf ? 'Context Pack PDF' : 'Context Pack';

  /// Per-format, so the two buttons never share a widget key.
  Key get _labelKey => _isPdf
      ? const Key('hod-export-pack-pdf-label')
      : const Key('hod-export-pack-label');

  /// The tooltip states exactly what is in the file, so a HOD knows what they are
  /// about to download before spending the wait on it.
  String get _tooltip => blockedReason ??
      (_isPdf
          ? 'One PDF with ${contextPackSheets.join(', ')} for the selected '
              'academic context'
          : 'One workbook with ${contextPackSheets.join(', ')} '
              'for the selected academic context');

  @override
  Widget build(BuildContext context) {
    final disabled = blockedReason != null || busy;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: _tooltip,
      child: Tooltip(
        message: _tooltip,
        child: OutlinedButton.icon(
          key: buttonKey,
          onPressed: disabled ? null : onPressed,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_isPdf ? Icons.picture_as_pdf : Icons.folder_zip_outlined),
          label: Text(
            busy ? 'Building $contextPackLabel…' : _label,
            key: _labelKey,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
