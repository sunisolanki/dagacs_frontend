import 'package:dagacs_frontend/models/academic_session.dart';
import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/semester.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/master_data/semester_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _cse = Department(id: 1, name: 'Computer Science & Engineering', code: 'CS');
const _electrical = Department(id: 2, name: 'Electrical Engineering', code: 'EE');

class _CapturingRepo extends MasterDataRepository {
  _CapturingRepo({
    List<AcademicSession> sessions = const [],
    List<Program> programs = const [],
  })  : _sessions = sessions,
        _programs = programs,
        super(ApiClient());

  List<AcademicSession> _sessions;
  List<Program> _programs;
  SemesterRequest? semesterReq;

  @override
  Future<List<AcademicSession>> getAcademicSessions() async =>
      List.of(_sessions);

  @override
  Future<List<Program>> getPrograms() async => List.of(_programs);

  @override
  Future<Semester> createSemester(SemesterRequest request) async {
    semesterReq = request;
    return const Semester(id: 99, name: 'X', code: 'X');
  }
}

AcademicSession _session(
  int id,
  String name, {
  int? programId,
  String? programName,
  String? programCode,
}) {
  return AcademicSession(
    id: id,
    name: name,
    code: 'A$id',
    programId: programId,
    program: programId == null || programName == null
        ? null
        : Program(id: programId, name: programName, code: programCode),
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
            onPressed: () => showSemesterForm(context, repo),
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
  final finder = find.byKey(const Key('submit-semester'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dropdown shows the Academic Session, Program and Department names',
      (tester) async {
    final repo = _CapturingRepo(
      sessions: [
        _session(1, '2025-26 Sem 1',
            programId: 10, programName: 'B.Tech CSE', programCode: 'CS'),
      ],
      programs: const [
        Program(id: 10, name: 'B.Tech CSE', code: 'CS', department: _cse),
      ],
    );
    await _open(tester, repo);

    expect(
      find.text(
          '2025-26 Sem 1 — B.Tech CSE — Computer Science & Engineering'),
      findsOneWidget,
    );
  });

  testWidgets('same-year sessions with different programs stay distinguishable',
      (tester) async {
    final repo = _CapturingRepo(
      sessions: [
        _session(1, '2025-26 Sem 1',
            programId: 10, programName: 'B.Tech CSE', programCode: 'CS'),
        _session(2, '2025-26 Sem 1',
            programId: 11, programName: 'B.Tech Electrical', programCode: 'EE'),
      ],
      programs: const [
        Program(id: 10, name: 'B.Tech CSE', code: 'CS', department: _cse),
        Program(id: 11, name: 'B.Tech Electrical', code: 'EE',
            department: _electrical),
      ],
    );
    await _open(tester, repo);

    await tester.tap(find.byKey(const Key('field-academic-session')));
    await tester.pumpAndSettle();

    expect(
      find.text(
          '2025-26 Sem 1 — B.Tech CSE — Computer Science & Engineering'),
      findsWidgets,
    );
    expect(
      find.text(
          '2025-26 Sem 1 — B.Tech Electrical — Electrical Engineering'),
      findsWidgets,
    );
  });

  testWidgets('M.Tech CSE and M.Tech Electrical resolve their own departments',
      (tester) async {
    final repo = _CapturingRepo(
      sessions: [
        _session(3, '2025-26 Sem 1',
            programId: 12, programName: 'M.Tech CSE', programCode: 'MS'),
        _session(4, '2025-26 Sem 1',
            programId: 13, programName: 'M.Tech Electrical', programCode: 'ME'),
      ],
      programs: const [
        Program(id: 12, name: 'M.Tech CSE', code: 'MS', department: _cse),
        Program(
            id: 13,
            name: 'M.Tech Electrical',
            code: 'ME',
            department: _electrical),
      ],
    );
    await _open(tester, repo);

    await tester.tap(find.byKey(const Key('field-academic-session')));
    await tester.pumpAndSettle();

    expect(
      find.text(
          '2025-26 Sem 1 — M.Tech CSE — Computer Science & Engineering'),
      findsWidgets,
    );
    expect(
      find.text(
          '2025-26 Sem 1 — M.Tech Electrical — Electrical Engineering'),
      findsWidgets,
    );
  });

  testWidgets('selecting an option submits its academicSessionId only',
      (tester) async {
    final repo = _CapturingRepo(
      sessions: [
        _session(1, '2025-26 Sem 1',
            programId: 10, programName: 'B.Tech CSE', programCode: 'CS'),
        _session(2, '2025-26 Sem 1',
            programId: 11, programName: 'B.Tech Electrical', programCode: 'EE'),
      ],
      programs: const [
        Program(id: 10, name: 'B.Tech CSE', code: 'CS', department: _cse),
        Program(id: 11, name: 'B.Tech Electrical', code: 'EE',
            department: _electrical),
      ],
    );
    await _open(tester, repo);

    await tester.tap(find.byKey(const Key('field-academic-session')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.text('2025-26 Sem 1 — B.Tech Electrical — Electrical Engineering'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field-name')), 'Sem 2');
    await tester.enterText(find.byKey(const Key('field-code')), 'S2');
    await tester.enterText(find.byKey(const Key('field-year')), '2026');
    await _submit(tester);

    expect(repo.semesterReq, isNotNull);
    expect(repo.semesterReq!.academicSessionId, 2);
    expect(
      repo.semesterReq!.toJson().keys.toSet(),
      {'name', 'code', 'year', 'academicSessionId'},
    );
    expect(repo.semesterReq!.toJson().containsKey('programId'), isFalse);
    expect(repo.semesterReq!.toJson().containsKey('departmentId'), isFalse);
  });

  testWidgets('a missing program degrades to Program unavailable safely',
      (tester) async {
    final repo = _CapturingRepo(
      sessions: [_session(1, '2025-26 Sem 1')],
      programs: const [
        Program(id: 10, name: 'B.Tech CSE', code: 'CS', department: _cse),
      ],
    );
    await _open(tester, repo);

    expect(
      find.text('2025-26 Sem 1 — Program unavailable — Department unavailable'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing department degrades to Department unavailable safely',
      (tester) async {
    final repo = _CapturingRepo(
      sessions: [
        _session(1, '2025-26 Sem 1',
            programId: 10, programName: 'B.Tech CSE', programCode: 'CS'),
      ],
      programs: const [Program(id: 10, name: 'B.Tech CSE', code: 'CS')],
    );
    await _open(tester, repo);

    expect(find.text('2025-26 Sem 1 — B.Tech CSE — Department unavailable'),
        findsOneWidget);
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
        sessions: [
          _session(1, '2025-26 Sem 1',
              programId: 10,
              programName:
                  'Bachelor of Technology in Computer Science and Engineering',
              programCode: 'BT-CSE'),
        ],
        programs: const [
          Program(
            id: 10,
            name:
                'Bachelor of Technology in Computer Science and Engineering',
            code: 'BT-CSE',
            department:
                Department(id: 1, name: 'Department of Computer Science and '
                    'Engineering (Autonomous)', code: 'CSE'),
          ),
        ],
      );
      await _open(tester, repo);

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Bachelor of Technology in Computer Science'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Department of Computer Science'),
        findsOneWidget,
      );
    }
  });
}