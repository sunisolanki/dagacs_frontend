import 'package:dagacs_frontend/models/teacher_assignment.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/master_data/assignment_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository({List<TeacherAssignment> assignments = const []})
      : _assignments = List.of(assignments),
        super(ApiClient());

  List<TeacherAssignment> _assignments;
  final List<int> deletedIds = [];

  @override
  Future<List<TeacherAssignment>> getTeacherAssignments() async =>
      List.of(_assignments);

  @override
  Future<void> deleteTeacherAssignment(int id) async {
    deletedIds.add(id);
    _assignments =
        _assignments.where((a) => a.id != id).toList();
  }
}

const _sample = TeacherAssignment(
  id: 7,
  teacherId: 2,
  teacherName: 'Dr A Sharma',
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

Future<void> _pump(WidgetTester tester, MasterDataRepository repo) async {
  await tester.pumpWidget(
      MaterialApp(home: TeacherAssignmentListScreen(repository: repo)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('assignment list shows derived context in each tile',
      (tester) async {
    final repo = _FakeMasterDataRepository(assignments: const [_sample]);
    await _pump(tester, repo);

    expect(find.byKey(const Key('assignment-list')), findsOneWidget);
    expect(find.byKey(const Key('assignment-tile-7')), findsOneWidget);
    expect(find.text('Dr A Sharma'), findsOneWidget);
    expect(
      find.text('CS301 — DBMS · 2026-27 — B.Tech CSE — Computer Science '
          '· A — Section A · B1'),
      findsOneWidget,
    );
  });

  testWidgets('empty assignment list shows the placeholder and add button',
      (tester) async {
    final repo = _FakeMasterDataRepository();
    await _pump(tester, repo);

    expect(find.byKey(const Key('assignment-empty')), findsOneWidget);
    expect(find.text('No teacher assignments yet. Use + to map one.'),
        findsOneWidget);
    expect(find.byKey(const Key('assignment-add')), findsOneWidget);
  });

  testWidgets('confirmed delete removes the assignment via the repository',
      (tester) async {
    final repo = _FakeMasterDataRepository(assignments: const [_sample]);
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('assignment-delete-7')));
    await tester.pumpAndSettle();

    expect(find.text('Delete Teacher Assignments'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assignment-confirm-delete')));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, [7]);
    expect(find.byKey(const Key('assignment-tile-7')), findsNothing);
    expect(find.byKey(const Key('assignment-empty')), findsOneWidget);
  });

  testWidgets('list layout stays responsive with long context at every width',
      (tester) async {
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

      final repo = _FakeMasterDataRepository(assignments: const [_sample]);
      await _pump(tester, repo);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('assignment-tile-7')), findsOneWidget);
    }
  });
}