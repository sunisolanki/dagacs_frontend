import 'package:dagacs_frontend/models/academic_session.dart';
import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/semester.dart';
import 'package:dagacs_frontend/models/subject.dart';
import 'package:dagacs_frontend/models/subject_offering.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/master_data/subject_offering_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository({
    List<SubjectOffering> offerings = const [],
    List<AcademicSession> sessions = const [],
    List<Program> programs = const [],
    this.failSessions = false,
  })  : _offerings = offerings,
        _sessions = sessions,
        _programs = programs,
        super(ApiClient());

  List<SubjectOffering> _offerings;
  List<AcademicSession> _sessions;
  List<Program> _programs;
  bool failSessions;

  @override
  Future<List<SubjectOffering>> getSubjectOfferings() async =>
      List.of(_offerings);

  @override
  Future<List<AcademicSession>> getAcademicSessions() async {
    if (failSessions) throw const ApiException.serverError();
    return List.of(_sessions);
  }

  @override
  Future<List<Program>> getPrograms() async => List.of(_programs);
}

void main() {
  testWidgets('offering list shows code — context — semester name',
      (tester) async {
    final repo = _FakeMasterDataRepository(
      offerings: [
        const SubjectOffering(
          id: 1,
          subjectId: 1,
          subject: Subject(id: 1, code: 'CS301', name: 'DBMS'),
          semesterId: 5,
          semester: Semester(
            id: 5,
            name: 'Semester 5',
            code: 'SEM5',
            academicSessionId: 9,
            academicSession: AcademicSession(id: 9, name: '2025-26', code: 'A1'),
          ),
        ),
      ],
      sessions: const [
        AcademicSession(
          id: 9,
          name: '2025-26',
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
          department:
              Department(id: 1, name: 'Computer Science & Engineering', code: 'CS'),
        ),
      ],
    );

    await tester.pumpWidget(
        MaterialApp(home: SubjectOfferingListScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subject-offering-tile-1')), findsOneWidget);
    expect(
      find.text('CS301 · 2025-26 — B.Tech CSE — Computer Science & Engineering '
          '· Semester 5'),
      findsOneWidget,
    );
  });

  testWidgets('list degrades to unavailable markers when reference fetch fails',
      (tester) async {
    final repo = _FakeMasterDataRepository(
      offerings: [
        const SubjectOffering(
          id: 1,
          subjectId: 1,
          subject: Subject(id: 1, code: 'CS301', name: 'DBMS'),
          semesterId: 5,
          semester: Semester(
            id: 5,
            name: 'Semester 5',
            code: 'SEM5',
            academicSessionId: 9,
            academicSession: AcademicSession(id: 9, name: '2025-26', code: 'A1'),
          ),
        ),
      ],
      failSessions: true,
    );

    await tester.pumpWidget(
        MaterialApp(home: SubjectOfferingListScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subject-offering-tile-1')), findsOneWidget);
    expect(
      find.text('CS301 · 2025-26 — Program unavailable — Department unavailable '
          '· Semester 5'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty offering list shows the placeholder',
      (tester) async {
    final repo = _FakeMasterDataRepository();

    await tester.pumpWidget(
        MaterialApp(home: SubjectOfferingListScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subject-offering-empty')), findsOneWidget);
    expect(
        find.text('No subject offerings yet. Use + to map one.'), findsOneWidget);
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
      await tester.pumpWidget(const SizedBox());

      final repo = _FakeMasterDataRepository(
        offerings: [
          const SubjectOffering(
            id: 1,
            subjectId: 1,
            subject: Subject(id: 1, code: 'CS301A', name: 'DBMS'),
            semesterId: 5,
            semester: Semester(
              id: 5,
              name: 'Semester 5',
              code: 'SEM5',
              academicSessionId: 9,
              academicSession: AcademicSession(
                id: 9,
                name: '2025-26',
                code: 'A1',
                programId: 10,
                program: Program(
                  id: 10,
                  name:
                      'Bachelor of Technology in Computer Science and Engineering',
                  code: 'BT-CSE',
                ),
              ),
            ),
          ),
        ],
        sessions: const [
          AcademicSession(
            id: 9,
            name: '2025-26',
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
          MaterialApp(home: SubjectOfferingListScreen(repository: repo)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('subject-offering-tile-1')), findsOneWidget);
      expect(
        find.textContaining('Bachelor of Technology in Computer Science'),
        findsOneWidget,
      );
    }
  });
}