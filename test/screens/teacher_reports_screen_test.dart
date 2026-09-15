import 'dart:async';
import 'dart:typed_data';

import 'package:dagacs_frontend/core/navigation/navigator.dart';
import 'package:dagacs_frontend/models/report_export.dart';
import 'package:dagacs_frontend/models/teacher_assignment.dart';
import 'package:dagacs_frontend/models/teacher_report_row.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/report_repository.dart';
import 'package:dagacs_frontend/repositories/teacher_repository.dart';
import 'package:dagacs_frontend/screens/teacher_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dagacs_frontend/screens/student_wise_report_screen.dart';

class _FakeReportRepository extends ReportRepository {
  _FakeReportRepository();

  List<TeacherReportRow> rows = const [];
  final List<({DateTime? start, DateTime? end})> reportCalls = [];
  final List<({String format, DateTime? start, DateTime? end})> exportCalls = [];
  Object? error;
  Completer<void>? exportGate;

  @override
  Future<List<TeacherReportRow>> getTeacherReport(
      {DateTime? startDate, DateTime? endDate}) async {
    reportCalls.add((start: startDate, end: endDate));
    if (error != null) throw error!;
    return rows;
  }

  @override
  Future<DownloadPayload> exportTeacherReport(String format,
      {DateTime? startDate, DateTime? endDate}) {
    exportCalls.add((format: format, start: startDate, end: endDate));
    if (exportGate != null) {
      return exportGate!.future.then(
          (_) => DownloadPayload(bytes: Uint8List.fromList([1]), fileName: 'x.xlsx'));
    }
    return Future.value(
        DownloadPayload(bytes: Uint8List.fromList([1]), fileName: 'x.xlsx'));
  }
}

const _rows = [
  TeacherReportRow(
    subjectCode: 'DS',
    subjectName: 'Data Structures',
    sectionCode: 'A',
    sectionName: 'Section A',
    presentCount: 5,
    totalRecordedCount: 8,
    percentage: 62.5,
  )
];

Widget _wrap(_FakeReportRepository repo,
    {required Future<String> Function(Uint8List, String, String?) download}) {
  return MaterialApp(
    home: TeacherReportsScreen(reportRepository: repo, downloadFile: download),
  );
}

Future<void> _selectDay(WidgetTester tester, int day) async {
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
      of: find.byType(CalendarDatePicker), matching: find.text('$day')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loads the teacher own report and renders rows', (tester) async {
    final repo = _FakeReportRepository()..rows = _rows;
    await tester.pumpWidget(_wrap(repo, download: (_, _, _) async => 'ok'));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(repo.reportCalls.length, 1);
    expect(repo.reportCalls.single.start, isNull);
    expect(repo.reportCalls.single.end, isNull);
    expect(find.text('Data Structures (DS)'), findsOneWidget);
    expect(find.text('Section A (A)'), findsOneWidget);
    expect(find.text('62.5%'), findsOneWidget);
  });

  testWidgets('start-date filter is applied on reload', (tester) async {
    final repo = _FakeReportRepository()..rows = _rows;
    await tester.pumpWidget(_wrap(repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();
    expect(repo.reportCalls.length, 1);

    await tester.tap(find.text('Start date'));
    await _selectDay(tester, 15);
    await tester.pumpAndSettle();

    expect(repo.reportCalls.last.start, isNotNull);
    expect(repo.reportCalls.last.end, isNull);
    expect(repo.reportCalls.last.start!.day, 15);
  });

  testWidgets('empty report shows empty state, not error', (tester) async {
    final repo = _FakeReportRepository();
    await tester.pumpWidget(_wrap(repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No attendance report data'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('API failure shows retryable error', (tester) async {
    final repo = _FakeReportRepository()
      ..error = const ApiException.serverError();
    await tester.pumpWidget(_wrap(repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    repo.error = null;
    repo.rows = _rows;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.reportCalls.length, 2);
    expect(find.text('Data Structures (DS)'), findsOneWidget);
  });

  testWidgets('Excel export sends format xlsx and downloads the payload',
      (tester) async {
    final repo = _FakeReportRepository()..rows = _rows;
    final downloaded = <String>[];
    await tester.pumpWidget(_wrap(
      repo,
      download: (bytes, name, type) async {
        downloaded.add(name);
        return 'Downloaded $name';
      },
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-excel')));
    await tester.pumpAndSettle();

    expect(repo.exportCalls.single.format, 'xlsx');
    expect(downloaded.single, isNotEmpty);
    expect(find.textContaining('Downloaded'), findsOneWidget);
  });

  testWidgets('loading state prevents duplicate export requests',
      (tester) async {
    final repo = _FakeReportRepository()
      ..rows = _rows
      ..exportGate = Completer<void>();
    await tester.pumpWidget(_wrap(repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-excel')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('export-pdf')));
    await tester.pump();

    expect(repo.exportCalls.length, 1);
    repo.exportGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.exportCalls.length, 1);
  });

  testWidgets('403 export shows authorization message', (tester) async {
    final repo = _FakeReportRepository();
    repo.rows = _rows;
    final failing = _ThrowingReportRepository();
    await tester.pumpWidget(_wrap(failing, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-pdf')));
    await tester.pumpAndSettle();

    expect(find.text('You are not authorized to perform this action.'),
        findsOneWidget);
  });

  testWidgets('student-wise register action opens the matrix screen when a '
      'teacher repository is provided', (tester) async {
    final repo = _FakeReportRepository()..rows = _rows;
    final teachers = _FakeTeacherRepository();
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.teacherStudentWise) {
          return MaterialPageRoute(
              builder: (_) => StudentWiseReportScreen(
                  reportRepository: repo, teacherRepository: teachers));
        }
        return MaterialPageRoute(
            builder: (_) => const SizedBox.shrink());
      },
      home: TeacherReportsScreen(
          reportRepository: repo, teacherRepository: teachers),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('student-wise-register')), findsOneWidget);
    await tester.tap(find.byKey(const Key('student-wise-register')));
    await tester.pumpAndSettle();

    expect(find.text('Student-Wise Register'), findsOneWidget);
    expect(find.byType(StudentWiseReportScreen), findsOneWidget);
  });

  testWidgets('reports-only surface has no student-wise action when no '
      'teacher repository is provided', (tester) async {
    final repo = _FakeReportRepository()..rows = _rows;
    await tester.pumpWidget(_wrap(repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('student-wise-register')), findsNothing);
  });
}

class _FakeTeacherRepository extends TeacherRepository {
  @override
  Future<List<TeacherAssignment>> getMyAssignments() async => const [];
}

class _ThrowingReportRepository extends _FakeReportRepository {
  @override
  Future<DownloadPayload> exportTeacherReport(String format,
      {DateTime? startDate, DateTime? endDate}) {
    return Future.error(const ApiException.forbidden());
  }
}