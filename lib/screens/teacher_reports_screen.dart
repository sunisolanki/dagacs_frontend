import 'package:flutter/material.dart';

import '../models/teacher_report_row.dart';
import '../network/api_exception.dart';
import '../repositories/report_repository.dart';
import '../services/report_file_downloader.dart';
import '../widgets/report_widgets.dart';

/// Teacher Reports (M7.3).
///
/// Shows the authenticated teacher's own subject-wise attendance report
/// (M7.1 `GET /api/teacher/attendance/report`) and exposes the M7.2 Excel/PDF
/// exports. Self-scope is always derived from the JWT - the UI has no
/// teacher/student/department/section selectors.
class TeacherReportsScreen extends StatefulWidget {
  const TeacherReportsScreen({
    super.key,
    required this.reportRepository,
    this.downloadFile = downloadReportFile,
  });

  final ReportRepository reportRepository;
  final ReportFileDownloader downloadFile;

  @override
  State<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends State<TeacherReportsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  bool _loading = true;
  String? _error;
  List<TeacherReportRow> _rows = const [];

  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _datesInvalid =>
      _startDate != null &&
      _endDate != null &&
      _startDate!.isAfter(_endDate!);

  Future<void> _load() async {
    if (_datesInvalid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.reportRepository.getTeacherReport(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load your attendance report. Please try again.';
        _loading = false;
      });
    }
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

  Future<void> _export(String format) async {
    if (_exporting) return;
    if (_datesInvalid) {
      _showSnack('Start date must not be after end date.');
      return;
    }
    setState(() => _exporting = true);
    try {
      final payload = await widget.reportRepository.exportTeacherReport(
        format,
        startDate: _startDate,
        endDate: _endDate,
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFor(ApiException e) {
    return userMessageFor(e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ReportErrorState(message: _error!, onRetry: _load);
    }
    if (_rows.isEmpty) {
      return const ReportEmptyState(
          message: 'No attendance report data for the current filter.');
    }
    return RefreshIndicator(
      key: const Key('teacher-reports-refresh'),
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Subject')),
              DataColumn(label: Text('Section')),
              DataColumn(label: Text('Present')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Percentage')),
            ],
            rows: [
              for (final r in _rows)
                DataRow(cells: [
                  DataCell(Text('${r.subjectName} (${r.subjectCode})')),
                  DataCell(Text('${r.sectionName} (${r.sectionCode})')),
                  DataCell(Text('${r.presentCount}')),
                  DataCell(Text('${r.totalRecordedCount}')),
                  DataCell(
                      Text(formatReportPercentage(r.percentage),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold))),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}