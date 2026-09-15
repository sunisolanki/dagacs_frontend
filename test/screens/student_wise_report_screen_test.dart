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
  List<TeacherAssignment> assignments = [];

  @override
  Future<List<TeacherAssignment>> getMyAssignments() async => assignments;
}

class _FakeReportRepository extends ReportRepository {
  StudentWiseReport? report;
  final List<({int? subjectId, int? sectionId, int? batchId})> matrixCalls = [];
  final List<({String format, int? subjectId, int? sectionId, int? batchId})>
      exportCalls = [];

  @override
  Future<StudentWiseReport> getStudentWiseReport({
    required int subjectId,
    int? sectionId,
    int? batchId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    matrixCalls.add((subjectId: subjectId, sectionId: sectionId, batchId: batchId));
    return report ?? const StudentWiseReport(columns: [], rows: []);
  }

  @override
  Future<DownloadPayload> exportStudentWiseReport(String format,
      {required int subjectId,
      int? sectionId,
      int? batchId,
      DateTime? startDate,
      DateTime? endDate}) async {
    exportCalls.add((format: format, subjectId: subjectId, sectionId: sectionId,
        batchId: batchId));
    return DownloadPayload(
        bytes: Uint8List.fromList(const [1]), fileName: 'm.xlsx');
  }
}

const _assignment = TeacherAssignment(
  id: 1,
  subjectId: 100,
  subjectCode: 'DS',
  subjectName: 'Data Structures',
  sectionId: 200,
  sectionCode: 'A',
  sectionName: 'CSE-A',
);

const _report = StudentWiseReport(
  subjectId: 100,
  subjectName: 'Data Structures',
  sectionId: 200,
  sectionName: 'CSE-A',
  columns: [
    StudentWiseColumn(sessionId: 1, date: '2026-01-10', lecturePeriod: 'LP1'),
    StudentWiseColumn(sessionId: 2, date: '2026-01-10', lecturePeriod: 'LP2'),
  ],
  rows: [
    StudentWiseRow(
      studentId: 10,
      rollNumber: 'CS-A-001',
      enrollmentNumber: 'ENG-0001',
      name: 'Alice',
      presentCount: 1,
      totalRecordedCount: 2,
      percentage: 50.0,
      cells: [
        StudentWiseCell(sessionId: 1, status: 'PRESENT', isPresent: true),
        StudentWiseCell(sessionId: 2, status: 'ABSENT', isPresent: false),
      ],
    ),
  ],
);

Widget _wrap(_FakeReportRepository reports, _FakeTeacherRepository teachers,
    {required Future<String> Function(Uint8List, String, String?) download}) {
  return MaterialApp(
    home: StudentWiseReportScreen(
      reportRepository: reports,
      teacherRepository: teachers,
      downloadFile: download,
    ),
  );
}

void main() {
  testWidgets('loads assignments, selects a class and renders the matrix',
      (tester) async {
    final reports = _FakeReportRepository()..report = _report;
    final teachers = _FakeTeacherRepository()..assignments = const [_assignment];
    await tester.pumpWidget(_wrap(reports, teachers,
        download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    expect(find.text('Student-Wise Register'), findsOneWidget);
    expect(reports.matrixCalls, isEmpty);

    await tester.tap(find.byKey(const Key('student-wise-assignment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data Structures (DS) - CSE-A').last);
    await tester.pumpAndSettle();

    expect(reports.matrixCalls.single.subjectId, 100);
    expect(reports.matrixCalls.single.sectionId, 200);
    expect(reports.matrixCalls.single.batchId, isNull);

    expect(find.text('ENG-0001'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.textContaining('LP1'), findsOneWidget);
    expect(find.textContaining('LP2'), findsOneWidget);
  });

  testWidgets('export buttons pass subjectId+sectionId to the repository',
      (tester) async {
    final reports = _FakeReportRepository()..report = _report;
    final teachers = _FakeTeacherRepository()..assignments = const [_assignment];
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

    await tester.tap(find.byKey(const Key('student-wise-assignment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data Structures (DS) - CSE-A').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-excel')));
    await tester.pumpAndSettle();

    expect(reports.exportCalls.single.format, 'xlsx');
    expect(reports.exportCalls.single.subjectId, 100);
    expect(reports.exportCalls.single.sectionId, 200);
    expect(downloaded.single, isNotEmpty);
    expect(find.textContaining('Downloaded'), findsOneWidget);
  });

  testWidgets('no assignments shows an empty hint without a retry error',
      (tester) async {
    final reports = _FakeReportRepository();
    final teachers = _FakeTeacherRepository();
    await tester.pumpWidget(_wrap(reports, teachers,
        download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no teaching assignments'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}