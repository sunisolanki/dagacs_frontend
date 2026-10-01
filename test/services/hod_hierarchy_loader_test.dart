import 'package:dagacs_frontend/core/context/hod_academic_context.dart';
import 'package:dagacs_frontend/models/hod_hierarchy.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/hod_hierarchy_repository.dart';
import 'package:dagacs_frontend/services/hod_hierarchy_loader.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHierarchyRepository extends HodHierarchyRepository {
  _FakeHierarchyRepository({this.root, this.error});

  final HodHierarchyRoot? root;
  final ApiException? error;

  int rootCalls = 0;
  final List<Map<String, int?>> sectionRequests = [];
  final List<Map<String, int?>> subjectRequests = [];

  @override
  Future<HodHierarchyRoot> getRoot() {
    rootCalls++;
    if (error != null) throw error!;
    return Future.value(root ?? _root());
  }

  @override
  Future<List<HodHierarchyOption>> getSemesters({required int academicSessionId}) {
    if (error != null) throw error!;
    return Future.value(const [
      HodHierarchyOption(id: 100, name: 'Semester 3'),
      HodHierarchyOption(id: 101, name: 'Semester 5'),
    ]);
  }

  @override
  Future<List<HodHierarchyOption>> getSections({
    required int academicSessionId,
    int? programId,
    int? semesterId,
  }) {
    sectionRequests
        .add({'session': academicSessionId, 'program': programId, 'semester': semesterId});
    if (error != null) throw error!;
    return Future.value(const [
      HodHierarchyOption(id: 200, name: 'A', studentCount: 30),
      HodHierarchyOption(id: 201, name: 'B', studentCount: 28),
    ]);
  }

  @override
  Future<List<HodHierarchySubject>> getSubjects({
    required int semesterId,
    int? sectionId,
  }) {
    subjectRequests.add({'semester': semesterId, 'section': sectionId});
    if (error != null) throw error!;
    return Future.value(const [
      HodHierarchySubject(
        id: 300,
        code: 'CODSA',
        name: 'DSA',
        semesterId: 100,
        semesterName: 'Semester 3',
        programId: 10,
        programName: 'B.Tech CSE',
        facultyNames: ['Prof Alice'],
      ),
    ]);
  }
}

HodHierarchyRoot _root() => const HodHierarchyRoot(
      departmentId: 1,
      departmentName: 'CSE',
      programs: [
        HodHierarchyOption(id: 10, name: 'B.Tech CSE'),
        HodHierarchyOption(id: 11, name: 'M.Tech CSE'),
      ],
      academicSessions: [
        HodHierarchyOption(
            id: 1,
            name: '2026-27',
            programId: 10,
            programName: 'B.Tech CSE'),
        HodHierarchyOption(
            id: 2,
            name: '2025-26',
            programId: 11,
            programName: 'M.Tech CSE'),
      ],
    );

void main() {
  group('root load', () {
    test('publishes programs and sessions and enables the context', () async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository();
      final loader =
          HodHierarchyLoader(repository: repository, context: context);

      await loader.ensureRoot();

      expect(loader.rootStatus, HodHierarchyStatus.ready);
      expect(context.hierarchyAvailable, isTrue);
      expect(context.optionsFor(HodContextLevel.academicSession), hasLength(2));
      expect(context.optionsFor(HodContextLevel.program), hasLength(2));
      expect(context.optionsFor(HodContextLevel.semester), isEmpty);
    });

    test('is fetched only once, so re-entering a screen does not refetch',
        () async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository();
      final loader =
          HodHierarchyLoader(repository: repository, context: context);

      await loader.ensureRoot();
      await loader.ensureRoot();
      await loader.ensureRoot();

      expect(repository.rootCalls, 1);
    });

    test('an explicit force reload does refetch', () async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository();
      final loader =
          HodHierarchyLoader(repository: repository, context: context);

      await loader.ensureRoot();
      await loader.ensureRoot(force: true);

      expect(repository.rootCalls, 2);
    });

    test('an empty root is reported as empty, not as an error', () async {
      final context = HodAcademicContext();
      final loader = HodHierarchyLoader(
        repository: _FakeHierarchyRepository(
            root: const HodHierarchyRoot(departmentId: 1)),
        context: context,
      );

      await loader.ensureRoot();

      expect(loader.rootStatus, HodHierarchyStatus.empty);
    });

    test('a server failure never masquerades as empty data', () async {
      final context = HodAcademicContext();
      final loader = HodHierarchyLoader(
        repository: _FakeHierarchyRepository(error: const ApiException.serverError()),
        context: context,
      );

      await loader.ensureRoot();

      expect(loader.rootStatus, HodHierarchyStatus.error);
      expect(loader.rootError, hodHierarchyErrorMessage);
      expect(loader.rootStatus, isNot(HodHierarchyStatus.empty));
    });

    test('a network failure is an error, not unauthorized', () async {
      final context = HodAcademicContext();
      final loader = HodHierarchyLoader(
        repository:
            _FakeHierarchyRepository(error: const ApiException.network()),
        context: context,
      );

      await loader.ensureRoot();

      expect(loader.rootStatus, HodHierarchyStatus.error);
    });

    test('401 and 403 are reported as unauthorized', () async {
      for (final status in const [401, 403]) {
        final context = HodAcademicContext();
        final loader = HodHierarchyLoader(
          repository: _FakeHierarchyRepository(error: ApiException(status, 'x')),
          context: context,
        );

        await loader.ensureRoot();

        expect(loader.rootStatus, HodHierarchyStatus.unauthorized);
        expect(loader.rootError, hodHierarchyUnauthorizedMessage);
      }
    });

    test('a failed root leaves the context unselectable', () async {
      final context = HodAcademicContext();
      final loader = HodHierarchyLoader(
        repository: _FakeHierarchyRepository(error: const ApiException.serverError()),
        context: context,
      );

      await loader.ensureRoot();

      expect(context.hierarchyAvailable, isFalse);
      expect(context.optionsFor(HodContextLevel.academicSession), isEmpty);
    });
  });

  group('program scoping of a session', () {
    test('a session resolves to exactly one program', () async {
      final context = HodAcademicContext();
      final loader = HodHierarchyLoader(
          repository: _FakeHierarchyRepository(), context: context);
      await loader.ensureRoot();

      expect(loader.programIdForSession(1), 10);
      expect(loader.programIdForSession(2), 11);
      expect(loader.programIdForSession(null), isNull);
      expect(loader.programIdForSession(999), isNull);
    });
  });

  group('dependent levels', () {
    test('semesters and sections are published for the selected session',
        () async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository();
      final loader =
          HodHierarchyLoader(repository: repository, context: context);
      await loader.ensureRoot();

      await loader.loadSemesters(academicSessionId: 1);
      await loader.loadSections(academicSessionId: 1);

      expect(loader.statusFor(HodContextLevel.semester), HodHierarchyStatus.ready);
      expect(context.optionsFor(HodContextLevel.semester), hasLength(2));
      expect(context.optionsFor(HodContextLevel.section), hasLength(2));
      expect(repository.sectionRequests.single,
          {'session': 1, 'program': null, 'semester': null});
    });

    test('sections carry the selected semester as a server-side filter',
        () async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository();
      final loader =
          HodHierarchyLoader(repository: repository, context: context);
      await loader.ensureRoot();

      await loader.loadSections(academicSessionId: 1, programId: 10, semesterId: 100);

      expect(repository.sectionRequests.last,
          {'session': 1, 'program': 10, 'semester': 100});
    });

    test('subjects are published with their real faculty', () async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository();
      final loader =
          HodHierarchyLoader(repository: repository, context: context);
      await loader.ensureRoot();
      context.select(HodContextLevel.semester, 100, name: 'Semester 3');

      final subjects =
          await loader.loadSubjects(semesterId: 100, sectionId: 200);

      expect(subjects, hasLength(1));
      expect(subjects.single.name, 'DSA');
      expect(subjects.single.facultyNames, ['Prof Alice']);
      expect(repository.subjectRequests.single,
          {'semester': 100, 'section': 200});
      expect(
        loader.subjectsWithFaculty(semesterId: 100).single.facultyNames,
        ['Prof Alice'],
      );
    });

    test('cached faculty is never served for a different semester', () async {
      final context = HodAcademicContext();
      final repository = _FakeHierarchyRepository();
      final loader =
          HodHierarchyLoader(repository: repository, context: context);
      await loader.ensureRoot();
      context.select(HodContextLevel.semester, 100, name: 'Semester 3');
      await loader.loadSubjects(semesterId: 100, sectionId: 200);

      // The context moved on without a new subject fetch.
      expect(loader.subjectsWithFaculty(semesterId: 101), isEmpty);
    });

    test('an empty dependent level is reported as empty', () async {
      final context = HodAcademicContext();
      final loader = HodHierarchyLoader(
        repository: _FakeHierarchyRepository(),
        context: context,
      );
      await loader.ensureRoot();

      // The fake always returns two; force an empty list through setOptions
      // semantics by checking the status mapping with a repository that has no
      // semesters for a session.
      final emptyLoader = HodHierarchyLoader(
        repository: _EmptyHierarchyRepository(),
        context: HodAcademicContext(),
      );
      await emptyLoader.ensureRoot();
      await emptyLoader.loadSemesters(academicSessionId: 1);

      expect(emptyLoader.statusFor(HodContextLevel.semester),
          HodHierarchyStatus.empty);
      expect(loader.statusFor(HodContextLevel.semester),
          isNot(HodHierarchyStatus.empty));
    });

    test('an unauthorized dependent level is distinct from an error', () async {
      final context = HodAcademicContext();
      final loader = HodHierarchyLoader(
        repository: _FakeHierarchyRepository(error: const ApiException.forbidden()),
        context: context,
      );
      await loader.ensureRoot();

      await loader.loadSemesters(academicSessionId: 1);

      expect(loader.statusFor(HodContextLevel.semester),
          HodHierarchyStatus.unauthorized);
      expect(loader.errorFor(HodContextLevel.semester),
          hodHierarchyUnauthorizedMessage);
    });
  });
}

class _EmptyHierarchyRepository extends HodHierarchyRepository {
  @override
  Future<HodHierarchyRoot> getRoot() async => _root();

  @override
  Future<List<HodHierarchyOption>> getSemesters({required int academicSessionId}) async =>
      const [];

  @override
  Future<List<HodHierarchyOption>> getSections({
    required int academicSessionId,
    int? programId,
    int? semesterId,
  }) async =>
      const [];

  @override
  Future<List<HodHierarchySubject>> getSubjects({
    required int semesterId,
    int? sectionId,
  }) async =>
      const [];
}
