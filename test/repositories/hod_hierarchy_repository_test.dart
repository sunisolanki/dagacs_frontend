import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/repositories/hod_hierarchy_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Answers from the longest matching path prefix and records every request.
class _StubClient extends ApiClient {
  _StubClient(this.responses) : super(httpClient: _NoopClient());

  final Map<String, dynamic> responses;
  final List<String> paths = [];

  @override
  Future<dynamic> get(String path) async {
    paths.add(path);
    if (responses.isEmpty) return const <dynamic>[];
    final matches = responses.keys.where(path.startsWith).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (matches.isEmpty) return const <dynamic>[];
    return responses[matches.first];
  }
}

class _NoopClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError('the stub client never performs I/O');
}

void main() {
  final client = _StubClient({
    '/hod/hierarchy/semesters': [
      {'id': 100, 'name': 'Semester 3', 'code': 'S3', 'studentCount': 58},
    ],
    '/hod/hierarchy/sections': [
      {
        'id': 200,
        'name': 'A',
        'code': 'SEC-A',
        'batchId': 10,
        'batchName': 'Batch 1',
        'studentCount': 30,
      },
    ],
    '/hod/hierarchy/subjects': [
      {
        'id': 300,
        'code': 'CODSA',
        'name': 'DSA',
        'semesterId': 100,
        'semesterName': 'Semester 3',
        'programId': 10,
        'programName': 'B.Tech CSE',
        'facultyNames': ['Prof Alice', 'Prof Bob'],
      },
    ],
    '/hod/hierarchy': {
      'departmentId': 1,
      'departmentName': 'CSE',
      'departmentCode': 'CS',
      'programs': [
        {'id': 10, 'name': 'B.Tech CSE', 'code': 'BTCSE'},
      ],
      'academicSessions': [
        {
          'id': 1,
          'name': '2026-27',
          'code': 'S1',
          'programId': 10,
          'programName': 'B.Tech CSE',
        },
      ],
    },
  });
  final repository = HodHierarchyRepository(client);

  test('root decodes the department and both cascade roots', () async {
    final root = await repository.getRoot();

    expect(root.departmentId, 1);
    expect(root.departmentName, 'CSE');
    expect(root.programs.single.name, 'B.Tech CSE');
    expect(root.academicSessions.single.programName, 'B.Tech CSE');
    expect(client.paths, ['/hod/hierarchy']);
  });

  test('never sends a department identifier on any hierarchy request', () async {
    await repository.getRoot();
    await repository.getSemesters(academicSessionId: 1);
    await repository.getSections(academicSessionId: 1);
    await repository.getSubjects(semesterId: 100);

    expect(client.paths, isNotEmpty);
    for (final path in client.paths) {
      expect(path.toLowerCase(), isNot(contains('departmentid')), reason: path);
    }
  });

  test('semesters request carries only the academic session', () async {
    await repository.getSemesters(academicSessionId: 1);

    expect(client.paths.last, '/hod/hierarchy/semesters?academicSessionId=1');
  });

  test('sections request omits absent filters entirely', () async {
    await repository.getSections(academicSessionId: 1);

    expect(client.paths.last, '/hod/hierarchy/sections?academicSessionId=1');
  });

  test('sections request includes only the supplied filters', () async {
    await repository
        .getSections(academicSessionId: 1, programId: 10, semesterId: 100);

    expect(client.paths.last,
        '/hod/hierarchy/sections?academicSessionId=1&programId=10&semesterId=100');
  });

  test('subjects request omits an absent section and includes a present one',
      () async {
    await repository.getSubjects(semesterId: 100);
    expect(client.paths.last, '/hod/hierarchy/subjects?semesterId=100');

    await repository.getSubjects(semesterId: 100, sectionId: 200);
    expect(client.paths.last, '/hod/hierarchy/subjects?semesterId=100&sectionId=200');
  });

  test('option decoding keeps the real display fields', () async {
    final sections = await repository.getSections(academicSessionId: 1);
    expect(sections.single.code, 'SEC-A');
    expect(sections.single.batchName, 'Batch 1');
    expect(sections.single.studentCount, 30);
  });

  test('subject decoding keeps program, semester and faculty', () async {
    final subjects = await repository.getSubjects(semesterId: 100);
    expect(subjects.single.code, 'CODSA');
    expect(subjects.single.programName, 'B.Tech CSE');
    expect(subjects.single.semesterName, 'Semester 3');
    expect(subjects.single.facultyNames, ['Prof Alice', 'Prof Bob']);
  });

  test('a level that returns nothing decodes to an empty list, not an error',
      () async {
    final empty = HodHierarchyRepository(_StubClient(const {}));
    expect(await empty.getSemesters(academicSessionId: 1), isEmpty);
  });
}
