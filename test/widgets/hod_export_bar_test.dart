import 'dart:async';

import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/widgets/hod/hod_export_bar.dart';
import 'package:dagacs_frontend/widgets/hod/hod_export_summary_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 4A: the export control's own contract.
///
/// The control is the only thing standing between a HOD and a silently wrong or
/// silently missing file, so its lifecycle is asserted directly rather than only
/// through a screen: idle -> generating -> success/failure, the duplicate-click
/// guard, the context lock it reports to its owner, and the wording of every
/// failure it can produce.
///
/// A backend stack trace must never reach these messages. That is asserted for
/// the worst case: an exception whose text *is* a stack trace.
Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('HodExportBar lifecycle', () {
    testWidgets('idle shows both formats and no outcome', (tester) async {
      await tester.pumpWidget(
        _host(
          HodExportBar(
            reportLabel: 'Attendance Matrix',
            onExport: (format) async => 'ok',
          ),
        ),
      );

      expect(find.byKey(const Key('hod-export-excel')), findsOneWidget);
      expect(find.byKey(const Key('hod-export-pdf')), findsOneWidget);
      expect(find.byKey(const Key('hod-export-outcome')), findsNothing);
      expect(find.byKey(const Key('hod-export-disabled')), findsNothing);
    });

    testWidgets('success names the file that was actually saved', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          HodExportBar(
            reportLabel: 'Attendance Matrix',
            onExport: (format) async => 'DAGACS_Attendance_Matrix.xlsx',
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('hod-export-excel')));
      await tester.pumpAndSettle();

      expect(
        find.text('Downloaded DAGACS_Attendance_Matrix.xlsx'),
        findsOneWidget,
      );
      // A success is not offered as a retry.
      expect(find.byKey(const Key('hod-export-retry')), findsNothing);
    });

    testWidgets('generating disables both buttons and shows a spinner', (
      tester,
    ) async {
      final gate = Completer<String>();
      await tester.pumpWidget(
        _host(
          HodExportBar(
            reportLabel: 'Attendance Overview',
            onExport: (format) => gate.future,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('hod-export-excel')));
      await tester.pump();

      // `OutlinedButton.icon` builds a private subclass, so byType would miss it.
      final buttons = tester.widgetList<OutlinedButton>(
        find.byWidgetPredicate((w) => w is OutlinedButton),
      );
      expect(buttons, hasLength(2));
      for (final button in buttons) {
        expect(
          button.onPressed,
          isNull,
          reason: 'both formats must be disabled while generating',
        );
      }
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete('done.xlsx');
      await tester.pumpAndSettle();
    });

    testWidgets('a double tap issues exactly one request', (tester) async {
      var calls = 0;
      final gate = Completer<String>();
      await tester.pumpWidget(
        _host(
          HodExportBar(
            reportLabel: 'Low Attendance',
            onExport: (format) {
              calls++;
              return gate.future;
            },
          ),
        ),
      );

      // Two taps in the same frame: the second must be swallowed by the in-flight
      // guard, not queued behind the first.
      final excel = find.byKey(const Key('hod-export-excel'));
      await tester.tap(excel, warnIfMissed: false);
      await tester.tap(excel, warnIfMissed: false);
      await tester.pump();

      expect(
        calls,
        1,
        reason: 'a duplicate click must not start a second export',
      );

      gate.complete('low.xlsx');
      await tester.pumpAndSettle();
    });

    testWidgets('a failure offers Retry and Retry repeats the same format', (
      tester,
    ) async {
      final formats = <String>[];
      var shouldFail = true;
      await tester.pumpWidget(
        _host(
          HodExportBar(
            reportLabel: 'Low Attendance',
            onExport: (format) async {
              formats.add(format.name);
              if (shouldFail) throw const ApiException.serverError();
              return 'low.xlsx';
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('hod-export-pdf')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hod-export-retry')), findsOneWidget);

      shouldFail = false;
      await tester.tap(find.byKey(const Key('hod-export-retry')));
      await tester.pumpAndSettle();

      expect(
        formats,
        ['pdf', 'pdf'],
        reason:
            'Retry must repeat the format that failed, not default to Excel',
      );
      expect(find.text('Downloaded low.xlsx'), findsOneWidget);
    });
  });

  group('HodExportBar context lock', () {
    testWidgets('onBusyChanged brackets the generation exactly', (
      tester,
    ) async {
      final busy = <bool>[];
      final gate = Completer<String>();
      await tester.pumpWidget(
        _host(
          HodExportBar(
            reportLabel: 'Attendance Matrix',
            onBusyChanged: busy.add,
            onExport: (format) => gate.future,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('hod-export-excel')));
      // pump, not pumpAndSettle: a progress indicator animates forever, so
      // settling would only ever time out while the request is in flight.
      await tester.pump();
      expect(busy, [
        true,
      ], reason: 'the lock is raised before the request starts');

      gate.complete('m.xlsx');
      await tester.pumpAndSettle();
      expect(busy, [true, false], reason: 'the lock is always released');
    });

    testWidgets('a failure also releases the lock', (tester) async {
      final busy = <bool>[];
      await tester.pumpWidget(
        _host(
          HodExportBar(
            reportLabel: 'Attendance Matrix',
            onBusyChanged: busy.add,
            onExport: (format) async => throw const ApiException.forbidden(),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('hod-export-excel')));
      await tester.pumpAndSettle();

      // A failed export must not leave the academic context frozen forever.
      expect(busy, [true, false]);
    });

    testWidgets('becoming disabled mid-generation still releases the lock', (
      tester,
    ) async {
      final busy = <bool>[];
      await tester.pumpWidget(
        _host(
          HodExportBar(
            reportLabel: 'Attendance Matrix',
            onBusyChanged: busy.add,
            enabled: true,
            onExport: (format) async {
              // The owner invalidates its snapshot while the request is in flight -
              // exactly what a context change does.
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return 'm.xlsx';
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('hod-export-excel')));
      await tester.pump();

      await tester.pumpWidget(
        _host(
          HodExportBar(
            reportLabel: 'Attendance Matrix',
            onBusyChanged: busy.add,
            enabled: false,
            disabledReason: 'The report is still loading.',
            onExport: (format) async => 'm.xlsx',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        busy.last,
        false,
        reason: 'a lock that survives disabling the control is a deadlock',
      );
    });
  });

  group('HodExportBar report-type awareness', () {
    testWidgets('each tooltip names the report it will download', (
      tester,
    ) async {
      for (final label in ['Attendance Overview', 'Attendance Matrix']) {
        await tester.pumpWidget(
          _host(
            HodExportBar(
              reportLabel: label,
              onExport: (format) async => 'x.xlsx',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tooltips = tester
            .widgetList<Tooltip>(find.byType(Tooltip))
            .map((t) => t.message)
            .toList();
        expect(
          tooltips,
          contains('Export $label as an Excel spreadsheet'),
          reason: 'a control must state which report it downloads',
        );
        expect(tooltips, contains('Export $label as a PDF'));
      }
    });

    testWidgets('no third "Full Pack" format is offered', (tester) async {
      await tester.pumpWidget(
        _host(
          HodExportBar(
            reportLabel: 'Attendance Matrix',
            onExport: (format) async => 'x.xlsx',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The Context Pack is Phase 4B. Phase 4A previously shipped a "Full Pack"
      // button wired to the *same* xlsx request as Excel, so a control advertised
      // a deliverable that did not exist.
      expect(find.byKey(const Key('hod-export-pack')), findsNothing);
      expect(find.text('Full Pack'), findsNothing);
      expect(find.text('Excel'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
    });
  });

  group('HodExportBar failure wording', () {
    Future<String> messageFor(WidgetTester tester, Object error) async {
      await tester.pumpWidget(
        _host(
          HodExportBar(
            reportLabel: 'Attendance Overview',
            onExport: (format) async => throw error,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('hod-export-excel')));
      await tester.pumpAndSettle();
      return tester
          .widget<Text>(find.byKey(const Key('hod-export-outcome')))
          .data!;
    }

    testWidgets('401 says the session expired', (tester) async {
      expect(
        await messageFor(tester, const ApiException.unauthorized()),
        'Session expired. Please sign in again.',
      );
    });

    testWidgets('403 says not authorized', (tester) async {
      expect(
        await messageFor(tester, const ApiException.forbidden()),
        'You are not authorized to perform this action.',
      );
    });

    testWidgets('400 keeps the backend\'s own actionable contract message', (
      tester,
    ) async {
      // The backend states the exact requirement for an incomplete context, and
      // it is already user-safe, so it is passed through rather than replaced.
      expect(
        await messageFor(
          tester,
          const ApiException.badRequest(
            'Select Academic Session, Program, Semester and Section to view '
            'the Attendance Matrix.',
          ),
        ),
        'Select Academic Session, Program, Semester and Section to view the '
        'Attendance Matrix.',
      );
    });

    testWidgets('a timeout is reported as a connectivity problem', (
      tester,
    ) async {
      expect(
        await messageFor(tester, const ApiException.timeout()),
        'Request timed out. Please check your connection and try again.',
      );
    });

    testWidgets('a network failure is reported as a connectivity problem', (
      tester,
    ) async {
      expect(
        await messageFor(tester, const ApiException.network()),
        'Unable to connect. Check your internet connection.',
      );
    });

    testWidgets('a server failure uses the standardized wording', (
      tester,
    ) async {
      expect(
        await messageFor(tester, const ApiException.serverError()),
        'Something went wrong. Please try again.',
      );
    });

    testWidgets('a client-side guard states its own reason', (tester) async {
      expect(
        await messageFor(
          tester,
          StateError("Open a student to export that student's report."),
        ),
        "Open a student to export that student's report.",
      );
    });

    testWidgets('an untyped failure never leaks internal detail', (
      tester,
    ) async {
      // The old implementation matched `error.toString()` for substrings like
      // '403'. A message that merely *mentions* 403 used to be mis-worded, and a
      // real stack trace used to be swallowed by a generic line. Now the
      // non-HTTP path is always a plain sentence.
      final message = await messageFor(
        tester,
        Exception('java.lang.NullPointerException at Foo.bar(Foo.java:42)'),
      );
      expect(message, 'Export failed. Please try again.');
      expect(message, isNot(contains('java.lang')));
      expect(message, isNot(contains('.java')));
    });
  });

  group('HodExportBar disabled state', () {
    testWidgets('shows the reason instead of the buttons', (tester) async {
      await tester.pumpWidget(
        _host(
          HodExportBar(
            reportLabel: 'Attendance Overview',
            enabled: false,
            disabledReason:
                'The report is still loading. Export is available once '
                'it has loaded.',
            onExport: (format) async => 'x.xlsx',
          ),
        ),
      );

      expect(find.byKey(const Key('hod-export-disabled')), findsOneWidget);
      expect(find.byKey(const Key('hod-export-excel')), findsNothing);
      expect(
        find.text(
          'The report is still loading. Export is available once it '
          'has loaded.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a disabled control issues no request even if tapped', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          HodExportBar(
            reportLabel: 'Attendance Overview',
            enabled: false,
            disabledReason: 'Not loaded.',
            onExport: (format) async {
              calls++;
              return 'x.xlsx';
            },
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('hod-export-disabled')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
    });
  });

  group('HodExportSummaryStrip', () {
    testWidgets('previews the dataset, the range and the load time', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          HodExportSummaryStrip(
            subjectCount: 5,
            studentCount: 60,
            rangeText: '2026-01-01 to 2026-01-31',
            generatedAt: DateTime(2026, 1, 31, 14, 5),
          ),
        ),
      );

      final text = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('hod-export-summary')),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(text, contains('5 subject(s)'));
      expect(text, contains('60 student(s)'));
      expect(text, contains('2026-01-01 to 2026-01-31'));
      expect(text, contains('as of 14:05'));
    });

    testWidgets('an empty report previews as zero, never as absent', (
      tester,
    ) async {
      // A genuinely empty context is still a real, exportable dataset. The strip
      // says so with honest zeros rather than hiding the fact.
      await tester.pumpWidget(
        _host(const HodExportSummaryStrip(subjectCount: 0, studentCount: 0)),
      );

      final text = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('hod-export-summary')),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(text, contains('0 subject(s)'));
      expect(text, contains('0 student(s)'));
    });
  });
}
