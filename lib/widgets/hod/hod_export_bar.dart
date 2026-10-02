import 'package:flutter/material.dart';

import '../../core/theme/dagacs_theme.dart';
import '../../network/api_exception.dart';

/// The two file formats a HOD report can be exported as.
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
///   click can never start a second download, and the academic context is
///   <b>locked</b> through [onBusyChanged] so it cannot be changed underneath
///   the in-flight request.
/// * **success** - an inline confirmation naming the file that was actually
///   saved, so the reader knows exactly which export landed.
/// * **failure** - an inline, actionable message with a Retry action. A 403 says
///   so in plain words instead of a generic failure.
///
/// Every state is expressed with an icon *and* text, never by colour alone, and
/// each button carries a semantic label and a tooltip so the control is usable
/// with a screen reader and by keyboard.
///
/// <b>Report-type awareness.</b> [reportLabel] names the report the buttons will
/// actually download, so a control can never be presented as one report and
/// quietly produce another. It is a required parameter precisely because
/// omitting it is how the wrong-report export bug shipped.
class HodExportBar extends StatefulWidget {
  const HodExportBar({
    super.key,
    required this.onExport,
    required this.reportLabel,
    this.enabled = true,
    this.disabledReason,
    this.onBusyChanged,
    this.leading,
  });

  /// Performs the export for [format] and returns a truthful description of what
  /// happened to the file.
  ///
  /// Implemented by the caller, which owns the repository and the platform
  /// downloader. Throwing surfaces as [HodExportState.failure].
  ///
  /// **Phase 5.1.** The returned string is shown verbatim. This used to be
  /// ignored in favour of a hard-coded `Downloaded <fileName>`, which on a phone
  /// was a lie: the bytes were in app-private storage the user could not open.
  /// On the web the downloader returns `Downloaded <fileName>`, so the wording a
  /// web user sees is unchanged.
  final Future<String> Function(HodExportFormat format) onExport;

  /// The human name of the report these buttons download, e.g.
  /// `Attendance Matrix`. Used in the tooltips and the semantic labels so the
  /// control states what it will do instead of showing a generic "Export".
  final String reportLabel;

  /// False while the report is still loading or no academic context is chosen.
  ///
  /// Exporting before the screen has data is how a file ends up describing a
  /// context the reader is not looking at, so the control stays disabled.
  final bool enabled;

  /// Shown instead of the buttons when [enabled] is false.
  final String? disabledReason;

  /// Called with true when a generation starts and false when it ends.
  ///
  /// The owner uses this to lock the academic-context bar and the date filter
  /// for the duration, which is what makes it structurally impossible to switch
  /// section while a file is being produced for the old one.
  final ValueChanged<bool>? onBusyChanged;

  /// Optional content placed before the buttons, e.g. a summary strip.
  final Widget? leading;

  @override
  State<HodExportBar> createState() => _HodExportBarState();
}

class _HodExportBarState extends State<HodExportBar> {
  HodExportState _state = HodExportState.idle;
  String? _message;

  bool get _busy => _state == HodExportState.generating;

  /// The format the in-flight attempt is using, so a Retry repeats exactly what
  /// failed instead of silently defaulting to Excel.
  HodExportFormat? _lastFormat;

  @override
  void didUpdateWidget(HodExportBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Becoming disabled while a generation is in flight (for example because the
    // context bar invalidated the snapshot) must still release the lock, or the
    // academic context would stay frozen forever.
    if (_busy && !widget.enabled) {
      setState(() {
        _state = HodExportState.idle;
        _message = null;
      });
      _setBusy(false);
    }
  }

  @override
  void dispose() {
    // Never leave the parent with a stale "busy" flag after teardown.
    if (_busy) _setBusy(false);
    super.dispose();
  }

  void _setBusy(bool value) {
    if (widget.onBusyChanged == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onBusyChanged!(value);
    });
  }

  Future<void> _run(HodExportFormat format) async {
    // Belt and braces: the buttons are already disabled while busy, but a
    // programmatic double tap must not slip a second request through.
    if (_busy || !widget.enabled) return;
    setState(() {
      _state = HodExportState.generating;
      _message = null;
      _lastFormat = format;
    });
    _setBusy(true);
    try {
      final status = await widget.onExport(format);
      if (!mounted) return;
      setState(() {
        _state = HodExportState.success;
        // The downloader owns this sentence. Phase 5.1 stopped replacing it with
        // a fixed "Downloaded ...", which on a phone claimed a file had been
        // saved when it was in private storage the user could not reach.
        _message = status;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = HodExportState.failure;
        _message = messageForExportFailure(error);
      });
    } finally {
      _setBusy(false);
    }
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
                tooltip: 'Export ${widget.reportLabel} as an Excel spreadsheet',
                busy: _busy,
                active: _busy && _lastFormat == HodExportFormat.xlsx,
                onPressed: () => _run(HodExportFormat.xlsx),
              ),
            ),
            const SizedBox(width: DagacsSpace.sm),
            Expanded(
              child: _ExportButton(
                key: const Key('hod-export-pdf'),
                icon: Icons.picture_as_pdf,
                label: 'PDF',
                tooltip: 'Export ${widget.reportLabel} as a PDF',
                busy: _busy,
                active: _busy && _lastFormat == HodExportFormat.pdf,
                onPressed: () => _run(HodExportFormat.pdf),
              ),
            ),
          ],
        ),
        if (_state == HodExportState.success ||
            _state == HodExportState.failure) ...[
          const SizedBox(height: DagacsSpace.xs),
          _Outcome(
            state: _state,
            message: _message ?? '',
            onRetry: _state == HodExportState.failure
                ? () => _run(_lastFormat ?? HodExportFormat.xlsx)
                : null,
          ),
        ],
      ],
    );
  }
}

/// Turns a failed export attempt into something a HOD can act on.
///
/// <b>Typed, never string-matched.</b> This previously inspected
/// `error.toString()` for substrings like `'403'`, which silently degraded to a
/// generic "Export failed" the moment a message was reworded and could not
/// distinguish a 401 from a timeout. It now routes every
/// [ApiException] through the application's single canonical mapper
/// [userMessageFor], so an export failure is worded exactly like every other
/// failure in the app and a backend stack trace can never reach the reader.
///
/// One deliberate addition: the *not loaded yet* case is a first-class message
/// rather than a generic failure, because it is the one failure a HOD can fix by
/// simply waiting.
String messageForExportFailure(Object error) {
  if (error is ApiException) {
    final canonical = userMessageFor(error);
    // A 400 from an export is almost always an incomplete academic context, and
    // the backend's own contract text is already actionable, so it is shown.
    if (error.statusCode == 400 && error.message.isNotEmpty) {
      return error.message;
    }
    return canonical;
  }
  if (error is StateError) {
    // Raised by the client-side guard before any request is issued, so no
    // network, no server and no file was involved.
    return error.message.isEmpty
        ? 'The report is not ready to export yet.'
        : error.message;
  }
  return 'Export failed. Please try again.';
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
