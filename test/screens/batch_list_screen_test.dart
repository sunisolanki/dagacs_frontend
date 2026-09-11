import 'package:dagacs_frontend/models/academic_session.dart';
import 'package:dagacs_frontend/models/batch.dart';
import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/section.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/master_data/batch_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository({
    List<Batch> batches = const [],
    List<AcademicSession> sessions = const [],
    List<Program> programs = const [],
    this.failSessions = false,
  })  : _batches = batches,
        _sessions = sessions,
        _programs = programs,
        super(ApiClient());

  List<Batch> _batches;
  List<AcademicSession> _sessions;
  List<Program> _programs;
  bool failSessions;

  @override
  Future<List<Batch>> getBatches() async => List.of(_batches);

  @override
  Future<List<AcademicSession>> getAcademicSessions() async {
    if (failSessions) throw const ApiException.serverError();
    return List.of(_sessions);
  }

  @override
  Future<List<Program>> getPrograms() async => List.of(_programs);
}

void main() {
  testWidgets('batch list shows program — session context, admission year and sections',
      (tester) async {
    final repo = _FakeMasterDataRepository(
      batches: const [
        Batch(
          id: 1,
          name: 'Batch 2025',
          batchCode: 'BT25CS',
          year: 2025,
          academicSession: AcademicSession(id: 9, name: '2025-26', code: 'A1'),
          sections: [
            Section(id: 1, name: 'A', sectionCode: 'A'),
            Section(id: 2, name: 'B', sectionCode: 'B'),
            Section(id: 3, name: 'C', sectionCode: 'C'),
          ],
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
          department: Department(id: 1, name: 'Computer Science & Engineering', code: 'CS'),
        ),
      ],
    );

    await tester.pumpWidget(
        MaterialApp(home: BatchListScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('batch-tile-1')), findsOneWidget);
    expect(
      find.text('BT25CS · Admission 2025 · 2025-26 — B.Tech CSE — '
          'Computer Science & Engineering · Sections: A, B, C'),
      findsOneWidget,
    );
  });

  testWidgets('list degrades to unavailable markers when reference fetch fails',
      (tester) async {
    final repo = _FakeMasterDataRepository(
      batches: const [
        Batch(
          id: 1,
          name: 'Batch 2025',
          batchCode: 'BT25CS',
          year: 2025,
          academicSession: AcademicSession(id: 9, name: '2025-26', code: 'A1'),
        ),
      ],
      failSessions: true,
    );

    await tester.pumpWidget(
        MaterialApp(home: BatchListScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('batch-tile-1')), findsOneWidget);
    expect(
      find.text('BT25CS · Admission 2025 · 2025-26 — Program unavailable — '
          'Department unavailable'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('list shows Department unavailable when department data is absent',
      (tester) async {
    final repo = _FakeMasterDataRepository(
      batches: const [
        Batch(
          id: 1,
          name: 'Batch 2025',
          batchCode: 'BT25CS',
          year: 2025,
          academicSession: AcademicSession(id: 9, name: '2025-26', code: 'A1'),
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
      programs: const [Program(id: 10, name: 'B.Tech CSE', code: 'CS')],
    );

    await tester.pumpWidget(
        MaterialApp(home: BatchListScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(
      find.text('BT25CS · Admission 2025 · 2025-26 — B.Tech CSE — '
          'Department unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('list omits empty section group instead of faking one',
      (tester) async {
    final repo = _FakeMasterDataRepository(
      batches: const [
        Batch(
          id: 1,
          name: 'Batch 2025',
          batchCode: 'BT25CS',
          year: 2025,
          academicSession: AcademicSession(id: 9, name: '2025-26', code: 'A1'),
        ),
      ],
    );

    await tester.pumpWidget(
        MaterialApp(home: BatchListScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('batch-tile-1')), findsOneWidget);
    expect(find.textContaining('Sections:'), findsNothing);
    expect(tester.takeException(), isNull);
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
        batches: const [
          Batch(
            id: 1,
            name: 'Batch 2025',
            batchCode: 'BT25CS',
            year: 2025,
            academicSession: AcademicSession(id: 9, name: '2025-26', code: 'A1'),
            sections: [
              Section(id: 1, name: 'A', sectionCode: 'A'),
              Section(id: 2, name: 'B', sectionCode: 'B'),
            ],
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
          MaterialApp(home: BatchListScreen(repository: repo)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('batch-tile-1')), findsOneWidget);
      expect(
        find.textContaining('Bachelor of Technology in Computer Science'),
        findsOneWidget,
      );
    }
  });
}