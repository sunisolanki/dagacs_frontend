import 'dart:async';

import 'package:dagacs_frontend/core/navigation/navigator.dart';
import 'package:dagacs_frontend/models/teacher_assignment.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/teacher_repository.dart';
import 'package:dagacs_frontend/screens/teacher_classes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sample = TeacherAssignment(
  id: 7,
  teacherId: 2,
  teacherEmail: 'a@college.edu',
  subjectOfferingId: 5,
  subjectId: 4,
  subjectCode: 'CS301',
  subjectName: 'DBMS',
  semesterId: 3,
  semesterName: 'Semester 3',
  sessionId: 1,
  sessionName: '2026-27',
  programId: 8,
  programName: 'B.Tech CSE',
  departmentId: 2,
  departmentName: 'Computer Science',
  sectionId: 9,
  sectionCode: 'A',
  sectionName: 'Section A',
  batchId: 6,
  batchCode: 'B1',
);

const _sample2 = TeacherAssignment(
  id: 8,
  teacherId: 2,
  teacherEmail: 'a@college.edu',
  subjectOfferingId: 6,
  subjectId: 5,
  subjectCode: 'CS302',
  subjectName: 'Operating Systems and Administration',
  semesterId: 4,
  semesterName: 'Semester 4',
  sessionId: 1,
  sessionName: '2026-27',
  programId: 8,
  programName: 'B.Tech CSE',
  departmentId: 2,
  departmentName: 'Computer Science',
  sectionId: 10,
  sectionCode: 'B',
  sectionName: 'Section B',
  batchId: 6,
  batchCode: 'B1',
);

const _long = TeacherAssignment(
  id: 99,
  teacherId: 2,
  subjectId: 4,
  subjectCode: 'CS301',
  subjectName:
      'Very Long Database Management Systems And Advanced Data Modelling Course Title',
  semesterName:
      'Semester 3 - Third Semester of the Four Year Undergraduate Programme',
  sessionName: '2026-27 Academic Session',
  programName:
      'Bachelor of Technology in Computer Science and Engineering (Honours)',
  departmentName:
      'Department of Computer Science and Systems Engineering Directorate',
  sectionName: 'Section A One',
  batchCode: 'Batch 2025 Twenty Twenty Five Intake',
);

class _FakeTeacherRepository extends TeacherRepository {
  _FakeTeacherRepository({
    List<TeacherAssignment> assignments = const [],
  }) : _assignments = List.of(assignments);

  List<TeacherAssignment> _assignments;
  bool failReads = false;
  int calls = 0;
  Completer<List<TeacherAssignment>>? gate;

  @override
  Future<List<TeacherAssignment>> getMyAssignments() {
    calls++;
    if (gate != null) return gate!.future;
    if (failReads) {
      return Future.error(const ApiException.serverError());
    }
    return Future.value(List.of(_assignments));
  }
}

Future<void> _pump(WidgetTester tester, _FakeTeacherRepository repo) async {
  await tester.pumpWidget(MaterialApp(home: TeacherClassesScreen(teacherRepository: repo)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the loading state before assignments resolve',
      (tester) async {
    final repo = _FakeTeacherRepository(assignments: const [_sample])
      ..gate = Completer<List<TeacherAssignment>>();
    await tester.pumpWidget(MaterialApp(home: TeacherClassesScreen(teacherRepository: repo)));
    await tester.pump();

    expect(find.text('Loading your classes...'), findsOneWidget);
    repo.gate!.complete(const [_sample]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-class-tile-7')), findsOneWidget);
  });

  testWidgets('shows the error state and retry re-fetches assignments',
      (tester) async {
    final repo = _FakeTeacherRepository()..failReads = true;
    await _pump(tester, repo);

    expect(find.text(kServerErrorMessage), findsOneWidget);

    repo.failReads = false;
    repo._assignments = const [_sample];
    final before = repo.calls;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repo.calls, before + 1);
    expect(find.byKey(const Key('my-class-tile-7')), findsOneWidget);
  });

  testWidgets('empty assignments show the administrator notice',
      (tester) async {
    final repo = _FakeTeacherRepository();
    await _pump(tester, repo);

    expect(find.byKey(const Key('my-classes-empty')), findsOneWidget);
    expect(find.text('No classes assigned yet. Contact your administrator.'),
        findsOneWidget);
  });

  testWidgets('renders one card per assignment with real academic context',
      (tester) async {
    final repo = _FakeTeacherRepository(assignments: const [_sample, _sample2]);
    await _pump(tester, repo);

    expect(find.byKey(const Key('my-classes-list')), findsOneWidget);
    expect(find.byKey(const Key('my-class-tile-7')), findsOneWidget);
    expect(find.byKey(const Key('my-class-tile-8')), findsOneWidget);

    expect(find.text('SUBJECT'), findsNWidgets(2));
    expect(find.text('CS301 — DBMS'), findsOneWidget);
    expect(find.text('CS302 — Operating Systems and Administration'),
        findsOneWidget);
    expect(find.text('SEMESTER'), findsNWidgets(2));
    expect(find.text('Semester 3'), findsOneWidget);
    expect(find.text('Semester 4'), findsOneWidget);
    expect(find.text('ACADEMIC CONTEXT'), findsNWidgets(2));
    expect(find.text('2026-27 — B.Tech CSE — Computer Science'),
        findsNWidgets(2));
    expect(find.text('SECTION'), findsNWidgets(2));
    expect(find.text('Section A'), findsOneWidget);
    expect(find.text('Section B'), findsOneWidget);
    expect(find.text('BATCH'), findsNWidgets(2));
    expect(find.text('B1'), findsNWidgets(2));
    expect(find.text('Take Attendance'), findsNWidgets(2));
  });

  testWidgets('Take Attendance passes the selected assignment to the route',
      (tester) async {
    final repo = _FakeTeacherRepository(assignments: const [_sample]);
    final pushedArguments = <Object?>[];
    await tester.pumpWidget(MaterialApp(
      home: TeacherClassesScreen(teacherRepository: repo),
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.createSession) {
          pushedArguments.add(settings.arguments);
          return MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('create-session')));
        }
        return MaterialPageRoute(builder: (_) => const SizedBox());
      },
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('my-class-take-attendance-7')));
    await tester.pumpAndSettle();

    expect(pushedArguments, hasLength(1));
    expect(pushedArguments.single, isA<TeacherAssignment>());
    expect((pushedArguments.single as TeacherAssignment).subjectId, 4);
    expect((pushedArguments.single as TeacherAssignment).sectionId, 9);
  });

  testWidgets('stays responsive with long names at every width',
      (tester) async {
    final repo = _FakeTeacherRepository(assignments: const [_long]);
    for (final size in const [
      Size(320, 720),
      Size(390, 844),
      Size(480, 800),
      Size(768, 1024),
      Size(1280, 800),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pump();
      await _pump(tester, repo);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('my-class-tile-99')), findsOneWidget);
      expect(find.text('Take Attendance'), findsOneWidget);
    }
  });

  testWidgets('null context fields are omitted gracefully', (tester) async {
    const sparse = TeacherAssignment(
      id: 11,
      teacherId: 2,
      subjectId: 4,
      sectionId: 9,
      subjectName: 'DBMS',
      sectionName: 'Section A',
    );
    final repo = _FakeTeacherRepository(assignments: [sparse]);
    await _pump(tester, repo);

    expect(find.byKey(const Key('my-class-tile-11')), findsOneWidget);
    expect(find.text('DBMS'), findsOneWidget);
    expect(find.text('Semester'), findsNothing);
    expect(find.text('Semester 3'), findsNothing);
    expect(find.text('Academic context'), findsNothing);
    expect(find.text('Section A'), findsOneWidget);
    expect(find.text('Take Attendance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}