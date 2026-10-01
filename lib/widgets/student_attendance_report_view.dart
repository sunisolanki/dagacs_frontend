import 'package:flutter/material.dart';

import '../core/theme/dagacs_theme.dart';
import '../models/student_wise_report.dart';
import '../models/teacher_assignment.dart';
import '../network/api_exception.dart';
import '../repositories/report_repository.dart';
import '../repositories/teacher_repository.dart';
import '../services/report_file_downloader.dart';
import 'dagacs_widgets.dart';
import 'report_widgets.dart';

/// The teacher student-wise, date-wise attendance register.
///
/// One column per CONDUCTED attendance session, one row per enrolled student,
/// ordered by enrollment number. This is the single implementation of the
/// register: both the Reports page and the student-wise deep link host it, so
/// the web preview, the Excel file and the PDF can never disagree.
///
/// Attendance semantics mirror the backend exports exactly:
/// `PRESENT` renders `P`; `ABSENT` **and every unmarked / missing mark** render
/// `A`. An unmarked session still counts towards the shared `Total Classes`
/// denominator, so an unmarked student can never look more present than they
/// are, and the matrix always stays rectangular.
class StudentAttendanceReportView extends StatefulWidget {
  const StudentAttendanceReportView({
    super.key,
    required this.reportRepository,
    required this.teacherRepository,
    this.downloadFile = downloadReportFile,
  });

  final ReportRepository reportRepository;
  final TeacherRepository teacherRepository;
  final ReportFileDownloader downloadFile;

  @override
  State<StudentAttendanceReportView> createState() =>
      _StudentAttendanceReportViewState();
}

class _StudentAttendanceReportViewState
    extends State<StudentAttendanceReportView> {
  DateTime? _startDate;
  DateTime? _endDate;

  List<TeacherAssignment> _assignments = const [];
  // Separate Subject / Section selectors, cascaded from the teacher's own
  // assignment list (the same list the backend re-validates for authorization).
  int? _subjectId;
  int? _sectionId;
  bool _loadingAssignments = true;

  bool _loading = false;
  String? _error;
  StudentWiseReport? _report;

  bool _exporting = false;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  bool get _datesInvalid =>
      _startDate != null &&
      _endDate != null &&
      _startDate!.isAfter(_endDate!);

  /// All four filters are required, in a valid order, before Generate enables.
  bool get _canGenerate =>
      _subjectId != null &&
      _sectionId != null &&
      _startDate != null &&
      _endDate != null &&
      !_datesInvalid &&
      !_loading;

  /// Distinct subjects across the teacher's assignments, in stable order.
  List<({int id, String label})> get _subjects {
    final seen = <int, String>{};
    for (final a in _assignments) {
      final id = a.subjectId;
      if (id == null) continue;
      seen.putIfAbsent(
          id,
          () => '${a.subjectName ?? "Subject"}'
              '${a.subjectCode == null ? "" : " (${a.subjectCode})"}');
    }
    final entries = seen.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [for (final e in entries) (id: e.key, label: e.value)];
  }

  /// Distinct classes within the selected subject. A batch assignment is keyed
  /// by its batch id so it can never collide with a section id.
  List<({int id, int? batchId, String label})> get _sections {
    if (_subjectId == null) return const [];
    final seen = <int, ({int? batchId, String label})>{};
    for (final a in _assignments) {
      if (a.subjectId != _subjectId) continue;
      final isSection = a.sectionId != null;
      final key = isSection ? a.sectionId! : (a.batchId ?? -1);
      final klass = isSection
          ? '${a.sectionName ?? "Section"}'
              '${a.sectionCode == null ? "" : " (${a.sectionCode})"}'
          : 'Batch ${a.batchCode ?? "-"}';
      seen.putIfAbsent(
          key, () => (batchId: isSection ? null : a.batchId, label: klass));
    }
    final entries = seen.entries.toList()
      ..sort((a, b) => a.value.label.compareTo(b.value.label));
    return [
      for (final e in entries)
        (id: e.key, batchId: e.value.batchId, label: e.value.label)
    ];
  }

  String? get _selectedSubjectLabel {
    if (_subjectId == null) return null;
    for (final s in _subjects) {
      if (s.id == _subjectId) return s.label;
    }
    return null;
  }

  String? get _selectedSectionLabel {
    if (_sectionId == null) return null;
    for (final s in _sections) {
      if (s.id == _sectionId) return s.label;
    }
    return null;
  }

  Future<void> _loadAssignments() async {
    setState(() {
      _loadingAssignments = true;
      _error = null;
    });
    try {
      final assignments = await widget.teacherRepository.getMyAssignments();
      if (!mounted) return;
      setState(() {
        _assignments = assignments;
        _loadingAssignments = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAssignments = false;
        _error = userMessageFor(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingAssignments = false;
        _error = 'Failed to load your assignments. Please try again.';
      });
    }
  }

  Future<void> _load() async {
    final subjectId = _subjectId;
    final sectionId = _sectionId;
    final start = _startDate;
    final end = _endDate;
    if (subjectId == null || sectionId == null) return;
    if (start == null || end == null) return;
    if (_datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await widget.reportRepository.getStudentWiseReport(
        subjectId: subjectId,
        sectionId: sectionId,
        startDate: start,
        endDate: end,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userMessageFor(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load the student-wise report. Please try again.';
      });
    }
  }

  Future<void> _export(String format) async {
    final subjectId = _subjectId;
    final sectionId = _sectionId;
    final start = _startDate;
    final end = _endDate;
    if (subjectId == null || sectionId == null) return;
    if (start == null || end == null) return;
    if (_exporting) return;
    if (_datesInvalid) {
      _showSnack('Start date must not be after end date.');
      return;
    }
    setState(() => _exporting = true);
    try {
      final payload = await widget.reportRepository.exportStudentWiseReport(
        format,
        subjectId: subjectId,
        sectionId: sectionId,
        startDate: start,
        endDate: end,
      );
      final status = await widget.downloadFile(
          payload.bytes, payload.fileName, payload.contentType);
      if (!mounted) return;
      _showSnack(status);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(userMessageFor(e));
    } catch (_) {
      if (!mounted) return;
      _showSnack('Export failed. Please try again.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSubjectChanged(int? subjectId) {
    setState(() {
      _subjectId = subjectId;
      // Changing subject invalidates the class and the previous report.
      _sectionId = null;
      _report = null;
      _error = null;
    });
  }

  void _onSectionChanged(int? sectionId) {
    setState(() {
      _sectionId = sectionId;
      _report = null;
      _error = null;
    });
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
    // Selection alone never fetches: Generate Report is the only trigger.
    setState(() => _startDate = picked);
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
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _report = null;
    });
  }

  /// Column label for one conducted session, e.g. `12-Aug-2026 (P1)`.
  ///
  /// Two sessions on the same date with different lecture periods therefore get
  /// two clearly distinct columns; neither is merged nor overwritten.
  static String sessionLabel(StudentWiseColumn col) {
    final parts = col.date.split('-');
    var base = col.date;
    if (parts.length == 3) {
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (m != null && d != null && m >= 1 && m <= 12) {
        base = '${d.toString().padLeft(2, '0')}-${_months[m - 1]}-${parts[0]}';
      }
    }
    if (col.lecturePeriod.isEmpty) return base;
    return '$base (${col.lecturePeriod})';
  }

  static String _prettyDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${_months[d.month - 1]}-${d.year}';

  /// Height of the scrollable matrix viewport. Bounded so the report header and
  /// the matrix never compete for the remaining page height.
  static const double _matrixViewportHeight = 420;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Capped and internally scrollable. NOTE: a `Flexible` next to an
          // `Expanded` would split the page 50/50 (both default to flex 1) and
          // overflow on short viewports, so the cap is explicit here.
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFilterCard(),
                    const SizedBox(height: 16),
                    ReportDateBar(
                      startDate: _startDate,
                      endDate: _endDate,
                      onPickStart: _pickStartDate,
                      onPickEnd: _pickEndDate,
                      onClear: _clearDates,
                    ),
                    if (_datesInvalid)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Start date must not be after end date.',
                            style:
                                TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ),
                    if (_subjectId != null &&
                        _sectionId != null &&
                        _startDate != null &&
                        _endDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ReportExportButtons(
                          exporting: _exporting,
                          onExcel: () => _export('xlsx'),
                          onPdf: () => _export('pdf'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    if (_loadingAssignments) {
      return const AppCard(
        child: SizedBox(
          height: 72,
          child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }
    if (_assignments.isEmpty) {
      return const AppCard(
        child: Text('You have no teaching assignments to report on.'),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < DagacsBreakpoints.narrow;
              final subject = AppFormDropdown<int>(
                key: const Key('register-subject'),
                label: 'Subject',
                value: _subjectId,
                items: [
                  for (final s in _subjects)
                    DropdownMenuItem(value: s.id, child: Text(s.label)),
                ],
                onChanged: _onSubjectChanged,
              );
              final section = AppFormDropdown<int>(
                key: const Key('register-section'),
                label: 'Section',
                value: _sectionId,
                items: [
                  for (final s in _sections)
                    DropdownMenuItem(value: s.id, child: Text(s.label)),
                ],
                // A subject must be chosen first, so the section list is empty
                // until then; the widget takes a non-nullable callback.
                onChanged: _subjectId == null
                    ? (_) {}
                    : (value) => _onSectionChanged(value),
              );
              if (stacked) {
                return Column(
                  children: [subject, section],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: subject),
                  const SizedBox(width: 16),
                  Expanded(child: section),
                ],
              );
            },
          ),
          // One explicit action. Never a request per filter change.
          AppPrimaryButton(
            key: const Key('register-generate'),
            onPressed: _load,
            enabled: _canGenerate,
            loading: _loading,
            child: const Text('Generate Report'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingAssignments || _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ReportErrorState(message: _error!, onRetry: _load);
    }
    if (_subjectId == null || _sectionId == null) {
      return const ReportEmptyState(
          message: 'Select a subject and section, then generate the report.');
    }
    if (_startDate == null || _endDate == null) {
      return const ReportEmptyState(
          message: 'Select a start and end date, then generate the report.');
    }
    if (_report == null) {
      return const ReportEmptyState(
          message: 'Tap Generate Report to load the student-wise register.');
    }
    final report = _report;
    if (report == null) {
      return const ReportEmptyState(
          message: 'Tap Generate Report to load the student-wise register.');
    }
    if (report.rows.isEmpty) {
      return const ReportEmptyState(
          message:
              'No conducted attendance sessions for the selected class and dates.');
    }
    return RefreshIndicator(
      key: const Key('student-wise-refresh'),
      onRefresh: _load,
      // The whole report scrolls as one unit, so a tall header can never
      // squeeze the matrix into an overflow.
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildReportHeader(report),
            const SizedBox(height: 8),
            SizedBox(
              height: _matrixViewportHeight,
              child: Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildMatrix(report),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// On-screen mirror of the Excel/PDF header block plus a summary strip.
  Widget _buildReportHeader(StudentWiseReport report) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AppCard(
        padding: const EdgeInsets.all(DagacsSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DAGACS',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'STUDENT ATTENDANCE REPORT',
              key: const Key('register-report-title'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Subject: ${_selectedSubjectLabel ?? "-"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Section: ${_selectedSectionLabel ?? "-"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Date Range: ${_prettyDate(_startDate!)} to ${_prettyDate(_endDate!)}',
              key: const Key('register-report-scope'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _buildSummaryStrip(report),
            const SizedBox(height: 8),
            _buildLegend(),
          ],
        ),
      ),
    );
  }
  Widget _buildSummaryStrip(StudentWiseReport report) {
    // Averaged from the backend's authoritative per-row percentages - never
    // recomputed from present/total, so the screen cannot disagree with Excel
    // or the PDF.
    final percentages =
        report.rows.map((r) => r.percentage).whereType<double>().toList();
    final average = percentages.isEmpty
        ? null
        : percentages.reduce((a, b) => a + b) / percentages.length;

    return Wrap(
      key: const Key('register-summary'),
      spacing: 8,
      runSpacing: 8,
      children: [
        _summaryChip('Students', '${report.rows.length}'),
        _summaryChip('Sessions', '${report.columns.length}'),
        _summaryChip('Average',
            average == null ? 'N/A' : formatRegisterPercentage(average)),
      ],
    );
  }

  Widget _summaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: DagacsColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style:
                  const TextStyle(fontSize: 12, color: DagacsColors.textSecondary)),
          Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      key: const Key('register-legend'),
      spacing: 16,
      runSpacing: 4,
      children: const [
        Text('P = Present',
            style: TextStyle(fontSize: 12, color: DagacsColors.success)),
        Text('A = Absent',
            style: TextStyle(fontSize: 12, color: DagacsColors.error)),
        Text('Unmarked / Missing = A',
            style: TextStyle(fontSize: 12, color: DagacsColors.textSecondary)),
      ],
    );
  }

  Widget _buildMatrix(StudentWiseReport report) {
    return DataTable(
      columns: [
        const DataColumn(label: Text('Enrollment No.')),
        const DataColumn(label: Text('Student Name')),
        for (final col in report.columns)
          DataColumn(
            label: Text(sessionLabel(col),
                style: const TextStyle(fontSize: 11)),
          ),
        const DataColumn(label: Text('Present')),
        const DataColumn(label: Text('Total Classes')),
        const DataColumn(label: Text('Percentage')),
      ],
      rows: [
        for (final row in report.rows)
          DataRow(cells: [
            DataCell(Text(row.enrollmentNumber ?? '')),
            DataCell(Text(row.name ?? '')),
            for (final col in report.columns)
              DataCell(_cellWidget(row.cellStatus(col.sessionId))),
            DataCell(Text('${row.presentCount}')),
            DataCell(Text('${row.totalRecordedCount}')),
            DataCell(Text(formatRegisterPercentage(row.percentage),
                style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
      ],
    );
  }

  /// `P` for present. Absent, unmarked and missing all render `A` - matching the
  /// Excel and PDF exports exactly, so no column can silently appear blank.
  Widget _cellWidget(String? status) {
    final present = status == 'PRESENT';
    return Text(
      present ? 'P' : 'A',
      style: TextStyle(
        color: present ? DagacsColors.success : DagacsColors.error,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }
}
