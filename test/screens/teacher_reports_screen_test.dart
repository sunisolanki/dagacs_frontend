import 'dart:async';
import 'dart:typed_data';

import 'package:dagacs_frontend/core/navigation/navigator.dart';
import 'package:dagacs_frontend/models/report_export.dart';
import 'package:dagacs_frontend/models/student_wise_report.dart';
import 'package:dagacs_frontend/models/teacher_assignment.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/report_repository.dart';
import 'package:dagacs_frontend/repositories/teacher_repository.dart';
import 'package:dagacs_frontend/screens/student_wise_report_screen.dart';
import 'package:dagacs_frontend/screens/teacher_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReportRepository extends ReportRepository {
  _FakeReportRepository({this.report});

  StudentWiseReport? report;
  Object? error;
  Completer<void>? exportGate;

  final List<({
    int? subjectId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate
  })> reportCalls = [];
  final List<({String format})> exportCalls = [];

  @override
  Future<StudentWiseReport> getStudentWiseReport({
    int? subjectId,
    int? sectionId,
    int? batchId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    reportCalls.add((
      subjectId: subjectId,
      sectionId: sectionId,
      startDate: startDate,
      endDate: endDate
    ));
    if (error != null) throw error!;
    return report ?? StudentWiseReport(columns: const [], rows: const []);
  }

  @override
  Future<DownloadPayload> exportStudentWiseReport(
    String format, {
    int? subjectId,
    int? sectionId,
    int? batchId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    exportCalls.add((format: format));
    if (exportGate != null) {
      return exportGate!.future.then((_) =>
          DownloadPayload(bytes: Uint8List.fromList([1]), fileName: 'x.xlsx'));
    }
    return Future.value(
        DownloadPayload(bytes: Uint8List.fromList([1]), fileName: 'x.xlsx'));
  }
}

class _FakeTeacherRepository extends TeacherRepository {
  _FakeTeacherRepository([this.assignments = _assignments]);

  List<TeacherAssignment> assignments;
  Object? error;

  @override
  Future<List<TeacherAssignment>> getMyAssignments() async {
    if (error != null) throw error!;
    return assignments;
  }
}

const _assignments = [
  TeacherAssignment(
    subjectId: 1,
    subjectName: 'DBMS',
    subjectCode: 'CS301',
    sectionId: 10,
    sectionName: 'CSE-A',
    sectionCode: 'A',
  ),
  TeacherAssignment(
    subjectId: 2,
    subjectName: 'DSA',
    subjectCode: 'CS302',
    sectionId: 11,
    sectionName: 'CSE-B',
    sectionCode: 'B',
  ),
];

/// Rahul is present, present, absent. Priya is present, absent and has NO record
/// at all for the third session (never marked) - that cell must render `A`.
StudentWiseReport get _report => StudentWiseReport(
      subjectId: 1,
      subjectName: 'DBMS',
      sectionId: 10,
      sectionName: 'CSE-A',
      columns: const [
        StudentWiseColumn(sessionId: 100, date: '2026-08-12', lecturePeriod: 'LP1'),
        StudentWiseColumn(sessionId: 101, date: '2026-08-14', lecturePeriod: 'LP1'),
        StudentWiseColumn(sessionId: 102, date: '2026-08-18', lecturePeriod: 'LP1'),
      ],
      rows: const [
        StudentWiseRow(
          studentId: 1,
          enrollmentNumber: 'DAGACS001',
          name: 'Rahul Sharma',
          presentCount: 2,
          totalRecordedCount: 3,
          percentage: 66.666666,
          cells: [
            StudentWiseCell(sessionId: 100, status: 'PRESENT', isPresent: true),
            StudentWiseCell(sessionId: 101, status: 'PRESENT', isPresent: true),
            StudentWiseCell(sessionId: 102, status: 'ABSENT', isPresent: false),
          ],
        ),
        StudentWiseRow(
          studentId: 2,
          enrollmentNumber: 'DAGACS002',
          name: 'Priya Verma',
          presentCount: 1,
          totalRecordedCount: 3,
          percentage: 33.333333,
          cells: [
            StudentWiseCell(sessionId: 100, status: 'PRESENT', isPresent: true),
            StudentWiseCell(sessionId: 101, status: 'ABSENT', isPresent: false),
            // session 102 intentionally unmarked -> no cell at all
          ],
        ),
      ],
    );

Widget _wrap(
  _FakeReportRepository report,
  _FakeTeacherRepository teacher, {
  Future<String> Function(Uint8List, String, String?)? download,
  Widget? app,
}) {
  return MaterialApp(
    home: app ??
        TeacherReportsScreen(
          reportRepository: report,
          teacherRepository: teacher,
          downloadFile: download ?? (_, _, _) async => 'ok',
        ),
  );
}

/// Picks a subject, a section, then generates.
Future<void> _generate(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('register-subject')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('DBMS (CS301)').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('register-section')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('CSE-A (A)').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('register-generate')));
  await tester.pumpAndSettle();
}

void main() {
  group('Teacher Reports is the student-wise, date-wise register', () {
    testWidgets('shows the DAGACS title block and the register table',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await tester.pumpAndSettle();

      // Filter controls are present before anything is generated.
      expect(find.byKey(const Key('register-subject')), findsOneWidget);
      expect(find.byKey(const Key('register-section')), findsOneWidget);
      expect(find.byKey(const Key('register-generate')), findsOneWidget);
      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('End date'), findsOneWidget);

      await _generate(tester);

      expect(find.text('DAGACS - Teacher Attendance Report'), findsOneWidget);
      // Scope line mirrors the Excel/PDF metadata row.
      final scope = tester.widget<Text>(
          find.byKey(const Key('register-report-scope')));
      expect(scope.data, contains('DBMS (CS301)'));
      expect(scope.data, contains('CSE-A (A)'));
      expect(scope.data, contains('All dates'));

      // Identity + totals columns, and no Roll Number anywhere.
      expect(find.text('Enrollment'), findsOneWidget);
      expect(find.text('Student'), findsOneWidget);
      expect(find.text('Total Present'), findsOneWidget);
      expect(find.text('Total Classes'), findsOneWidget);
      expect(find.text('Percentage'), findsOneWidget);
      expect(find.textContaining('Roll'), findsNothing);

      expect(find.text('DAGACS001'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('DAGACS002'), findsOneWidget);
      expect(find.text('Priya Verma'), findsOneWidget);
    });

    testWidgets('one column per conducted session date, header shows date and period',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      // Each session date gets its own column header, date + lecture period.
      expect(find.text('2026-08-12\nLP1'), findsOneWidget);
      expect(find.text('2026-08-14\nLP1'), findsOneWidget);
      expect(find.text('2026-08-18\nLP1'), findsOneWidget);
    });

    testWidgets('unmarked attendance renders A, never a blank cell',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      // Rahul: P, P, A   Priya: P, A, and the unmarked session must be A.
      final marks = tester
          .widgetList<Text>(find.descendant(
              of: find.byType(DataTable), matching: find.text('P')))
          .length;
      final absents = tester
          .widgetList<Text>(find.descendant(
              of: find.byType(DataTable), matching: find.text('A')))
          .length;

      expect(marks, 3, reason: 'three P marks across both students');
      // Rahul absent once + Priya absent once + Priya unmarked once.
      expect(absents, 3,
          reason: 'every absent or unmarked session shows A');
    });

    testWidgets('percentage is shown to two decimals', (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      expect(find.text('66.67%'), findsOneWidget);
      expect(find.text('33.33%'), findsOneWidget);
      expect(find.text('66.7%'), findsNothing);
    });

    testWidgets('summary strip reports students, sessions and average',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      final summary = find.byKey(const Key('register-summary'));
      expect(find.descendant(of: summary, matching: find.text('Students: ')),
          findsOneWidget);
      expect(find.descendant(of: summary, matching: find.text('2')), findsOneWidget);
      expect(
          find.descendant(of: summary, matching: find.text('Sessions: ')),
          findsOneWidget);
      expect(find.descendant(of: summary, matching: find.text('3')), findsOneWidget);
      expect(
          find.descendant(of: summary, matching: find.text('Average: ')),
          findsOneWidget);
      // Mean of 66.67 and 33.33.
      expect(find.descendant(of: summary, matching: find.text('50.00%')),
          findsOneWidget);
    });

    testWidgets('changing the subject clears the class and the previous report',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);
      expect(find.text('Rahul Sharma'), findsOneWidget);

      await tester.tap(find.byKey(const Key('register-subject')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DSA (CS302)').last);
      await tester.pumpAndSettle();

      expect(find.text('Rahul Sharma'), findsNothing,
          reason: 'the old report must be dropped when the subject changes');
      expect(find.textContaining('Select a subject and section'),
          findsOneWidget);
    });
  });

  group('Teacher Reports filters and states', () {
    testWidgets('subject and section cascade into the request', (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      expect(report.reportCalls.length, 1);
      expect(report.reportCalls.single.subjectId, 1);
      expect(report.reportCalls.single.sectionId, 10);
    });

    testWidgets('date range is passed to the report request', (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      await tester.tap(find.text('Start date'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(CalendarDatePicker), matching: find.text('15')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(report.reportCalls.length, 2);
      expect(report.reportCalls.last.startDate, isNotNull);
      expect(report.reportCalls.last.startDate!.day, 15);
    });

    testWidgets('a start date after the end date blocks the request',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      // Pick an end date first; that valid range does reload.
      await tester.tap(find.text('End date'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(CalendarDatePicker), matching: find.text('10')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final before = report.reportCalls.length;
      expect(before, 2, reason: 'generate + the valid end-date reload');

      // Now a start date AFTER the end date: rejected client-side.
      await tester.tap(find.text('Start date'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(CalendarDatePicker), matching: find.text('20')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Start date must not be after end date.'),
          findsWidgets);
      expect(report.reportCalls.length, before,
          reason: 'an invalid range must never reach the API');
      expect(
          find.byKey(const Key('register-generate')), findsOneWidget);
    });

    testWidgets('a teacher with no assignments gets an empty state',
        (tester) async {
      final report = _FakeReportRepository();
      await tester
          .pumpWidget(_wrap(report, _FakeTeacherRepository(const [])));
      await tester.pumpAndSettle();

      expect(find.textContaining('no teaching assignments'), findsOneWidget);
      expect(find.byKey(const Key('register-generate')), findsNothing);
    });

    testWidgets('an empty report shows an empty state, not an error',
        (tester) async {
      final report = _FakeReportRepository(
          report: StudentWiseReport(columns: const [], rows: const []));
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      expect(find.textContaining('No attendance data'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('an API failure shows a retryable error and retries',
        (tester) async {
      final report = _FakeReportRepository()
        ..error = const ApiException.serverError();
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      expect(find.text('Something went wrong. Please try again.'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      report.error = null;
      report.report = _report;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(report.reportCalls.length, 2);
      expect(find.text('Rahul Sharma'), findsOneWidget);
    });

    testWidgets('an assignment load failure is surfaced', (tester) async {
      final report = _FakeReportRepository();
      final teacher = _FakeTeacherRepository()..error = const ApiException.serverError();
      await tester.pumpWidget(_wrap(report, teacher));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong. Please try again.'),
          findsOneWidget);
    });
  });

  group('Teacher Reports exports', () {
    testWidgets('Excel export downloads the xlsx payload', (tester) async {
      final report = _FakeReportRepository(report: _report);
      final downloaded = <String>[];
      await tester.pumpWidget(_wrap(
        report,
        _FakeTeacherRepository(),
        download: (bytes, name, type) async {
          downloaded.add(name);
          return 'Downloaded $name';
        },
      ));
      await _generate(tester);

      await tester.tap(find.byKey(const Key('export-excel')));
      await tester.pumpAndSettle();

      expect(report.exportCalls.single.format, 'xlsx');
      expect(downloaded.single, isNotEmpty);
      expect(find.textContaining('Downloaded'), findsOneWidget);
    });

    testWidgets('PDF export requests the pdf format', (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      await tester.tap(find.byKey(const Key('export-pdf')));
      await tester.pumpAndSettle();

      expect(report.exportCalls.single.format, 'pdf');
    });

    testWidgets('a 403 export shows the authorization message', (tester) async {
      final report = _ThrowingReportRepository();
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      await tester.tap(find.byKey(const Key('export-pdf')));
      await tester.pumpAndSettle();

      expect(find.text('You are not authorized to perform this action.'),
          findsOneWidget);
    });

    testWidgets('an in-flight export blocks a duplicate request', (tester) async {
      final report = _FakeReportRepository(report: _report)
        ..exportGate = Completer<void>();
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      await tester.tap(find.byKey(const Key('export-excel')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('export-pdf')));
      await tester.pump();

      expect(report.exportCalls.length, 1);
      report.exportGate!.complete();
      await tester.pumpAndSettle();
      expect(report.exportCalls.length, 1);
    });

    testWidgets('export controls only appear once a class is selected',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export-excel')), findsNothing);
      expect(find.byKey(const Key('export-pdf')), findsNothing);
    });
  });

  group('Teacher Reports navigation and layout', () {
    testWidgets('the student-wise deep link still renders the same register',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.teacherStudentWise) {
            return MaterialPageRoute(
                builder: (_) => StudentWiseReportScreen(
                    reportRepository: report,
                    teacherRepository: _FakeTeacherRepository()));
          }
          return MaterialPageRoute(builder: (_) => const SizedBox.shrink());
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context)
                  .pushNamed(AppRoutes.teacherStudentWise),
              child: const Text('go'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Student-Wise Register'), findsOneWidget);
      expect(find.byKey(const Key('register-subject')), findsOneWidget);

      await _generate(tester);
      expect(find.text('DAGACS - Teacher Attendance Report'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
    });

    testWidgets('stacks the selectors on a narrow viewport', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      expect(find.byKey(const Key('register-subject')), findsOneWidget);
      expect(find.byKey(const Key('register-section')), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
    });
  });
}

class _ThrowingReportRepository extends _FakeReportRepository {
  @override
  Future<DownloadPayload> exportStudentWiseReport(
    String format, {
    int? subjectId,
    int? sectionId,
    int? batchId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return Future.error(const ApiException.forbidden());
  }
}
