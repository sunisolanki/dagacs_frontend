import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/academic_session.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/models/batch.dart';
import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/section.dart';
import 'package:dagacs_frontend/models/semester.dart';
import 'package:dagacs_frontend/models/subject.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/master_data_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository();
  @override
  Future<void> persistSession(AuthResponse auth) async {}
  @override
  Future<void> logout() async {}
}

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository() : super(ApiClient());

  @override
  Future<List<Department>> getDepartments() async => const [
        Department(id: 1, name: 'Computer Science', code: 'CS'),
        Department(id: 2, name: 'Electronics', code: 'EC'),
      ];

  @override
  Future<List<Program>> getPrograms() async =>
      const [Program(id: 1, name: 'B.Tech CSE', code: 'CS')];

  @override
  Future<List<AcademicSession>> getAcademicSessions() async =>
      const [AcademicSession(id: 1, name: '2026-27 Sem 1', code: 'S1')];

  @override
  Future<List<Semester>> getSemesters() async =>
      const [Semester(id: 1, name: 'Semester 1', code: 'S1')];

  @override
  Future<List<Batch>> getBatches() async =>
      const [Batch(id: 1, name: 'B1', batchCode: 'B1')];

  @override
  Future<List<Section>> getSections() async =>
      const [Section(id: 1, name: 'A', sectionCode: 'A')];

  @override
  Future<List<Subject>> getSubjects() async =>
      const [Subject(id: 1, code: 'CS301', name: 'DBMS')];
}

Future<void> _pumpAdminHub(WidgetTester tester,
    {MasterDataRepository? repository}) async {
  final session = SessionController(_FakeAuthRepository());
  session.establishSession('ADMIN');
  await tester.pumpWidget(MaterialApp(
    home: MasterDataScreen(
      repository: repository ?? _FakeMasterDataRepository(),
      session: session,
    ),
  ));
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
  testWidgets('hub groups the seven entities under category headings',
      (tester) async {
    await _pumpAdminHub(tester);

    expect(find.text('ACADEMIC STRUCTURE'), findsOneWidget);
    expect(find.text('ACADEMIC CALENDAR'), findsOneWidget);
    expect(find.text('STUDENT STRUCTURE'), findsOneWidget);
    expect(find.text('ACADEMIC CATALOG'), findsOneWidget);

    expect(find.byKey(const Key('master-data-departments')), findsOneWidget);
    expect(find.byKey(const Key('master-data-programs')), findsOneWidget);
    expect(find.byKey(const Key('master-data-academic-sessions')),
        findsOneWidget);
    expect(find.byKey(const Key('master-data-semesters')), findsOneWidget);
    expect(find.byKey(const Key('master-data-batches')), findsOneWidget);
    expect(find.byKey(const Key('master-data-sections')), findsOneWidget);
    expect(find.byKey(const Key('master-data-subjects')), findsOneWidget);
  });

  testWidgets('hub cards show a short description and the live record count',
      (tester) async {
    await _pumpAdminHub(tester);

    expect(find.text('Institutional academic departments'), findsOneWidget);
    expect(find.text('Degree programs by department'), findsOneWidget);
    expect(find.text('Sessions grouped by program'), findsOneWidget);
    expect(find.text('Study periods within a session'), findsOneWidget);
    expect(find.text('Student cohorts per academic session'), findsOneWidget);
    expect(find.text('Groups within a batch'), findsOneWidget);
    expect(find.text('Catalogue with credit hours and status'), findsOneWidget);

    expect(find.text('2 records'), findsOneWidget);
    expect(find.text('1 record'), findsWidgets);
  });

  testWidgets('hub keeps a single Master Data title in the app bar',
      (tester) async {
    await _pumpAdminHub(tester);

    expect(find.text('Master Data'), findsOneWidget);
  });

  testWidgets('hub layout stays responsive from 320 to 1440 without overflow',
      (tester) async {
    for (final size in _sizes) {
      await _atSize(tester, size);
      await _pumpAdminHub(tester);

      for (final key in const [
        'master-data-departments',
        'master-data-programs',
        'master-data-academic-sessions',
        'master-data-semesters',
        'master-data-batches',
        'master-data-sections',
        'master-data-subjects',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget);
      }
    }
  });
}