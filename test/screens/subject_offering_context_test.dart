import 'package:dagacs_frontend/models/academic_session.dart';
import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/semester.dart';
import 'package:dagacs_frontend/models/subject.dart';
import 'package:dagacs_frontend/models/subject_offering.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/master_data/subject_offering_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _cse = Department(
    id: 1, name: 'Computer Science & Engineering', code: 'CS');
const _electrical =
    Department(id: 2, name: 'Electrical Engineering', code: 'EE');

class _CapturingRepo extends MasterDataRepository {
  _CapturingRepo({
    List<Semester> semesters = const [],
    List<Subject> subjects = const [],
    List<AcademicSession> sessions = const [],
    List<Program> programs = const [],
    this.createError,
  })  : _semesters = semesters,
        _subjects = subjects,
        _sessions = sessions,
        _programs = programs,
        super(ApiClient());

  List<Semester> _semesters;
  List<Subject> _subjects;
  List<AcademicSession> _sessions;
  List<Program> _programs;
  ApiException? createError;
  SubjectOfferingRequest? offeringReq;

  @override
  Future<List<Semester>> getSemesters() async => List.of(_semesters);

  @override
  Future<List<Subject>> getSubjects() async => List.of(_subjects);

  @override
  Future<List<AcademicSession>> getAcademicSessions() async =>
      List.of(_sessions);

  @override
  Future<List<Program>> getPrograms() async => List.of(_programs);

  @override
  Future<SubjectOffering> createSubjectOffering(
      SubjectOfferingRequest request) async {
    offeringReq = request;
    if (createError != null) throw createError!;
    return SubjectOffering(
        id: 99, subjectId: request.subjectId, semesterId: request.semesterId);
  }
}

Semester _semester(
  int id,
  String name, {
  required int sessionId,
  String sessionName = '2025-26',
  int? programId,
  String? programName,
  String? programCode,
}) {
  return Semester(
    id: id,
    name: name,
    code: 'SEM$id',
    academicSessionId: sessionId,
    academicSession: AcademicSession(
      id: sessionId,
      name: sessionName,
      code: 'A$sessionId',
      programId: programId,
      program: programId == null || programName == null
          ? null
          : Program(id: programId, name: programName, code: programCode),
    ),
  );
}

Future<void> _open(
  WidgetTester tester,
  MasterDataRepository repo,
) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showSubjectOfferingForm(context, repo),
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
  final finder = find.byKey(const Key('submit-subject-offering'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  final csePrograms = const [
    Program(id: 10, name: 'B.Tech CSE', code: 'CS', department: _cse),
    Program(id: 11, name: 'B.Tech Electrical', code: 'EE',
        department: _electrical),
  ];

  testWidgets('subject dropdown labels each option as code — name',
      (tester) async {
    final repo = _CapturingRepo(
      subjects: const [
        Subject(id: 1, code: 'CS301', name: 'DBMS'),
        Subject(id: 2, code: 'CS401', name: 'Networks'),
      ],
    );
    await _open(tester, repo);

    expect(find.text('CS301 — DBMS'), findsOneWidget);
  });

  testWidgets('semester dropdown shows session, program, department and semester',
      (tester) async {
    final repo = _CapturingRepo(
      semesters: [
        _semester(5, 'Semester 5',
            sessionId: 1,
            programId: 10,
            programName: 'B.Tech CSE',
            programCode: 'CS'),
      ],
      subjects: const [Subject(id: 1, code: 'CS301', name: 'DBMS')],
      sessions: [
        AcademicSession(
            id: 1,
            name: '2025-26',
            code: 'A1',
            programId: 10,
            program: const Program(id: 10, name: 'B.Tech CSE', code: 'CS')),
      ],
      programs: csePrograms,
    );
    await _open(tester, repo);

    expect(
      find.text('2025-26 — B.Tech CSE — Computer Science & Engineering — '
          'Semester 5'),
      findsOneWidget,
    );
  });

  testWidgets('same-named semesters in different programs stay distinguishable',
      (tester) async {
    final repo = _CapturingRepo(
      semesters: [
        _semester(5, 'Semester 5',
            sessionId: 1,
            programId: 10,
            programName: 'B.Tech CSE',
            programCode: 'CS'),
        _semester(6, 'Semester 5',
            sessionId: 2,
            programId: 11,
            programName: 'B.Tech Electrical',
            programCode: 'EE'),
      ],
      subjects: const [Subject(id: 1, code: 'CS301', name: 'DBMS')],
      sessions: [
        AcademicSession(
            id: 1,
            name: '2025-26',
            code: 'A1',
            programId: 10,
            program: const Program(id: 10, name: 'B.Tech CSE', code: 'CS')),
        AcademicSession(
            id: 2,
            name: '2025-26',
            code: 'A2',
            programId: 11,
            program:
                const Program(id: 11, name: 'B.Tech Electrical', code: 'EE')),
      ],
      programs: csePrograms,
    );
    await _open(tester, repo);

    await tester.tap(find.byKey(const Key('field-semester')));
    await tester.pumpAndSettle();

    expect(
      find.text('2025-26 — B.Tech CSE — Computer Science & Engineering — '
          'Semester 5'),
      findsWidgets,
    );
    expect(
      find.text('2025-26 — B.Tech Electrical — Electrical Engineering — '
          'Semester 5'),
      findsWidgets,
    );
  });

  testWidgets(
      'submitting sends ONLY subjectId and semesterId, never context ids',
      (tester) async {
    final repo = _CapturingRepo(
      semesters: [
        _semester(5, 'Semester 5',
            sessionId: 1,
            programId: 10,
            programName: 'B.Tech CSE',
            programCode: 'CS'),
        _semester(6, 'Semester 5',
            sessionId: 2,
            programId: 11,
            programName: 'B.Tech Electrical',
            programCode: 'EE'),
      ],
      subjects: const [
        Subject(id: 1, code: 'CS301', name: 'DBMS'),
        Subject(id: 2, code: 'CS401', name: 'Networks'),
      ],
      sessions: [
        AcademicSession(
            id: 1,
            name: '2025-26',
            code: 'A1',
            programId: 10,
            program: const Program(id: 10, name: 'B.Tech CSE', code: 'CS')),
        AcademicSession(
            id: 2,
            name: '2025-26',
            code: 'A2',
            programId: 11,
            program:
                const Program(id: 11, name: 'B.Tech Electrical', code: 'EE')),
      ],
      programs: csePrograms,
    );
    await _open(tester, repo);

    await tester.tap(find.byKey(const Key('field-subject')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CS401 — Networks'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('field-semester')));
    await tester.pumpAndSettle();
    await tester.tap(
        find.text('2025-26 — B.Tech Electrical — Electrical Engineering — '
            'Semester 5'));
    await tester.pumpAndSettle();

    await _submit(tester);

    expect(repo.offeringReq, isNotNull);
    expect(repo.offeringReq!.subjectId, 2);
    expect(repo.offeringReq!.semesterId, 6);
    expect(
      repo.offeringReq!.toJson().keys.toSet(),
      {'subjectId', 'semesterId'},
    );
    for (final forbidden in const [
      'programId',
      'academicSessionId',
      'departmentId',
      'teacherId',
      'sectionId',
      'batchId',
      'studentId',
      'status',
    ]) {
      expect(repo.offeringReq!.toJson().containsKey(forbidden), isFalse,
          reason: 'request must never carry $forbidden');
    }
  });

  testWidgets('a 409 duplicate mapping stays visible as the submit error',
      (tester) async {
    final repo = _CapturingRepo(
      semesters: [
        _semester(5, 'Semester 5', sessionId: 1),
      ],
      subjects: const [Subject(id: 1, code: 'CS301', name: 'DBMS')],
      sessions: [AcademicSession(id: 1, name: '2025-26', code: 'A1')],
      programs: csePrograms,
      createError:
          const ApiException(409, 'Subject is already mapped to this semester'),
    );
    await _open(tester, repo);

    await _submit(tester);

    expect(find.text('Subject is already mapped to this semester'),
        findsOneWidget);
    expect(find.byKey(const Key('field-subject')), findsOneWidget);
  });

  testWidgets('a missing program degrades to Program unavailable safely',
      (tester) async {
    final repo = _CapturingRepo(
      semesters: [
        _semester(5, 'Semester 5', sessionId: 1),
      ],
      subjects: const [Subject(id: 1, code: 'CS301', name: 'DBMS')],
      sessions: [AcademicSession(id: 1, name: '2025-26', code: 'A1')],
      programs: csePrograms,
    );
    await _open(tester, repo);

    expect(
      find.text('2025-26 — Program unavailable — Department unavailable — '
          'Semester 5'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('long contextual labels wrap at narrow widths without overflow',
      (tester) async {
    for (final size in const [
      Size(320, 720),
      Size(390, 844),
      Size(480, 800),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pump();

      final repo = _CapturingRepo(
        semesters: [
          _semester(
            5,
            'Semester 5',
            sessionId: 1,
            programId: 10,
            programName:
                'Bachelor of Technology in Computer Science and Engineering',
            programCode: 'BT-CSE',
          ),
        ],
        subjects: const [
          Subject(
              id: 1,
              code: 'CS301A',
              name: 'Database Management Systems with a Long Name'),
        ],
        sessions: [
          AcademicSession(
            id: 1,
            name: '2025-26',
            code: 'A1',
            programId: 10,
            program: const Program(
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
      await _open(tester, repo);

      expect(tester.takeException(), isNull);
      expect(
        find.text('CS301A — Database Management Systems with a Long Name'),
        findsOneWidget,
      );
    }
  });
}