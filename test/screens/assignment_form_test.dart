import 'package:dagacs_frontend/models/academic_session.dart';
import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/section.dart';
import 'package:dagacs_frontend/models/semester.dart';
import 'package:dagacs_frontend/models/subject.dart';
import 'package:dagacs_frontend/models/subject_offering.dart';
import 'package:dagacs_frontend/models/teacher.dart';
import 'package:dagacs_frontend/models/teacher_assignment.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/master_data/assignment_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CapturingRepo extends MasterDataRepository {
  _CapturingRepo() : super(ApiClient());

  TeacherAssignmentRequest? assignmentReq;
  int? assignmentUpdateId;
  int? reenterAfterSubmit;

  Object? failError;

  @override
  Future<List<Teacher>> getTeachers() async => const [
        Teacher(
            id: 3,
            fullName: 'Dr Retired',
            designation: 'Professor',
            status: 'INACTIVE'),
        Teacher(
            id: 1,
            fullName: 'Dr A Sharma',
            designation: 'Professor',
            status: 'ACTIVE'),
        Teacher(
            id: 2,
            fullName: 'Dr B Gupta',
            designation: 'Associate',
            status: 'ACTIVE'),
      ];

  @override
  Future<List<SubjectOffering>> getSubjectOfferings() async => const [
        SubjectOffering(
          id: 5,
          subjectId: 4,
          subject: Subject(id: 4, code: 'CS301', name: 'DBMS'),
          semesterId: 3,
          semester: Semester(
            id: 3,
            name: 'Semester 3',
            code: 'SEM3',
            academicSessionId: 1,
            academicSession: AcademicSession(id: 1, name: '2026-27', code: 'S1'),
          ),
        ),
        SubjectOffering(id: 6, subjectId: 2, semesterId: 4),
      ];

  @override
  Future<List<Section>> getSections() async => const [
        Section(id: 9, name: 'Section A', sectionCode: 'A'),
        Section(id: 10, name: 'Section B', sectionCode: 'B'),
      ];

  @override
  Future<List<AcademicSession>> getAcademicSessions() async => const [
        AcademicSession(
          id: 1,
          name: '2026-27',
          code: 'S1',
          programId: 8,
          program: Program(
            id: 8,
            name: 'B.Tech CSE',
            code: 'CS',
            department: Department(id: 2, name: 'Computer Science', code: 'CS'),
          ),
        ),
      ];

  @override
  Future<List<Program>> getPrograms() async => const [
        Program(
          id: 8,
          name: 'B.Tech CSE',
          code: 'CS',
          department: Department(id: 2, name: 'Computer Science', code: 'CS'),
        ),
      ];

  @override
  Future<TeacherAssignment> createTeacherAssignment(
      TeacherAssignmentRequest request) async {
    if (failError != null) throw failError!;
    assignmentReq = request;
    return const TeacherAssignment(
        id: 99, teacherId: 1, subjectOfferingId: 5, sectionId: 9);
  }

  @override
  Future<TeacherAssignment> updateTeacherAssignment(
      int id, TeacherAssignmentRequest request) async {
    if (failError != null) throw failError!;
    assignmentUpdateId = id;
    assignmentReq = request;
    return const TeacherAssignment(
        id: 99, teacherId: 1, subjectOfferingId: 5, sectionId: 9);
  }
}

Future<void> _open(
  WidgetTester tester,
  MasterDataRepository repo, {
  TeacherAssignment? initial,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showTeacherAssignmentForm(context, repo,
                initial: initial),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  final finder = find.byKey(const Key('submit-teacher-assignment'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('assignment form sends exactly the three identity ids',
      (tester) async {
    final repo = _CapturingRepo();
    await _open(tester, repo);

    expect(find.byKey(const Key('field-teacher')), findsOneWidget);
    expect(find.byKey(const Key('field-subject-offering')), findsOneWidget);
    expect(find.byKey(const Key('field-section')), findsOneWidget);

    expect(find.text('Dr A Sharma — Professor'), findsOneWidget);
    expect(
      find.text('CS301 — DBMS · 2026-27 — B.Tech CSE — Computer Science '
          '— Semester 3'),
      findsOneWidget,
    );

    await _submit(tester);

    expect(repo.assignmentUpdateId, isNull);
    expect(repo.assignmentReq!.toJson(), {
      'teacherId': 1,
      'subjectOfferingId': 5,
      'sectionId': 9,
    });
    expect(repo.assignmentReq!.toJson().keys.toSet(),
        {'teacherId', 'subjectOfferingId', 'sectionId'});
  });

  testWidgets('assignment form edit prefills and issues an update with the '
      'three ids', (tester) async {
    final repo = _CapturingRepo();
    await _open(
      tester,
      repo,
      initial: const TeacherAssignment(
          id: 7, teacherId: 2, subjectOfferingId: 5, sectionId: 9),
    );

    expect(find.text('Edit Teacher Assignment'), findsOneWidget);
    expect(find.text('Dr B Gupta — Associate'), findsOneWidget);

    await _submit(tester);

    expect(repo.assignmentUpdateId, 7);
    expect(repo.assignmentReq!.teacherId, 2);
    expect(repo.assignmentReq!.subjectOfferingId, 5);
    expect(repo.assignmentReq!.sectionId, 9);
    expect(repo.assignmentReq!.toJson().keys.toSet(),
        {'teacherId', 'subjectOfferingId', 'sectionId'});
  });

  testWidgets('assignment form create filters out inactive teachers',
      (tester) async {
    final repo = _CapturingRepo();
    await _open(tester, repo);

    expect(find.byKey(const Key('field-teacher')), findsOneWidget);
    await tester.tap(find.byKey(const Key('field-teacher')));
    await tester.pumpAndSettle();
    expect(find.text('Dr Retired — Professor'), findsNothing);
    expect(find.text('Dr A Sharma — Professor'), findsWidgets);
    expect(find.text('Dr B Gupta — Associate'), findsOneWidget);
  });

  testWidgets(
      'assignment form edit keeps an inactive current teacher selectable',
      (tester) async {
    final repo = _CapturingRepo();
    await _open(
      tester,
      repo,
      initial: const TeacherAssignment(
          id: 7, teacherId: 3, subjectOfferingId: 5, sectionId: 9),
    );

    expect(find.text('Edit Teacher Assignment'), findsOneWidget);
    expect(find.text('Dr Retired — Professor'), findsOneWidget);

    await _submit(tester);

    expect(repo.assignmentUpdateId, 7);
    expect(repo.assignmentReq!.teacherId, 3);
    expect(repo.assignmentReq!.toJson().keys.toSet(),
        {'teacherId', 'subjectOfferingId', 'sectionId'});
  });

  testWidgets('assignment form create defaults to the first active teacher',
      (tester) async {
    final repo = _CapturingRepo();
    await _open(tester, repo);

    expect(find.text('Dr A Sharma — Professor'), findsOneWidget);
    await _submit(tester);

    expect(repo.assignmentReq!.teacherId, 1);
  });

  testWidgets('assignment form edit renders the backend 409 message as the '
      'submit error', (tester) async {
    final repo = _CapturingRepo()
      ..failError = const ApiException(
          409, 'Cannot change assignment teacher while attendance history exists.');
    await _open(
      tester,
      repo,
      initial: const TeacherAssignment(
          id: 7, teacherId: 2, subjectOfferingId: 5, sectionId: 9),
    );

    await _submit(tester);

    expect(find.text(
        'Cannot change assignment teacher while attendance history exists.'),
        findsOneWidget);
  });
}