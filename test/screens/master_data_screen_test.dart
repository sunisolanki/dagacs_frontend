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
import 'package:dagacs_frontend/screens/master_data/department_list_screen.dart';
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

  bool failReads = false;
  bool getDepartmentsCalled = false;

  void _maybeFail() {
    if (failReads) throw Exception('read failed');
  }

  @override
  Future<List<Department>> getDepartments() async {
    getDepartmentsCalled = true;
    _maybeFail();
    return const [
      Department(id: 1, name: 'Computer Science', code: 'CS'),
      Department(id: 2, name: 'Electronics', code: 'EC'),
    ];
  }

  @override
  Future<List<Program>> getPrograms() async {
    _maybeFail();
    return const [Program(id: 1, name: 'B.Tech CSE', code: 'CS')];
  }

  @override
  Future<List<AcademicSession>> getAcademicSessions() async {
    _maybeFail();
    return const [AcademicSession(id: 1, name: '2026-27 Sem 1', code: 'S1')];
  }

  @override
  Future<List<Semester>> getSemesters() async {
    _maybeFail();
    return const [Semester(id: 1, name: 'Semester 1', code: 'S1')];
  }

  @override
  Future<List<Batch>> getBatches() async {
    _maybeFail();
    return const [Batch(id: 1, name: 'B1', batchCode: 'B1')];
  }

  @override
  Future<List<Section>> getSections() async {
    _maybeFail();
    return const [Section(id: 1, name: 'A', sectionCode: 'A')];
  }

  @override
  Future<List<Subject>> getSubjects() async {
    _maybeFail();
    return const [Subject(id: 1, code: 'CS301', name: 'DBMS')];
  }
}

class _MasterDataScreenWrapper extends StatelessWidget {
  const _MasterDataScreenWrapper(
      {required this.session, required this.repository});

  final SessionController session;
  final MasterDataRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MasterDataScreen(repository: repository, session: session),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/master-data/departments':
            return MaterialPageRoute(
                settings: settings,
                builder: (_) => DepartmentListScreen(repository: repository));
          default:
            return MaterialPageRoute(
                settings: settings, builder: (_) => const SizedBox());
        }
      },
    );
  }
}

void main() {
  testWidgets('ADMIN hub shows all seven entity cards with live counts',
      (tester) async {
    final session = SessionController(_FakeAuthRepository());
    session.establishSession('ADMIN');
    await tester.pumpWidget(_MasterDataScreenWrapper(
        session: session, repository: _FakeMasterDataRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('master-data-departments')), findsOneWidget);
    expect(find.byKey(const Key('master-data-programs')), findsOneWidget);
    expect(find.byKey(const Key('master-data-academic-sessions')), findsOneWidget);
    expect(find.byKey(const Key('master-data-semesters')), findsOneWidget);
    expect(find.byKey(const Key('master-data-batches')), findsOneWidget);
    expect(find.byKey(const Key('master-data-sections')), findsOneWidget);
    expect(find.byKey(const Key('master-data-subjects')), findsOneWidget);

    expect(find.text('2 records'), findsOneWidget);
    expect(find.text('1 record'), findsWidgets);
  });

  testWidgets('ADMIN can navigate from a hub card into the CRUD list',
      (tester) async {
    final session = SessionController(_FakeAuthRepository());
    session.establishSession('ADMIN');
    await tester.pumpWidget(_MasterDataScreenWrapper(
        session: session, repository: _FakeMasterDataRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('master-data-departments')));
    await tester.pumpAndSettle();

    expect(find.text('Departments'), findsOneWidget);
    expect(find.byKey(const Key('department-tile-1')), findsOneWidget);
    expect(find.byKey(const Key('department-tile-2')), findsOneWidget);
  });

  testWidgets('non-ADMIN role sees the ADMIN-only notice and nothing is read',
      (tester) async {
    final session = SessionController(_FakeAuthRepository());
    session.establishSession('TEACHER');
    final repo = _FakeMasterDataRepository()
      ..failReads = true;
    await tester.pumpWidget(
        _MasterDataScreenWrapper(session: session, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Master data management is ADMIN-only.'), findsOneWidget);
    expect(find.byKey(const Key('master-data-departments')), findsNothing);
    expect(repo.getDepartmentsCalled, isFalse);
  });

  testWidgets('hub shows an error state with retry when reads fail',
      (tester) async {
    final session = SessionController(_FakeAuthRepository());
    session.establishSession('ADMIN');
    final repo = _FakeMasterDataRepository()
      ..failReads = true;
    await tester.pumpWidget(
        _MasterDataScreenWrapper(session: session, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong while loading master data.'),
        findsOneWidget);

    repo.failReads = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('master-data-departments')), findsOneWidget);
  });
}