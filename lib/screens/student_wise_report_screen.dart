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
  TeacherAssignment? _selected;
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
    final assignment = _selected;
    if (assignment == null) return;
    if (_datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await widget.reportRepository.getStudentWiseReport(
        subjectId: assignment.subjectId!,
        sectionId: assignment.sectionId,
        batchId: assignment.batchId,
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
    final assignment = _selected;
    if (assignment == null) return;
    if (_exporting) return;
    if (_datesInvalid) {
      _showSnack('Start date must not be after end date.');
      return;
    }
    setState(() => _exporting = true);
    try {
      final payload = await widget.reportRepository.exportStudentWiseReport(
        format,
        subjectId: assignment.subjectId!,
        sectionId: assignment.sectionId,
        batchId: assignment.batchId,
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

  String _assignmentLabel(TeacherAssignment a) {
    final subject = '${a.subjectName ?? ''} (${a.subjectCode ?? ''})'.trim();
    final klass = a.sectionName != null
        ? a.sectionName!
        : a.batchCode ?? '';
    return '$subject - $klass';
  }

  void _onChanged(TeacherAssignment? value) {
    setState(() {
      _selected = value;
      _report = null;
      _error = null;
    });
    if (value != null) _load();
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
            if (_selected != null)
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
    return DropdownButtonFormField<TeacherAssignment>(
      key: const Key('student-wise-assignment'),
      value: _selected,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Class (subject - section / batch)',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final a in _assignments)
          DropdownMenuItem(value: a, child: Text(_assignmentLabel(a))),
      ],
      onChanged: _onChanged,
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
    if (_selected == null) {
      return const ReportEmptyState(
          message: 'Select a class to load its student-wise register.');
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
        const DataColumn(label: Text('Total')),
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
            DataCell(Text(formatReportPercentage(row.percentage),
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