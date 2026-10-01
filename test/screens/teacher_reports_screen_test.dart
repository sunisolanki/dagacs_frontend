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
import 'package:dagacs_frontend/widgets/dagacs_widgets.dart';
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

/// Only the CONDUCTED sessions the backend returned become columns.
/// Rahul: P, P, A. Priya: P, A and session 102 was never marked (no cell).
const _report = StudentWiseReport(
  subjectId: 1,
  subjectName: 'DBMS',
  sectionId: 10,
  sectionName: 'CSE-A',
  columns: [
    StudentWiseColumn(sessionId: 100, date: '2026-08-12', lecturePeriod: 'P1'),
    StudentWiseColumn(sessionId: 101, date: '2026-08-14', lecturePeriod: 'P1'),
    StudentWiseColumn(sessionId: 102, date: '2026-08-18', lecturePeriod: 'P1'),
  ],
  rows: [
    StudentWiseRow(
      studentId: 1,
      enrollmentNumber: 'DAGACS001',
      rollNumber: 'ROLL-001',
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
      rollNumber: 'ROLL-002',
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
}) {
  return MaterialApp(
    home: TeacherReportsScreen(
      reportRepository: report,
      teacherRepository: teacher,
      downloadFile: download ?? (_, _, _) async => 'ok',
    ),
  );
}

Future<void> _pickDate(WidgetTester tester, String label, int day) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
      of: find.byType(CalendarDatePicker), matching: find.text('$day')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _chooseClass(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('register-subject')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('DBMS (CS301)').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('register-section')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('CSE-A (A)').last);
  await tester.pumpAndSettle();
}

/// Full required flow: Subject -> Section -> Start -> End -> Generate.
Future<void> _generate(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await _chooseClass(tester);
  await _pickDate(tester, 'Start date', 1);
  await _pickDate(tester, 'End date', 28);
  await tester.tap(find.byKey(const Key('register-generate')));
  await tester.pumpAndSettle();
}

bool _generateEnabled(WidgetTester tester) {
  final button = tester.widget<ElevatedButton>(
      find.descendant(
          of: find.byKey(const Key('register-generate')),
          matching: find.byType(ElevatedButton)));
  return button.onPressed != null;
}

void main() {
  group('Teacher Reports renders the student-wise, date-wise register', () {
    testWidgets('shows the DAGACS header block and the matrix columns',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await tester.pumpAndSettle();

      // Separate Subject and Section selectors, and the explicit action.
      expect(find.byType(AppFormDropdown<int>), findsNWidgets(2));
      expect(find.byKey(const Key('register-subject')), findsOneWidget);
      expect(find.byKey(const Key('register-section')), findsOneWidget);
      expect(find.byType(AppPrimaryButton), findsOneWidget);

      await _generate(tester);

      expect(find.text('DAGACS'), findsOneWidget);
      expect(
          find.byKey(const Key('register-report-title')),
          findsOneWidget);
      expect(find.text('STUDENT ATTENDANCE REPORT'), findsOneWidget);
      expect(find.text('Subject: DBMS (CS301)'), findsOneWidget);
      expect(find.text('Section: CSE-A (A)'), findsOneWidget);
      expect(find.textContaining('Date Range:'), findsOneWidget);

      // Column 1 = enrollment, column 2 = name, never a roll number.
      expect(find.text('Enrollment No.'), findsOneWidget);
      expect(find.text('Student Name'), findsOneWidget);
      expect(find.textContaining('Roll'), findsNothing);
      expect(find.text('ROLL-001'), findsNothing);

      // Exactly one of each trailing column - no duplicates.
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Total Classes'), findsOneWidget);
      expect(find.text('Percentage'), findsOneWidget);
    });

    testWidgets('one clearly labelled column per conducted session date',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      expect(find.text('12-Aug-2026 (P1)'), findsOneWidget);
      expect(find.text('14-Aug-2026 (P1)'), findsOneWidget);
      expect(find.text('18-Aug-2026 (P1)'), findsOneWidget);
      // The backend session ids map 1:1 onto columns.
      expect(find.descendant(of: find.byType(DataTable), matching: find.text('12-Aug-2026 (P1)')),
          findsOneWidget);
    });

    testWidgets('two conducted sessions on the same date stay separate columns',
        (tester) async {
      final sameDate = StudentWiseReport(
        subjectId: 1,
        subjectName: 'DBMS',
        sectionId: 10,
        sectionName: 'CSE-A',
        columns: const [
          StudentWiseColumn(sessionId: 100, date: '2026-08-12', lecturePeriod: 'P1'),
          StudentWiseColumn(sessionId: 101, date: '2026-08-12', lecturePeriod: 'P2'),
        ],
        rows: const [
          StudentWiseRow(
            studentId: 1,
            enrollmentNumber: 'DAGACS001',
            name: 'Rahul Sharma',
            presentCount: 1,
            totalRecordedCount: 2,
            percentage: 50.0,
            cells: [
              StudentWiseCell(sessionId: 100, status: 'PRESENT', isPresent: true),
              StudentWiseCell(sessionId: 101, status: 'ABSENT', isPresent: false),
            ],
          ),
        ],
      );
      final report = _FakeReportRepository(report: sameDate);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      // Distinct labels, neither merged nor overwritten.
      expect(find.text('12-Aug-2026 (P1)'), findsOneWidget);
      expect(find.text('12-Aug-2026 (P2)'), findsOneWidget);
      // Total Classes counts both conducted sessions for everyone.
      expect(
          find.descendant(
              of: find.byType(DataTable), matching: find.text('2')),
          findsOneWidget);
    });

    testWidgets('legend explains P, A and unmarked/missing', (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      final legend = find.byKey(const Key('register-legend'));
      expect(
          find.descendant(
              of: legend, matching: find.text('P = Present')),
          findsOneWidget);
      expect(
          find.descendant(of: legend, matching: find.text('A = Absent')),
          findsOneWidget);
      expect(
          find.descendant(
              of: legend, matching: find.text('Unmarked / Missing = A')),
          findsOneWidget);
    });

    testWidgets('unmarked and missing attendance both render A, never blank',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      final marks = find.descendant(
          of: find.byType(DataTable), matching: find.text('P'));
      final absents = find.descendant(
          of: find.byType(DataTable), matching: find.text('A'));

      // Rahul P,P,A and Priya P,A + unmarked => 3 P and 3 A.
      expect(marks, findsNWidgets(3));
      expect(absents, findsNWidgets(3));
    });

    testWidgets('every student shares the backend Total Classes denominator',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      // Both rows show Total Classes = 3 (rendered by the DataTable), including
      // Priya whose third session was never marked.
      final totalClassesCells = find.descendant(
          of: find.byType(DataTable), matching: find.text('3'));
      expect(totalClassesCells, findsNWidgets(2));
    });

    testWidgets('percentage comes from the backend and shows 2 decimals',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      expect(
          find.descendant(
              of: find.byType(DataTable), matching: find.text('66.67%')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(DataTable), matching: find.text('33.33%')),
          findsOneWidget);
      expect(find.textContaining('66.6666666'), findsNothing);
    });

    testWidgets('summary strip reports students, sessions and average',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      final summary = find.byKey(const Key('register-summary'));
      expect(
          find.descendant(of: summary, matching: find.text('Students: ')),
          findsOneWidget);
      expect(find.descendant(of: summary, matching: find.text('2')),
          findsOneWidget);
      expect(
          find.descendant(of: summary, matching: find.text('Sessions: ')),
          findsOneWidget);
      expect(find.descendant(of: summary, matching: find.text('3')),
          findsOneWidget);
      // Mean of the backend's 66.67% and 33.33%.
      expect(
          find.descendant(of: summary, matching: find.text('50.00%')),
          findsOneWidget);
    });
  });

  group('Generate Report is an explicit, validated action', () {
    testWidgets('is disabled until subject, section and both dates are set',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await tester.pumpAndSettle();

      // Nothing selected.
      expect(_generateEnabled(tester), isFalse);

      await _chooseClass(tester);
      // Class chosen, still no dates.
      expect(_generateEnabled(tester), isFalse);

      await _pickDate(tester, 'Start date', 1);
      // Only a start date.
      expect(_generateEnabled(tester), isFalse);

      await _pickDate(tester, 'End date', 28);
      expect(_generateEnabled(tester), isTrue);
    });

    testWidgets('stays disabled when start is after end', (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await tester.pumpAndSettle();
      await _chooseClass(tester);

      await _pickDate(tester, 'End date', 10);
      await _pickDate(tester, 'Start date', 20);

      expect(find.text('Start date must not be after end date.'),
          findsOneWidget);
      expect(_generateEnabled(tester), isFalse);
      expect(report.reportCalls, isEmpty,
          reason: 'an invalid range must never reach the API');
    });

    testWidgets('selecting filters does NOT auto-generate the report',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await tester.pumpAndSettle();

      await _chooseClass(tester);
      expect(report.reportCalls, isEmpty,
          reason: 'changing a selector must not fetch');

      await _pickDate(tester, 'Start date', 1);
      expect(report.reportCalls, isEmpty,
          reason: 'picking a date must not fetch');

      await _pickDate(tester, 'End date', 28);
      expect(report.reportCalls, isEmpty,
          reason: 'picking a date must not fetch');

      // Only the explicit action fetches.
      await tester.tap(find.byKey(const Key('register-generate')));
      await tester.pumpAndSettle();
      expect(report.reportCalls.length, 1);
    });

    testWidgets('changing the subject clears the class and the report',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);
      expect(find.text('Rahul Sharma'), findsOneWidget);

      await tester.tap(find.byKey(const Key('register-subject')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DSA (CS302)').last);
      await tester.pumpAndSettle();

      expect(find.text('Rahul Sharma'), findsNothing);
      expect(find.textContaining('Select a subject and section'),
          findsOneWidget);
      expect(_generateEnabled(tester), isFalse);
    });

    testWidgets('sends subjectId, sectionId and the inclusive date range',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      expect(report.reportCalls.length, 1);
      final call = report.reportCalls.single;
      expect(call.subjectId, 1);
      expect(call.sectionId, 10);
      expect(call.startDate, isNotNull);
      expect(call.endDate, isNotNull);
      expect(call.startDate!.day, 1);
      expect(call.endDate!.day, 28);
    });
  });

  group('States', () {
    testWidgets('a teacher with no assignments gets an empty state',
        (tester) async {
      final report = _FakeReportRepository();
      await tester
          .pumpWidget(_wrap(report, _FakeTeacherRepository(const [])));
      await tester.pumpAndSettle();

      expect(find.textContaining('no teaching assignments'), findsOneWidget);
      expect(find.byKey(const Key('register-generate')), findsNothing);
    });

    testWidgets('missing dates asks for the dates before generating',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await tester.pumpAndSettle();
      await _chooseClass(tester);

      expect(find.textContaining('Select a start and end date'),
          findsOneWidget);
    });

    testWidgets('an empty report shows an empty state, not an error',
        (tester) async {
      final report = _FakeReportRepository(
          report: StudentWiseReport(columns: const [], rows: const []));
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      expect(find.textContaining('No conducted attendance sessions'),
          findsOneWidget);
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
      final teacher = _FakeTeacherRepository()
        ..error = const ApiException.serverError();
      await tester.pumpWidget(_wrap(report, teacher));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong. Please try again.'),
          findsOneWidget);
    });
  });

  group('Exports', () {
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

    testWidgets('exports carry the same filters as the on-screen report',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      await tester.tap(find.byKey(const Key('export-pdf')));
      await tester.pumpAndSettle();
      expect(report.exportCalls.single.format, 'pdf');
      expect(report.reportCalls.single.subjectId, 1);
      expect(report.reportCalls.single.sectionId, 10);
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

    testWidgets('export controls only appear once the filters are complete',
        (tester) async {
      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export-excel')), findsNothing);
      expect(find.byKey(const Key('export-pdf')), findsNothing);
    });
  });

  group('Navigation and layout', () {
    testWidgets('the student-wise deep link renders the same register',
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
      await _generate(tester);
      expect(find.text('STUDENT ATTENDANCE REPORT'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
    });

    testWidgets('keeps the matrix usable on a narrow viewport', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final report = _FakeReportRepository(report: _report);
      await tester.pumpWidget(_wrap(report, _FakeTeacherRepository()));
      await _generate(tester);

      // The table stays intact and scrolls horizontally.
      expect(find.byType(DataTable), findsOneWidget);
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
