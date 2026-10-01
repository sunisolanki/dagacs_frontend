import 'package:flutter/material.dart';

import '../core/context/hod_academic_context.dart';
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
/// The keys are deliberately prefixed: the pre-existing department report types
/// keep their own keys, and sharing one (notably `low-attendance`) would make a
/// section switch ambiguous and silently send the reader to the other report.
const _contextReportOptions = [
  _ReportOption('context-overview', 'Attendance Overview'),
  _ReportOption('context-matrix', 'Attendance Matrix'),
  _ReportOption('context-students', 'Student Attendance'),
  _ReportOption('context-subjects', 'Subject Attendance'),
  _ReportOption('context-low-attendance', 'Low Attendance'),
];

const _departmentReportOptions = [
  _ReportOption('daily-lecture', 'Daily Lecture'),
  _ReportOption('coverage', 'Coverage'),
  _ReportOption('monthly', 'Monthly'),
  _ReportOption('quarterly', 'Quarterly'),
  _ReportOption('low-attendance', 'Low Attendance'),
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

  /// A context or date change invalidates the export snapshot in the same state
  /// update that refetches the report, so the export control is disabled again
  /// until the newly-selected context has actually loaded. Without this, a HOD
  /// could export the new context while still looking at the old data.
  void _onContextChanged() => setState(() {
        _reloadToken++;
        _loadedContext = null;
        _loadedAt = null;
      });

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

  /// Exports the report the HOD is actually looking at.
  ///
  /// Phase 4A fixes a real defect here: every academic-context report used to be
  /// routed to the matrix exporter, so choosing "Attendance Overview" and
  /// clicking Excel silently produced the attendance matrix. The dispatch is now
  /// per report type, and the filename, the endpoint and the on-screen data all
  /// come from the same snapshot.
  Future<String> _exportContextReport(String format) async {
    final repository = widget.attendanceRepository;
    final ctx = _loadedContext;
    if (repository == null || ctx == null) {
      throw const ApiException.badRequest(
          'The report is still loading. Try again in a moment.');
    }
    if (_reportType == 'context-matrix' &&
        (ctx.academicSessionId == null ||
            ctx.programId == null ||
            ctx.semesterId == null ||
            ctx.sectionId == null)) {
      throw const ApiException.badRequest(
          HodAttendanceRepository.matrixContextRequiredMessage);
    }

    final extension = format;
    final payload = await switch (_reportType) {
      'context-matrix' => repository.exportMatrix(
          extension,
          academicSessionId: ctx.academicSessionId,
          programId: ctx.programId,
          semesterId: ctx.semesterId,
          sectionId: ctx.sectionId,
          subjectId: ctx.subjectId,
          startDate: ctx.startDate,
          endDate: ctx.endDate,
        ),
      'context-low-attendance' => repository.exportLowAttendance(
          extension,
          academicSessionId: ctx.academicSessionId,
          programId: ctx.programId,
          semesterId: ctx.semesterId,
          sectionId: ctx.sectionId,
          startDate: ctx.startDate,
          endDate: ctx.endDate,
        ),
      _ => repository.exportOverview(
          extension,
          academicSessionId: ctx.academicSessionId,
          programId: ctx.programId,
          semesterId: ctx.semesterId,
          sectionId: ctx.sectionId,
          startDate: ctx.startDate,
          endDate: ctx.endDate,
        ),
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
  static const Set<String> _hubExportableReports = {
    'context-overview',
    'context-matrix',
    'context-low-attendance',
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
        return _reportType == 'context-students'
            ? 'Open a student to export that student\'s attendance report.'
            : 'Open a subject to export that subject\'s attendance report.';
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
      onRangeChanged: _onContextChanged,
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
                onOpenStudent: widget.onOpenStudent,
              ),
            'context-students' => HodStudentAttendancePanel(
                repository: repository,
                academicContext: academicContext,
                reloadToken: _reloadToken,
                onReportLoaded: _onReportLoaded,
                onOpenStudent: widget.onOpenStudent,
              ),
            'context-subjects' => HodSubjectAttendancePanel(
                repository: repository,
                academicContext: academicContext,
                reloadToken: _reloadToken,
                onReportLoaded: _onReportLoaded,
                onOpenSubject: widget.onOpenSubject,
              ),
            'context-low-attendance' => HodLowAttendancePanel(
                repository: repository,
                academicContext: academicContext,
                reloadToken: _reloadToken,
                onReportLoaded: _onReportLoaded,
                onOpenStudent: widget.onOpenStudent,
              ),
            _ => HodAttendanceOverviewPanel(
                repository: repository,
                academicContext: academicContext,
                reloadToken: _reloadToken,
                onReportLoaded: _onReportLoaded,
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
    // which owns the idle/generating/success/failure lifecycle and is disabled
    // until the report has actually loaded. The pre-existing department reports
    // keep their own two buttons, unchanged.
    if (_isContextReport) {
      final blocked = _exportBlockedReason();
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            DagacsSpace.md, DagacsSpace.xs, DagacsSpace.md, DagacsSpace.sm),
        child: HodExportBar(
          enabled: blocked == null,
          disabledReason: blocked,
          showPack: _reportType == 'context-matrix',
          leading: HodExportSummaryStrip(
            rangeText: _rangeText,
            generatedAt: _loadedAt,
          ),
          onExport: (format) => _exportContextReport(format.name),
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
