import 'package:flutter/material.dart';

import '../core/theme/dagacs_theme.dart';
import '../models/student_wise_report.dart';
import '../models/teacher_assignment.dart';
import '../network/api_exception.dart';
import '../repositories/report_repository.dart';
import '../repositories/teacher_repository.dart';
import '../services/report_file_downloader.dart';
import '../widgets/report_widgets.dart';

/// Additive student-wise attendance register.
///
/// Picks one of the teacher's own assignments (subject + section/batch), then
/// renders the enrollment-ordered matrix with one column per (date,
/// lecturePeriod) session and per-student totals (M4 semantics). The locked
/// M10B contract is subjectId (required) plus exactly one of sectionId/batchId
/// (XOR): both/neither/missing subject is 400, a nonexistent ID is 404, and an
/// out-of-scope context is 403. Self-scope is always derived from the JWT.
/// Excel/PDF exports use the same matrix.
class StudentWiseReportScreen extends StatefulWidget {
  const StudentWiseReportScreen({
    super.key,
    required this.reportRepository,
    required this.teacherRepository,
    this.downloadFile = downloadReportFile,
  });

  final ReportRepository reportRepository;
  final TeacherRepository teacherRepository;
  final ReportFileDownloader downloadFile;

  @override
  State<StudentWiseReportScreen> createState() => _StudentWiseReportScreenState();
}

class _StudentWiseReportScreenState extends State<StudentWiseReportScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  bool get _datesInvalid =>
      _startDate != null &&
      _endDate != null &&
      _startDate!.isAfter(_endDate!);

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

  /// Distinct classes within the selected subject.
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
      seen.putIfAbsent(key, () => (batchId: isSection ? null : a.batchId, label: klass));
    }
    final entries = seen.entries.toList()
      ..sort((a, b) => a.value.label.compareTo(b.value.label));
    return [
      for (final e in entries)
        (id: e.key, batchId: e.value.batchId, label: e.value.label)
    ];
  }

  bool get _canGenerate =>
      _subjectId != null && _sectionId != null && !_datesInvalid && !_loading;

  Future<void> _loadAssignments() async {
    setState(() {
      _loadingAssignments = true;
      _error = null;
    });
    try {
      final assignments =
          await widget.teacherRepository.getMyAssignments();
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
    if (subjectId == null || sectionId == null) return;
    if (_datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await widget.reportRepository.getStudentWiseReport(
        subjectId: subjectId,
        sectionId: sectionId,
        startDate: _startDate,
        endDate: _endDate,
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
    if (subjectId == null || sectionId == null) return;
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
        startDate: _startDate,
        endDate: _endDate,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student-Wise Register')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _buildAssignmentPicker(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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
            if (_subjectId != null && _sectionId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: ReportExportButtons(
                  exporting: _exporting,
                  onExcel: () => _export('xlsx'),
                  onPdf: () => _export('pdf'),
                ),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentPicker() {
    if (_loadingAssignments) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ));
    }
    if (_assignments.isEmpty) {
      return const ReportEmptyState(
          message: 'You have no teaching assignments to report on.');
    }

    final sections = _sections;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: const Key('register-subject'),
                value: _subjectId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final s in _subjects)
                    DropdownMenuItem(value: s.id, child: Text(s.label)),
                ],
                onChanged: _onSubjectChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: const Key('register-section'),
                value: _sectionId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final s in sections)
                    DropdownMenuItem(value: s.id, child: Text(s.label)),
                ],
                onChanged: _subjectId == null ? null : _onSectionChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // One explicit action instead of a request per dropdown change.
        // ElevatedButton (the same pattern My Classes uses) so it can render a
        // genuinely disabled state until a subject and section are chosen.
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('register-generate'),
            onPressed: _canGenerate ? () => _load() : null,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.assessment_outlined, size: 18),
            label: const Text('Generate Report'),
          ),
        ),
      ],
    );
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
    await _load();
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _load();
  }

  Widget _buildBody() {
    if (_loadingAssignments) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ReportErrorState(message: _error!, onRetry: _load);
    }
    if (_subjectId == null || _sectionId == null) {
      return const ReportEmptyState(
          message: 'Select a subject and section, then generate the report.');
    }
    if (_report == null && !_loading) {
      return const ReportEmptyState(
          message: 'Tap Generate Report to load the student-wise register.');
    }
    final report = _report;
    if (report == null || report.rows.isEmpty) {
      return const ReportEmptyState(
          message: 'No attendance data for the selected class and dates.');
    }
    return RefreshIndicator(
      key: const Key('student-wise-refresh'),
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _buildMatrix(report),
        ),
      ),
    );
  }

  Widget _buildMatrix(StudentWiseReport report) {
    return DataTable(
      columns: [
        const DataColumn(label: Text('Enrollment')),
        const DataColumn(label: Text('Student')),
        for (final col in report.columns)
          DataColumn(
            label: Text('${col.date}\n${col.lecturePeriod}',
                style: const TextStyle(fontSize: 11)),
          ),
        const DataColumn(label: Text('Present')),
        const DataColumn(label: Text('Total Classes')),
        const DataColumn(label: Text('%')),
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

  Widget _cellWidget(String? status) {
    final color = status == 'PRESENT'
        ? DagacsColors.success
        : status == 'ABSENT'
            ? DagacsColors.error
            : DagacsColors.textSecondary;
    return status == 'PRESENT' || status == 'ABSENT'
        ? Icon(Icons.circle, size: 10, color: color)
        : const SizedBox.shrink();
  }
}