import 'package:flutter/material.dart';

import '../../core/theme/dagacs_theme.dart';

/// The two file formats a HOD report can be exported as, plus the optional
/// full-context workbook.
///
/// The format is decided here and passed to the repository as a path segment, so
/// the client never chooses a content type the server did not produce.
enum HodExportFormat { xlsx, pdf }

/// The lifecycle of an export attempt.
///
/// [success] and [failure] are states, not transient toasts: the outcome stays on
/// screen until the next attempt so a HOD cannot believe a download happened when
/// it did not. This is the "never silently fail" requirement made structural.
enum HodExportState { idle, generating, success, failure }

/// The academic context a report on screen was actually loaded for.
///
/// Captured when the report loads, not read at export time, so a context or date
/// change cannot make the download describe something the reader is no longer
/// looking at.
class HodExportContext {
  const HodExportContext({
    this.academicSessionId,
    this.programId,
    this.semesterId,
    this.sectionId,
    this.subjectId,
    this.startDate,
    this.endDate,
  });

  final int? academicSessionId;
  final int? programId;
  final int? semesterId;
  final int? sectionId;
  final int? subjectId;
  final DateTime? startDate;
  final DateTime? endDate;

  /// True when the four mandatory levels for a cross-tab are all chosen.
  bool get hasFullContext =>
      academicSessionId != null &&
      programId != null &&
      semesterId != null &&
      sectionId != null;
}

/// The professional export control for the HOD reports.
///
/// Owns the whole attempt lifecycle so every HOD screen behaves identically:
///
/// * **idle** - the buttons are enabled and the selected context is intact.
/// * **generating** - both buttons are disabled and show a spinner, so a double
///   click can never start a second download.
/// * **success** - an inline confirmation naming the file that was actually
///   saved, so the reader knows exactly which export landed.
/// * **failure** - an inline, actionable message with a Retry action. A 403 says
///   so in plain words instead of a generic failure.
///
/// Every state is expressed with an icon *and* text, never by colour alone, and
/// each button carries a semantic label and a tooltip so the control is usable
/// with a screen reader and by keyboard.
class HodExportBar extends StatefulWidget {
  const HodExportBar({
    super.key,
    required this.onExport,
    this.enabled = true,
    this.disabledReason,
    this.showPack = false,
    this.leading,
  });

  /// Performs the export for [format] and returns the name of the saved file.
  ///
  /// Implemented by the caller, which owns the repository and the platform
  /// downloader. Throwing surfaces as [HodExportState.failure].
  final Future<String> Function(HodExportFormat format) onExport;

  /// False while the report is still loading or no academic context is chosen.
  ///
  /// Exporting before the screen has data is how a file ends up describing a
  /// context the reader is not looking at, so the control stays disabled.
  final bool enabled;

  /// Shown instead of the buttons when [enabled] is false.
  final String? disabledReason;

  /// Offers the full-context workbook alongside the two single-file formats.
  final bool showPack;

  /// Optional content placed before the buttons, e.g. a summary strip.
  final Widget? leading;

  @override
  State<HodExportBar> createState() => _HodExportBarState();
}

class _HodExportBarState extends State<HodExportBar> {
  HodExportState _state = HodExportState.idle;
  String? _message;

  bool get _busy => _state == HodExportState.generating;

  Future<void> _run(HodExportFormat format) async {
    // Belt and braces: the buttons are already disabled while busy, but a
    // programmatic double tap must not slip a second request through.
    if (_busy || !widget.enabled) return;
    setState(() {
      _state = HodExportState.generating;
      _message = null;
    });
    try {
      final fileName = await widget.onExport(format);
      if (!mounted) return;
      setState(() {
        _state = HodExportState.success;
        _message = 'Downloaded $fileName';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = HodExportState.failure;
        _message = _messageFor(error);
      });
    }
  }

  /// Turns a failure into something a HOD can act on.
  static String _messageFor(Object error) {
    final text = error.toString();
    if (text.contains('403')) {
      return 'You are not authorized to export this report.';
    }
    if (text.contains('400')) {
      return 'Select a complete academic context before exporting.';
    }
    if (text.contains('Failed to load')) {
      return 'The report is not loaded yet. Wait for it to finish, then export.';
    }
    return 'Export failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return _Disabled(
        reason: widget.disabledReason ??
            'Choose the academic context to export this report.',
        leading: widget.leading,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.leading != null) ...[
          widget.leading!,
          const SizedBox(height: DagacsSpace.xs),
        ],
        Row(
          children: [
            Expanded(
              child: _ExportButton(
                key: const Key('hod-export-excel'),
                icon: Icons.table_chart,
                label: 'Excel',
                tooltip: 'Export this report as an Excel spreadsheet',
                busy: _busy,
                active: _busy,
                onPressed: () => _run(HodExportFormat.xlsx),
              ),
            ),
            const SizedBox(width: DagacsSpace.sm),
            Expanded(
              child: _ExportButton(
                key: const Key('hod-export-pdf'),
                icon: Icons.picture_as_pdf,
                label: 'PDF',
                tooltip: 'Export this report as a PDF',
                busy: _busy,
                active: _busy,
                onPressed: () => _run(HodExportFormat.pdf),
              ),
            ),
            if (widget.showPack) ...[
              const SizedBox(width: DagacsSpace.sm),
              Expanded(
                child: _ExportButton(
                  key: const Key('hod-export-pack'),
                  icon: Icons.folder_zip_outlined,
                  label: 'Full Pack',
                  tooltip: 'Export the matrix, subject summary and low attendance '
                      'as one Excel workbook',
                  busy: _busy,
                  active: _busy,
                  onPressed: () => _run(HodExportFormat.xlsx),
                ),
              ),
            ],
          ],
        ),
        if (_state == HodExportState.success ||
            _state == HodExportState.failure) ...[
          const SizedBox(height: DagacsSpace.xs),
          _Outcome(
            state: _state,
            message: _message ?? '',
            onRetry: _state == HodExportState.failure
                ? () => _run(HodExportFormat.xlsx)
                : null,
          ),
        ],
      ],
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.busy,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool busy;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: !busy,
        label: tooltip,
        child: OutlinedButton.icon(
          onPressed: busy ? null : onPressed,
          icon: active
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.state,
    required this.message,
    this.onRetry,
  });

  final HodExportState state;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = state == HodExportState.failure;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        children: [
          Icon(
            failed ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            // Never colour alone: the icon shape and the text both carry it.
            color: failed ? DagacsColors.error : DagacsColors.success,
          ),
          const SizedBox(width: DagacsSpace.xs),
          Expanded(
            child: Text(
              message,
              key: const Key('hod-export-outcome'),
              style: DagacsTextStyles.caption,
            ),
          ),
          if (onRetry != null)
            TextButton(
              key: const Key('hod-export-retry'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

class _Disabled extends StatelessWidget {
  const _Disabled({required this.reason, this.leading});

  final String reason;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(height: DagacsSpace.xs),
        ],
        Row(
          children: [
            const Icon(Icons.lock_outline,
                size: 18, color: DagacsColors.textSecondary),
            const SizedBox(width: DagacsSpace.xs),
            Expanded(
              child: Text(
                reason,
                key: const Key('hod-export-disabled'),
                style: DagacsTextStyles.caption,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
