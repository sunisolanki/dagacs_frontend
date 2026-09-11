import 'package:flutter/material.dart';

import '../models/report_page.dart';
import '../models/hod_coverage_row.dart';
import '../models/hod_daily_lecture_row.dart';
import '../models/hod_low_attendance.dart';
import '../models/hod_rollup.dart';
import '../network/api_exception.dart';
import '../repositories/hod_repository.dart';
import '../repositories/report_repository.dart';
import '../services/report_file_downloader.dart';
import '../widgets/report_widgets.dart';

/// HOD Reports (M7.3).
///
/// Select one of the five supported report types (daily-lecture, coverage,
/// monthly, quarterly, low-attendance), apply an optional inclusive date range,
/// preview the report data from the M7.1 feeds, and download the M7.2 Excel/PDF
/// exports. Department scope always comes from the JWT - no department/ids are
/// selected in the UI. Semester is NOT offered (not derivable by the backend).
class HodReportsScreen extends StatefulWidget {
  const HodReportsScreen({
    super.key,
    required this.hodRepository,
    required this.reportRepository,
    this.downloadFile = downloadReportFile,
  });

  final HodRepository hodRepository;
  final ReportRepository reportRepository;
  final ReportFileDownloader downloadFile;

  @override
  State<HodReportsScreen> createState() => _HodReportsScreenState();
}

class _ReportOption {
  const _ReportOption(this.value, this.label);

  final String value;
  final String label;
}

const _reportOptions = [
  _ReportOption('daily-lecture', 'Daily Lecture'),
  _ReportOption('coverage', 'Coverage'),
  _ReportOption('monthly', 'Monthly'),
  _ReportOption('quarterly', 'Quarterly'),
  _ReportOption('low-attendance', 'Low Attendance'),
];

class _HodReportsScreenState extends State<HodReportsScreen> {
  String _reportType = 'daily-lecture';
  DateTime? _startDate;
  DateTime? _endDate;

  int _page = 0;
  static const int _pageSize = 20;

  bool _loading = true;
  String? _error;

  bool _exporting = false;

  ReportPage<HodDailyLectureRow>? _daily;
  ReportPage<HodCoverageRow>? _coverage;
  List<HodRollup>? _rollups;
  List<HodLowAttendance>? _low;

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
      switch (_reportType) {
        case 'monthly':
          _rollups = await widget.hodRepository.getRollups(
              type: 'monthly', startDate: _startDate, endDate: _endDate);
          break;
        case 'quarterly':
          _rollups = await widget.hodRepository.getRollups(
              type: 'quarterly', startDate: _startDate, endDate: _endDate);
          break;
        case 'low-attendance':
          _low = await widget.hodRepository
              .getLowAttendance(startDate: _startDate, endDate: _endDate);
          break;
        case 'coverage':
          _coverage = await widget.reportRepository.getCoverage(
              page: _page,
              size: _pageSize,
              startDate: _startDate,
              endDate: _endDate);
          break;
        case 'daily-lecture':
        default:
          _daily = await widget.reportRepository.getDailyLecture(
              page: _page,
              size: _pageSize,
              startDate: _startDate,
              endDate: _endDate);
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
    setState(() => _exporting = true);
    try {
      final payload = await widget.reportRepository.exportHodReport(
        _reportType,
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
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in _reportOptions)
                    ChoiceChip(
                      key: Key('report-type-${option.value}'),
                      label: Text(option.label),
                      selected: _reportType == option.value,
                      onSelected: (_) => _selectType(option.value),
                    ),
                ],
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
        _buildPaginationBar(),
      ],
    );
  }

  Widget _buildPaginationBar() {
    final paginated = _reportType == 'daily-lecture' || _reportType == 'coverage';
    if (!paginated) return const SizedBox.shrink();
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
      _reportOptions.firstWhere((o) => o.value == _reportType).label;

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