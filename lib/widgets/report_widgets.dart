import 'package:flutter/material.dart';

/// Shared M7.3 report date-range bar (start / end / clear), mirroring the
/// existing HOD dashboard filter pattern (`showDatePicker` + reset).
///
/// Dates are displayed as `YYYY-MM-DD` and serialized the same way by the
/// repository; locale-formatted strings are never sent to the backend.
class ReportDateBar extends StatelessWidget {
  const ReportDateBar({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClear,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilter = startDate != null || endDate != null;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickStart,
            icon: const Icon(Icons.date_range),
            label: Text(startDate == null ? 'Start date' : _format(startDate!)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickEnd,
            icon: const Icon(Icons.date_range),
            label: Text(endDate == null ? 'End date' : _format(endDate!)),
          ),
        ),
        if (hasFilter) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: onClear,
            tooltip: 'Clear dates',
            icon: const Icon(Icons.clear),
          ),
        ],
      ],
    );
  }

  static String _format(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Excel / PDF export actions for an M7.2 export file.
///
/// Both buttons are disabled while [exporting] so a single in-flight export can
/// never be triggered twice.
class ReportExportButtons extends StatelessWidget {
  const ReportExportButtons({
    super.key,
    required this.exporting,
    required this.onExcel,
    required this.onPdf,
  });

  final bool exporting;
  final VoidCallback onExcel;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    final excelLabel = exporting
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.table_chart);
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const Key('export-excel'),
            onPressed: exporting ? null : onExcel,
            icon: excelLabel,
            label: const Text('Excel'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            key: const Key('export-pdf'),
            onPressed: exporting ? null : onPdf,
            icon: exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: const Text('PDF'),
          ),
        ),
      ],
    );
  }
}

/// Empty data state (not an error).
class ReportEmptyState extends StatelessWidget {
  const ReportEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Retryable error state (5xx / network / unexpected failures).
class ReportErrorState extends StatelessWidget {
  const ReportErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('report-retry'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats a backend percentage the way the existing HOD dashboard does
/// (`null` renders as "No data", whole numbers drop the trailing `.0`).
String formatReportPercentage(double? value) {
  if (value == null) return 'No data';
  final text = value.toString();
  final trimmed =
      text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  return '$trimmed%';
}