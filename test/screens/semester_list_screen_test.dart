import 'package:dagacs_frontend/models/academic_session.dart';
import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/semester.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/master_data/semester_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository({
    List<Semester> semesters = const [],
    List<AcademicSession> sessions = const [],
    List<Program> programs = const [],
    this.failSessions = false,
  })  : _semesters = semesters,
        _sessions = sessions,
        _programs = programs,
        super(ApiClient());

  List<Semester> _semesters;
  List<AcademicSession> _sessions;
  List<Program> _programs;
  bool failSessions;

  @override
  Future<List<Semester>> getSemesters() async => List.of(_semesters);

  @override
  Future<List<AcademicSession>> getAcademicSessions() async {
    if (failSessions) throw const ApiException.serverError();
    return List.of(_sessions);
  }

  @override
  Future<List<Program>> getPrograms() async => List.of(_programs);
}

void main() {
  testWidgets('semester list shows session — program — department context',
      (tester) async {
    final repo = _FakeMasterDataRepository(
      semesters: const [
        Semester(
          id: 1,
          name: 'Semester 1',
          code: 'S1',
          year: 2026,
          academicSession: AcademicSession(id: 9, name: '2025-26 Sem 1', code: 'A1'),
        ),
      ],
      sessions: const [
        AcademicSession(
          id: 9,
          name: '2025-26 Sem 1',
          code: 'A1',
          programId: 10,
          program: Program(id: 10, name: 'B.Tech CSE', code: 'CS'),
        ),
      ],
      programs: const [
        Program(
          id: 10,
          name: 'B.Tech CSE',
          code: 'CS',
          department: Department(id: 1, name: 'Computer Science & Engineering', code: 'CS'),
        ),
      ],
    );

    await tester.pumpWidget(
        MaterialApp(home: SemesterListScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('semester-tile-1')), findsOneWidget);
    expect(
      find.text('S1 · 2026 · 2025-26 Sem 1 — B.Tech CSE — '
          'Computer Science & Engineering'),
      findsOneWidget,
    );
  });

  testWidgets('list degrades to unavailable markers when reference fetch fails',
      (tester) async {
    final repo = _FakeMasterDataRepository(
      semesters: const [
        Semester(
          id: 1,
          name: 'Semester 1',
          code: 'S1',
          year: 2026,
          academicSession: AcademicSession(id: 9, name: '2025-26 Sem 1', code: 'A1'),
        ),
      ],
      failSessions: true,
    );

    await tester.pumpWidget(
        MaterialApp(home: SemesterListScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('semester-tile-1')), findsOneWidget);
    expect(
      find.text('S1 · 2026 · 2025-26 Sem 1 — Program unavailable — '
          'Department unavailable'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('list shows Department unavailable when department data is absent',
      (tester) async {
    final repo = _FakeMasterDataRepository(
      semesters: const [
        Semester(
          id: 1,
          name: 'Semester 1',
          code: 'S1',
          year: 2026,
          academicSession: AcademicSession(id: 9, name: '2025-26 Sem 1', code: 'A1'),
        ),
      ],
      sessions: const [
        AcademicSession(
          id: 9,
          name: '2025-26 Sem 1',
          code: 'A1',
          programId: 10,
          program: Program(id: 10, name: 'B.Tech CSE', code: 'CS'),
        ),
      ],
      programs: const [Program(id: 10, name: 'B.Tech CSE', code: 'CS')],
    );

    await tester.pumpWidget(
        MaterialApp(home: SemesterListScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(
      find.text('S1 · 2026 · 2025-26 Sem 1 — B.Tech CSE — Department unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('list layout stays responsive with long context at every width',
      (tester) async {
    for (final size in const [
      Size(320, 720),
      Size(390, 844),
      Size(480, 800),
      Size(768, 1024),
      Size(1024, 768),
      Size(1280, 800),
      Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());

      final repo = _FakeMasterDataRepository(
        semesters: const [
          Semester(
            id: 1,
            name: 'Semester 1',
            code: 'S1',
            year: 2026,
            academicSession: AcademicSession(id: 9, name: '2025-26 Sem 1', code: 'A1'),
          ),
        ],
        sessions: const [
          AcademicSession(
            id: 9,
            name: '2025-26 Sem 1',
            code: 'A1',
            programId: 10,
            program: Program(
              id: 10,
              name:
                  'Bachelor of Technology in Computer Science and Engineering',
              code: 'BT-CSE',
            ),
          ),
        ],
        programs: const [
          Program(
            id: 10,
            name:
                'Bachelor of Technology in Computer Science and Engineering',
            code: 'BT-CSE',
            department: Department(
              id: 1,
              name: 'Department of Computer Science and Engineering (Autonomous)',
              code: 'CSE',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
          MaterialApp(home: SemesterListScreen(repository: repo)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('semester-tile-1')), findsOneWidget);
      expect(
        find.textContaining('Bachelor of Technology in Computer Science'),
        findsOneWidget,
      );
    }
  });
}