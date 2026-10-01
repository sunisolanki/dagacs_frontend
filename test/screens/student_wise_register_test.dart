import 'dart:typed_data';

import 'package:dagacs_frontend/models/report_export.dart';
import 'package:dagacs_frontend/models/student_wise_report.dart';
import 'package:dagacs_frontend/models/teacher_assignment.dart';
import 'package:dagacs_frontend/repositories/report_repository.dart';
import 'package:dagacs_frontend/repositories/teacher_repository.dart';
import 'package:dagacs_frontend/screens/student_wise_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTeacherRepository extends TeacherRepository {
  List<TeacherAssignment> assignments = const [];

  @override
  Future<List<TeacherAssignment>> getMyAssignments() async => assignments;
}

class _FakeReportRepository extends ReportRepository {
  StudentWiseReport? report;
  final List<({int? subjectId, int? sectionId})> matrixCalls = [];
  final List<({String format, int? subjectId, int? sectionId})> exportCalls = [];

  @override
  Future<StudentWiseReport> getStudentWiseReport({
    required int subjectId,
    int? sectionId,
    int? batchId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    matrixCalls.add((subjectId: subjectId, sectionId: sectionId));
    return report ?? const StudentWiseReport(columns: [], rows: []);
  }

  @override
  Future<DownloadPayload> exportStudentWiseReport(String format,
      {required int subjectId,
      int? sectionId,
      int? batchId,
      DateTime? startDate,
      DateTime? endDate}) async {
    exportCalls.add(
        (format: format, subjectId: subjectId, sectionId: sectionId));
    return DownloadPayload(
        bytes: Uint8List.fromList(const [1]), fileName: 'register.xlsx');
  }
}

const _dsAssignment = TeacherAssignment(
  id: 1,
  subjectId: 100,
  subjectCode: 'DS',
  subjectName: 'Data Structures',
  sectionId: 200,
  sectionCode: 'A',
  sectionName: 'CSE-A',
);

const _dbmsAssignment = TeacherAssignment(
  id: 2,
  subjectId: 101,
  subjectCode: 'DBMS',
  subjectName: 'Database Systems',
  sectionId: 201,
  sectionCode: 'B',
  sectionName: 'CSE-B',
);

/// 2 of 3 conducted classes = 66.666...% which must render as 66.67%.
const _report = StudentWiseReport(
  subjectId: 100,
  subjectName: 'Data Structures',
  sectionId: 200,
  sectionName: 'CSE-A',
  columns: [
    StudentWiseColumn(sessionId: 1, date: '2026-01-10', lecturePeriod: 'LP1'),
    StudentWiseColumn(sessionId: 2, date: '2026-01-12', lecturePeriod: 'LP1'),
    StudentWiseColumn(sessionId: 3, date: '2026-01-14', lecturePeriod: 'LP1'),
  ],
  rows: [
    StudentWiseRow(
      studentId: 10,
      enrollmentNumber: 'ENG-0001',
      name: 'Alice',
      presentCount: 2,
      totalRecordedCount: 3,
      percentage: 66.66666666666667,
      cells: [
        StudentWiseCell(sessionId: 1, status: 'PRESENT', isPresent: true),
        StudentWiseCell(sessionId: 2, status: 'ABSENT', isPresent: false),
        StudentWiseCell(sessionId: 3, status: 'PRESENT', isPresent: true),
      ],
    ),
  ],
);

Widget _wrap(_FakeReportRepository reports, _FakeTeacherRepository teachers,
    {Future<String> Function(Uint8List, String, String?)? download}) {
  return MaterialApp(
    home: StudentWiseReportScreen(
      reportRepository: reports,
      teacherRepository: teachers,
      downloadFile: download ?? (_, _, _) async => 'ok',
    ),
  );
}

Future<void> _pump(WidgetTester tester, _FakeReportRepository reports,
    _FakeTeacherRepository teachers) async {
  await tester.pumpWidget(_wrap(reports, teachers));
  await tester.pumpAndSettle();
}

Future<void> _choose(String subjectLabel, String sectionLabel) async {
  final tester = _currentTester!;
  await tester.tap(find.byKey(const Key('register-subject')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(subjectLabel).last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('register-section')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(sectionLabel).last);
  await tester.pumpAndSettle();
}

/// Chooses the class, picks both required dates, then presses Generate.
Future<void> _chooseAndGenerate(String subjectLabel, String sectionLabel) async {
  final tester = _currentTester!;
  await _choose(subjectLabel, sectionLabel);
  await _pickDate(tester, 'Start date', 1);
  await _pickDate(tester, 'End date', 28);
  await tester.tap(find.byKey(const Key('register-generate')));
  await tester.pumpAndSettle();
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

late WidgetTester? _currentTester;

void main() {
  setUp(() => _currentTester = null);

  group('Student-wise register filters', () {
    testWidgets('subject and section are separate selectors', (tester) async {
      _currentTester = tester;
      final reports = _FakeReportRepository()..report = _report;
      final teachers = _FakeTeacherRepository()
        ..assignments = const [_dsAssignment, _dbmsAssignment];
      await _pump(tester, reports, teachers);

      expect(find.byKey(const Key('register-subject')), findsOneWidget);
      expect(find.byKey(const Key('register-section')), findsOneWidget);
      // Both authorized subjects are offered.
      await tester.tap(find.byKey(const Key('register-subject')));
      await tester.pumpAndSettle();
      expect(find.text('Data Structures (DS)'), findsWidgets);
      expect(find.text('Database Systems (DBMS)'), findsWidgets);
    });

    testWidgets('Generate stays disabled until class and both dates are chosen',
        (tester) async {
      _currentTester = tester;
      final reports = _FakeReportRepository()..report = _report;
      final teachers = _FakeTeacherRepository()
        ..assignments = const [_dsAssignment, _dbmsAssignment];
      await _pump(tester, reports, teachers);

      bool enabled() => tester
          .widget<ElevatedButton>(find.descendant(
              of: find.byKey(const Key('register-generate')),
              matching: find.byType(ElevatedButton)))
          .onPressed !=
          null;

      // Nothing fetched just by having assignments.
      expect(reports.matrixCalls, isEmpty);
      expect(find.textContaining('Select a subject and section'),
          findsOneWidget);
      expect(enabled(), isFalse, reason: 'no subject or section yet');

      await _choose('Data Structures (DS)', 'CSE-A (A)');
      // Class chosen, but the dates are still missing.
      expect(reports.matrixCalls, isEmpty);
      expect(find.textContaining('Select a start and end date'),
          findsOneWidget);
      expect(enabled(), isFalse, reason: 'both dates are required');

      await _pickDate(tester, 'Start date', 1);
      expect(enabled(), isFalse, reason: 'only a start date');
      expect(reports.matrixCalls, isEmpty);

      await _pickDate(tester, 'End date', 28);
      expect(enabled(), isTrue);

      await tester.tap(find.byKey(const Key('register-generate')));
      await tester.pumpAndSettle();
      expect(reports.matrixCalls, isNotEmpty);
    });

    testWidgets('changing subject clears the class and previous report',
        (tester) async {
      _currentTester = tester;
      final reports = _FakeReportRepository()..report = _report;
      final teachers = _FakeTeacherRepository()
        ..assignments = const [_dsAssignment, _dbmsAssignment];
      await _pump(tester, reports, teachers);

      await _chooseAndGenerate('Data Structures (DS)', 'CSE-A (A)');
      expect(find.text('ENG-0001'), findsOneWidget);

      // Switching subject must invalidate the class selection.
      await tester.tap(find.byKey(const Key('register-subject')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Database Systems (DBMS)').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Select a subject and section'),
          findsOneWidget);
      expect(find.text('ENG-0001'), findsNothing);
    });

    testWidgets('generate passes the chosen subjectId and sectionId',
        (tester) async {
      _currentTester = tester;
      final reports = _FakeReportRepository()..report = _report;
      final teachers = _FakeTeacherRepository()
        ..assignments = const [_dsAssignment, _dbmsAssignment];
      await _pump(tester, reports, teachers);

      await _chooseAndGenerate('Data Structures (DS)', 'CSE-A (A)');

      expect(reports.matrixCalls.single.subjectId, 100);
      expect(reports.matrixCalls.single.sectionId, 200);
    });
  });

  group('Student-wise register presentation', () {
    testWidgets('percentages render to exactly two decimals', (tester) async {
      _currentTester = tester;
      final reports = _FakeReportRepository()..report = _report;
      final teachers = _FakeTeacherRepository()
        ..assignments = const [_dsAssignment];
      await _pump(tester, reports, teachers);

      await _chooseAndGenerate('Data Structures (DS)', 'CSE-A (A)');

      expect(
          find.descendant(
              of: find.byType(DataTable), matching: find.text('66.67%')),
          findsOneWidget);
      // Raw float precision must never reach the UI.
      expect(find.textContaining('66.6666666'), findsNothing);
    });

    testWidgets('the register shows one column per conducted session date',
        (tester) async {
      _currentTester = tester;
      final reports = _FakeReportRepository()..report = _report;
      final teachers = _FakeTeacherRepository()
        ..assignments = const [_dsAssignment];
      await _pump(tester, reports, teachers);

      await _chooseAndGenerate('Data Structures (DS)', 'CSE-A (A)');

      // One clearly labelled column per CONDUCTED session date.
      expect(find.text('10-Jan-2026 (LP1)'), findsOneWidget);
      expect(find.text('12-Jan-2026 (LP1)'), findsOneWidget);
      expect(find.text('14-Jan-2026 (LP1)'), findsOneWidget);
      // Identity + totals columns, and never a roll number.
      expect(find.text('Enrollment No.'), findsOneWidget);
      expect(find.text('Student Name'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Total Classes'), findsOneWidget);
      expect(find.text('Percentage'), findsOneWidget);
    });

    testWidgets('exports use the selected class', (tester) async {
      _currentTester = tester;
      final reports = _FakeReportRepository()..report = _report;
      final teachers = _FakeTeacherRepository()
        ..assignments = const [_dsAssignment];
      final downloaded = <String>[];
      await tester.pumpWidget(_wrap(
        reports,
        teachers,
        download: (bytes, name, type) async {
          downloaded.add(name);
          return 'Downloaded $name';
        },
      ));
      await tester.pumpAndSettle();

      await _chooseAndGenerate('Data Structures (DS)', 'CSE-A (A)');

      await tester.tap(find.byKey(const Key('export-excel')));
      await tester.pumpAndSettle();
      expect(reports.exportCalls.single.format, 'xlsx');
      expect(reports.exportCalls.single.subjectId, 100);
      expect(reports.exportCalls.single.sectionId, 200);

      await tester.tap(find.byKey(const Key('export-pdf')));
      await tester.pumpAndSettle();
      expect(reports.exportCalls.last.format, 'pdf');
      expect(downloaded.length, 2);
    });

    testWidgets('no conducted sessions shows an empty state, not an error',
        (tester) async {
      _currentTester = tester;
      final reports = _FakeReportRepository()
        ..report = const StudentWiseReport(columns: [], rows: []);
      final teachers = _FakeTeacherRepository()
        ..assignments = const [_dsAssignment];
      await _pump(tester, reports, teachers);

      await _chooseAndGenerate('Data Structures (DS)', 'CSE-A (A)');

      expect(find.textContaining('No conducted attendance sessions'),
          findsOneWidget);
      expect(find.byKey(const Key('report-retry')), findsNothing);
    });

    testWidgets('no overflow at 320 / 800 / 1280 px', (tester) async {
      // Height is kept generous so the Material date picker (used to set the
      // required start/end dates) is operable at every width; the widths are
      // what this test is about.
      for (final size in [
        const Size(320, 900),
        const Size(800, 800),
        const Size(1280, 800),
      ]) {
        // Dispose the previous tree so the view's State (dates, selections) is
        // recreated; otherwise the next iteration inherits the chosen dates and
        // the "Start date" affordance is no longer rendered.
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        _currentTester = tester;

        final reports = _FakeReportRepository()..report = _report;
        final teachers = _FakeTeacherRepository()
          ..assignments = const [_dsAssignment];
        await _pump(tester, reports, teachers);

        await _chooseAndGenerate('Data Structures (DS)', 'CSE-A (A)');

        // The register actually rendered.
        expect(find.byType(DataTable), findsOneWidget,
            reason: 'no matrix at ${size.width}px');

        expect(tester.takeException(), isNull,
            reason: 'overflow at ${size.width}px');
      }
    });
  });
}
