import 'dart:async';

import 'package:dagacs_frontend/models/batch.dart';
import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/subject.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/master_data/academic_session_form.dart';
import 'package:dagacs_frontend/screens/master_data/department_form.dart';
import 'package:dagacs_frontend/screens/master_data/program_form.dart';
import 'package:dagacs_frontend/screens/master_data/section_form.dart';
import 'package:dagacs_frontend/screens/master_data/subject_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository() : super(ApiClient());

  List<Department> departments = const [
    Department(id: 1, name: 'Computer Science', code: 'CS'),
  ];
  Completer<List<Department>>? departmentGate;
  int failDepartmentFetches = 0;
  ApiException? createError;
  DepartmentRequest? deptReq;
  ProgramRequest? programReq;
  SubjectRequest? subjectReq;

  @override
  Future<List<Department>> getDepartments() async {
    if (departmentGate != null) return departmentGate!.future;
    if (failDepartmentFetches > 0) {
      failDepartmentFetches--;
      throw const ApiException.badRequest(
          'Could not load Department reference data.');
    }
    return List.of(departments);
  }

  @override
  Future<List<Program>> getPrograms() async =>
      const [Program(id: 1, name: 'B.Tech CSE', code: 'CS')];

  @override
  Future<List<Batch>> getBatches() async =>
      const [Batch(id: 1, name: 'B1', batchCode: 'B1')];

  @override
  Future<Department> createDepartment(DepartmentRequest request) async {
    deptReq = request;
    if (createError != null) throw createError!;
    return Department(id: 99, name: request.name, code: request.code);
  }

  @override
  Future<Program> createProgram(ProgramRequest request) async {
    programReq = request;
    return const Program(id: 99, name: 'X', code: 'X');
  }

  @override
  Future<Subject> createSubject(SubjectRequest request) async {
    subjectReq = request;
    return const Subject(id: 99, code: 'X', name: 'X');
  }
}

Future<void> _open(
  WidgetTester tester,
  MasterDataRepository repo,
  Future<dynamic> Function(BuildContext context) open,
) async {
  await tester.pumpWidget(const SizedBox());
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

const _sizes = <Size>[
  Size(320, 720),
  Size(390, 844),
  Size(480, 800),
  Size(768, 1024),
  Size(1024, 768),
  Size(1280, 800),
  Size(1440, 900),
];

Future<void> _atSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pump();
}

void main() {
  testWidgets('program form shows a loading message while departments load',
      (tester) async {
    final repo = _FakeMasterDataRepository()
      ..departmentGate = Completer<List<Department>>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showProgramForm(context, repo),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Loading Department reference data...'), findsOneWidget);

    repo.departmentGate!.complete(const [
      Department(id: 1, name: 'Computer Science', code: 'CS'),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('field-department')), findsOneWidget);
  });

  testWidgets('program form shows a reference error whose Retry recovers',
      (tester) async {
    final repo = _FakeMasterDataRepository()
      ..failDepartmentFetches = 1;
    await _open(tester, repo, (c) => showProgramForm(c, repo));

    expect(
        find.text('Could not load Department reference data.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('field-department')), findsOneWidget);
  });

  testWidgets('program form requires a department selection', (tester) async {
    final repo = _FakeMasterDataRepository()..departments = const [];
    await _open(tester, repo, (c) => showProgramForm(c, repo));

    await tester.enterText(find.byKey(const Key('field-name')), 'B.Tech CE');
    await tester.enterText(find.byKey(const Key('field-code')), 'CE');
    await tester.enterText(find.byKey(const Key('field-duration')), '4 years');
    await _submit(tester, 'submit-program');

    expect(find.text('Department is required'), findsOneWidget);
    expect(repo.programReq, isNull);
  });

  testWidgets('academic session form exposes only the four supported fields',
      (tester) async {
    final repo = _FakeMasterDataRepository();
    await _open(tester, repo, (c) => showAcademicSessionForm(c, repo));

    expect(find.byKey(const Key('field-name')), findsOneWidget);
    expect(find.byKey(const Key('field-code')), findsOneWidget);
    expect(find.byKey(const Key('field-program')), findsOneWidget);
    expect(find.byKey(const Key('field-description')), findsOneWidget);
    expect(find.byKey(const Key('field-semester')), findsNothing);
    expect(find.byKey(const Key('field-credits')), findsNothing);
  });

  testWidgets('section form has no subject field', (tester) async {
    final repo = _FakeMasterDataRepository();
    await _open(tester, repo, (c) => showSectionForm(c, repo));

    expect(find.byKey(const Key('field-subject')), findsNothing);
    expect(find.byKey(const Key('field-sectionCode')), findsOneWidget);
    expect(find.byKey(const Key('field-batch')), findsOneWidget);
  });

  testWidgets('subject form accepts decimal credit hours', (tester) async {
    final repo = _FakeMasterDataRepository();
    await _open(tester, repo, (c) => showSubjectForm(c, repo));

    await tester.enterText(find.byKey(const Key('field-code')), 'CS301');
    await tester.enterText(find.byKey(const Key('field-name')), 'DBMS');
    await tester.enterText(find.byKey(const Key('field-creditHours')), '3.5');
    await _submit(tester, 'submit-subject');

    expect(repo.subjectReq!.creditHours, '3.5');
    expect(repo.subjectReq!.departmentId, 1);
  });

  testWidgets('subject form rejects zero credit hours', (tester) async {
    final repo = _FakeMasterDataRepository();
    await _open(tester, repo, (c) => showSubjectForm(c, repo));

    await tester.enterText(find.byKey(const Key('field-code')), 'CS301');
    await tester.enterText(find.byKey(const Key('field-name')), 'DBMS');
    await tester.enterText(find.byKey(const Key('field-creditHours')), '0');
    await _submit(tester, 'submit-subject');

    expect(find.text('Credit hours must be a positive number'), findsOneWidget);
    expect(repo.subjectReq, isNull);
  });

  testWidgets('a backend submit error stays visible in the form',
      (tester) async {
    final repo = _FakeMasterDataRepository()
      ..createError = const ApiException.badRequest(
          'A department with this code already exists.');
    await _open(tester, repo, (c) => showDepartmentForm(c, repo));

    await tester.enterText(find.byKey(const Key('field-name')), 'Mechanical');
    await tester.enterText(find.byKey(const Key('field-code')), 'ME');
    await _submit(tester, 'submit-department');

    expect(find.text('A department with this code already exists.'),
        findsOneWidget);
    expect(find.byKey(const Key('field-name')), findsOneWidget);
  });

  testWidgets('forms stay responsive from 320 to 1440 without overflow',
      (tester) async {
    for (final size in _sizes) {
      await _atSize(tester, size);
      final repo = _FakeMasterDataRepository();
      await _open(tester, repo, (c) => showProgramForm(c, repo));
      expect(find.byKey(const Key('field-department')), findsOneWidget);
      expect(find.byKey(const Key('submit-program')), findsOneWidget);

      await _open(tester, _FakeMasterDataRepository(), (c) => showSubjectForm(c, repo));
      expect(find.byKey(const Key('field-creditHours')), findsOneWidget);
      expect(find.byKey(const Key('submit-subject')), findsOneWidget);
    }
  });
}