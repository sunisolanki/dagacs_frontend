import 'package:dagacs_frontend/models/academic_session.dart';
import 'package:dagacs_frontend/models/batch.dart';
import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/section.dart';
import 'package:dagacs_frontend/models/semester.dart';
import 'package:dagacs_frontend/models/subject.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/master_data/academic_session_form.dart';
import 'package:dagacs_frontend/screens/master_data/batch_form.dart';
import 'package:dagacs_frontend/screens/master_data/department_form.dart';
import 'package:dagacs_frontend/screens/master_data/program_form.dart';
import 'package:dagacs_frontend/screens/master_data/section_form.dart';
import 'package:dagacs_frontend/screens/master_data/semester_form.dart';
import 'package:dagacs_frontend/screens/master_data/subject_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CapturingRepo extends MasterDataRepository {
  _CapturingRepo() : super(ApiClient());

  DepartmentRequest? deptReq;
  ProgramRequest? programReq;
  AcademicSessionRequest? sessionReq;
  SemesterRequest? semesterReq;
  BatchRequest? batchReq;
  SectionRequest? sectionReq;
  SubjectRequest? subjectReq;
  int? subjectUpdateId;

  @override
  Future<List<Department>> getDepartments() async =>
      const [Department(id: 1, name: 'Computer Science', code: 'CS')];

  @override
  Future<List<Program>> getPrograms() async =>
      const [Program(id: 1, name: 'B.Tech CSE', code: 'CS')];

  @override
  Future<List<AcademicSession>> getAcademicSessions() async =>
      const [AcademicSession(id: 1, name: '2026-27 Sem 1', code: 'S1')];

  @override
  Future<List<Batch>> getBatches() async =>
      const [Batch(id: 1, name: 'B1', batchCode: 'B1')];

  @override
  Future<Department> createDepartment(DepartmentRequest request) async {
    deptReq = request;
    return const Department(id: 99, name: 'X', code: 'X');
  }

  @override
  Future<Program> createProgram(ProgramRequest request) async {
    programReq = request;
    return const Program(id: 99, name: 'X', code: 'X');
  }

  @override
  Future<AcademicSession> createAcademicSession(
      AcademicSessionRequest request) async {
    sessionReq = request;
    return const AcademicSession(id: 99, name: 'X', code: 'X');
  }

  @override
  Future<Semester> createSemester(SemesterRequest request) async {
    semesterReq = request;
    return const Semester(id: 99, name: 'X', code: 'X');
  }

  @override
  Future<Batch> createBatch(BatchRequest request) async {
    batchReq = request;
    return const Batch(id: 99, name: 'X', batchCode: 'X');
  }

  @override
  Future<Section> createSection(SectionRequest request) async {
    sectionReq = request;
    return const Section(id: 99, name: 'X', sectionCode: 'X');
  }

  @override
  Future<Subject> createSubject(SubjectRequest request) async {
    subjectReq = request;
    return const Subject(id: 99, code: 'X', name: 'X');
  }

  @override
  Future<Subject> updateSubject(int id, SubjectRequest request) async {
    subjectUpdateId = id;
    subjectReq = request;
    return Subject(id: id, code: 'X', name: 'X');
  }
}

Future<void> _open(
  WidgetTester tester,
  MasterDataRepository repo,
  Future<dynamic> Function(BuildContext context) open,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, String submitKey) async {
  final finder = find.byKey(Key(submitKey));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('department form maps Name/Code/Description to the request',
      (tester) async {
    final repo = _CapturingRepo();
    await _open(tester, repo, (c) => showDepartmentForm(c, repo));

    await tester.enterText(find.byKey(const Key('field-name')), 'CSE Lab');
    await tester.enterText(find.byKey(const Key('field-code')), 'CSE');
    await _submit(tester, 'submit-department');

    expect(repo.deptReq!.name, 'CSE Lab');
    expect(repo.deptReq!.code, 'CSE');
    expect(repo.deptReq!.description, isNull);
  });

  testWidgets('program form maps fields and the chosen departmentId',
      (tester) async {
    final repo = _CapturingRepo();
    await _open(tester, repo, (c) => showProgramForm(c, repo));

    expect(find.byKey(const Key('field-department')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('field-name')), 'B.Tech CE');
    await tester.enterText(find.byKey(const Key('field-code')), 'CE');
    await tester.enterText(find.byKey(const Key('field-duration')), '4 years');
    await _submit(tester, 'submit-program');

    expect(repo.programReq!.name, 'B.Tech CE');
    expect(repo.programReq!.code, 'CE');
    expect(repo.programReq!.duration, '4 years');
    expect(repo.programReq!.departmentId, 1);
  });

  testWidgets('academic session form maps numeric fields and programId',
      (tester) async {
    final repo = _CapturingRepo();
    await _open(tester, repo, (c) => showAcademicSessionForm(c, repo));

    await tester.enterText(
        find.byKey(const Key('field-name')), '2026-27 Sem 1');
    await tester.enterText(find.byKey(const Key('field-code')), 'S1');
    await tester.enterText(find.byKey(const Key('field-semester')), '1');
    await tester.enterText(find.byKey(const Key('field-durationHours')), '16');
    await tester.enterText(
        find.byKey(const Key('field-lecturePeriods')), '4');
    await tester.enterText(find.byKey(const Key('field-credits')), '3');
    await _submit(tester, 'submit-academic-session');

    expect(repo.sessionReq!.name, '2026-27 Sem 1');
    expect(repo.sessionReq!.code, 'S1');
    expect(repo.sessionReq!.semester, '1');
    expect(repo.sessionReq!.durationHours, 16);
    expect(repo.sessionReq!.lecturePeriods, 4);
    expect(repo.sessionReq!.credits, 3);
    expect(repo.sessionReq!.programId, 1);
  });

  testWidgets('academic session form rejects non-numeric values',
      (tester) async {
    final repo = _CapturingRepo();
    await _open(tester, repo, (c) => showAcademicSessionForm(c, repo));

    await tester.enterText(find.byKey(const Key('field-name')), 'S');
    await tester.enterText(find.byKey(const Key('field-code')), 'S');
    await tester.enterText(find.byKey(const Key('field-semester')), '1');
    await tester.enterText(
        find.byKey(const Key('field-durationHours')), 'abc');
    await tester.enterText(find.byKey(const Key('field-lecturePeriods')), '4');
    await tester.enterText(find.byKey(const Key('field-credits')), '3');
    await _submit(tester, 'submit-academic-session');

    expect(find.text('Duration must be a number'), findsOneWidget);
    expect(repo.sessionReq, isNull);
  });

  testWidgets('semester form maps fields, year and academicSessionId',
      (tester) async {
    final repo = _CapturingRepo();
    await _open(tester, repo, (c) => showSemesterForm(c, repo));

    await tester.enterText(find.byKey(const Key('field-name')), 'Sem 2');
    await tester.enterText(find.byKey(const Key('field-code')), 'S2');
    await tester.enterText(find.byKey(const Key('field-year')), '2026');
    await _submit(tester, 'submit-semester');

    expect(repo.semesterReq!.name, 'Sem 2');
    expect(repo.semesterReq!.code, 'S2');
    expect(repo.semesterReq!.year, 2026);
    expect(repo.semesterReq!.academicSessionId, 1);
  });

  testWidgets('batch form maps fields, year and academicSessionId',
      (tester) async {
    final repo = _CapturingRepo();
    await _open(tester, repo, (c) => showBatchForm(c, repo));

    await tester.enterText(find.byKey(const Key('field-batchCode')), 'B2');
    await tester.enterText(find.byKey(const Key('field-name')), 'Batch 2026');
    await tester.enterText(find.byKey(const Key('field-year')), '2026');
    await tester.enterText(find.byKey(const Key('field-maxCapacity')), '60');
    await _submit(tester, 'submit-batch');

    expect(repo.batchReq!.batchCode, 'B2');
    expect(repo.batchReq!.name, 'Batch 2026');
    expect(repo.batchReq!.year, 2026);
    expect(repo.batchReq!.maxCapacity, 60);
    expect(repo.batchReq!.academicSessionId, 1);
  });

  testWidgets('section form maps fields and batchId', (tester) async {
    final repo = _CapturingRepo();
    await _open(tester, repo, (c) => showSectionForm(c, repo));

    await tester.enterText(find.byKey(const Key('field-sectionCode')), 'A');
    await tester.enterText(find.byKey(const Key('field-name')), 'Section A');
    await tester.enterText(find.byKey(const Key('field-maxCapacity')), '60');
    await _submit(tester, 'submit-section');

    expect(repo.sectionReq!.sectionCode, 'A');
    expect(repo.sectionReq!.name, 'Section A');
    expect(repo.sectionReq!.maxCapacity, 60);
    expect(repo.sectionReq!.batchId, 1);
  });

  testWidgets('subject form maps fields with ACTIVE status by default',
      (tester) async {
    final repo = _CapturingRepo();
    await _open(tester, repo, (c) => showSubjectForm(c, repo));

    await tester.enterText(find.byKey(const Key('field-code')), 'CS301');
    await tester.enterText(find.byKey(const Key('field-name')), 'DBMS');
    await tester.enterText(find.byKey(const Key('field-creditHours')), '3');
    await _submit(tester, 'submit-subject');

    expect(repo.subjectReq!.code, 'CS301');
    expect(repo.subjectReq!.name, 'DBMS');
    expect(repo.subjectReq!.creditHours, '3');
    expect(repo.subjectReq!.status, 'ACTIVE');
  });

  testWidgets('subject edit preserves the existing status', (tester) async {
    final repo = _CapturingRepo();
    await _open(
      tester,
      repo,
      (c) => showSubjectForm(
        c,
        repo,
        initial: const Subject(
            id: 1, code: 'CS101', name: 'OOP', creditHours: '3', status: 'INACTIVE'),
      ),
    );

    await tester.enterText(find.byKey(const Key('field-code')), 'CS101A');
    await _submit(tester, 'submit-subject');

    expect(repo.subjectUpdateId, 1);
    expect(repo.subjectReq!.code, 'CS101A');
    expect(repo.subjectReq!.name, 'OOP');
    expect(repo.subjectReq!.status, 'INACTIVE');
  });
}