import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/hod_attendance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Answers from the longest matching path prefix and records every request.
class _StubClient extends ApiClient {
  _StubClient(this.responses) : super(httpClient: _NoopClient());

  final Map<String, dynamic> responses;
  final List<String> paths = [];
  Future<dynamic> get(String path) async {
    paths.add(path);
    final matches = responses.keys.where(path.startsWith).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (matches.isEmpty) return const <dynamic>[];
    return responses[matches.first];
  }
  Future<http.Response> getBytes(String path) async {
    paths.add(path);
    return http.Response.bytes(
      [1, 2, 3],
      200,
      headers: const {
        'content-disposition':
            'attachment; filename="dagacs_hod_attendance_matrix_all.xlsx"',
        'content-type': 'application/vnd.openxmlformats-officedocument'
            '.spreadsheetml.sheet',
      },
    );
  }
}

class _NoopClient extends http.BaseClient {
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError('the stub client never performs I/O');
}

/// The request contract of the Phase 3 HOD attendance API.
///
/// The most important assertion in this file is the negative one: no request
/// ever carries a department id, because the department is derived from the JWT
/// on the server and is not a report dimension.
void main() {
  late _StubClient client;
  late HodAttendanceRepository repository;

  final matrix = {
    'context': {'complete': true},
    'subjects': <dynamic>[],
    'students': <dynamic>[],
    'page': 0,
    'size': 50,
    'totalElements': 0,
    'totalPages': 0,
    'singleSubject': false,
  };

  setUp(() {
    client = _StubClient({
      '/hod/attendance/overview': {
        'totalStudents': 0,
        'overallPresentCount': 0,
        'overallTotalClasses': 0,
        'belowThresholdCount': 0,
        'noConductedClasses': 0,
        'subjects': <dynamic>[],
        'distribution': <dynamic>[],
      },
      '/hod/attendance/matrix/export': {'ignored': true},
      '/hod/attendance/matrix': matrix,
      '/hod/attendance/student/91': {'studentId': 91, 'subjects': <dynamic>[]},
      '/hod/attendance/subject/101': {'subjectId': 101, 'studentRows': <dynamic>[]},
      '/hod/attendance/low': {
        'belowThresholdCount': 0,
        'totalStudents': 0,
        'students': <dynamic>[],
      },
      '/hod/attendance/context': {'complete': true},
    });
    repository = HodAttendanceRepository(client);
  });

  test('overview sends only the levels that were selected', () async {
    await repository.getOverview(academicSessionId: 1, programId: 2);

    expect(client.paths.last, '/hod/attendance/overview?academicSessionId=1&programId=2');
  });

  test('overview omits the query string entirely with no context', () async {
    await repository.getOverview();

    expect(client.paths.last, '/hod/attendance/overview');
  });

  test('matrix sends the full context plus paging, sorting and direction',
      () async {
    await repository.getMatrix(
      academicSessionId: 1,
      programId: 2,
      semesterId: 3,
      sectionId: 4,
      sortBy: 'overallPercentage',
      direction: 'desc',
      page: 2,
      size: 25,
    );

    final path = client.paths.last;
    expect(path, startsWith('/hod/attendance/matrix?'));
    expect(path, contains('academicSessionId=1'));
    expect(path, contains('programId=2'));
    expect(path, contains('semesterId=3'));
    expect(path, contains('sectionId=4'));
    expect(path, contains('page=2'));
    expect(path, contains('size=25'));
    expect(path, contains('sortBy=overallPercentage'));
    expect(path, contains('direction=desc'));
  });

  test('matrix defaults to enrollment-number order on the first page', () async {
    await repository.getMatrix(
        academicSessionId: 1, programId: 2, semesterId: 3, sectionId: 4);

    final path = client.paths.last;
    expect(path, contains('page=0'));
    expect(path, contains('sortBy=enrollmentNumber'));
    expect(path, contains('direction=asc'));
    expect(path, isNot(contains('subjectId')));
  });

  test('matrix includes a subject only when one is selected', () async {
    await repository.getMatrix(
      academicSessionId: 1,
      programId: 2,
      semesterId: 3,
      sectionId: 4,
      subjectId: 101,
    );

    expect(client.paths.last, contains('subjectId=101'));
  });

  test('an incomplete context never reaches the network for the matrix',
      () async {
    await expectLater(
      repository.getMatrix(
        academicSessionId: 1,
        programId: 2,
        semesterId: 3,
        sectionId: null,
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400)
          .having((e) => e.message, 'message',
              HodAttendanceRepository.matrixContextRequiredMessage)),
    );
    expect(client.paths, isEmpty);
  });

  test('the matrix context message is exactly the documented contract',
      () async {
    expect(
      HodAttendanceRepository.matrixContextRequiredMessage,
      'Select Academic Session, Program, Semester and Section to view the '
      'Attendance Matrix.',
    );
  });

  test('date filtering is sent alongside the context, never instead of it',
      () async {
    await repository.getMatrix(
      academicSessionId: 1,
      programId: 2,
      semesterId: 3,
      sectionId: 4,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
    );

    final path = client.paths.last;
    expect(path, contains('academicSessionId=1'));
    expect(path, contains('sectionId=4'));
    expect(path, contains('startDate=2026-01-01'));
    expect(path, contains('endDate=2026-01-31'));
  });

  test('student detail targets the student path with the full context',
      () async {
    await repository.getStudentDetail(
      studentId: 91,
      academicSessionId: 1,
      programId: 2,
      semesterId: 3,
      sectionId: 4,
    );

    expect(
      client.paths.last,
      '/hod/attendance/student/91?academicSessionId=1&programId=2'
      '&semesterId=3&sectionId=4',
    );
  });

  test('subject detail targets the subject path with the full context',
      () async {
    await repository.getSubjectDetail(
      subjectId: 101,
      academicSessionId: 1,
      programId: 2,
      semesterId: 3,
      sectionId: 4,
    );

    expect(
      client.paths.last,
      '/hod/attendance/subject/101?academicSessionId=1&programId=2'
      '&semesterId=3&sectionId=4',
    );
  });

  test('low attendance sends the selected context and decodes the breakdown',
      () async {
    client.responses['/hod/attendance/low'] = {
      'thresholdPercentage': 75.0,
      'totalStudents': 3,
      'belowThresholdCount': 1,
      'students': [
        {
          'studentId': 93,
          'enrollmentNumber': 'E-003',
          'rollNumber': 'R3',
          'studentName': 'Carol',
          'sectionName': 'A',
          'presentCount': 3,
          'totalClasses': 6,
          'percentage': 50.0,
          'subjectsBelowThreshold': 1,
          'belowThresholdSubjects': [
            {
              'subjectId': 101,
              'subjectCode': 'CS301',
              'subjectName': 'Data Structures',
              'present': 1,
              'total': 4,
              'percentage': 25.0,
            },
          ],
        },
      ],
    };

    final report = await repository.getLowAttendance(
        academicSessionId: 1, programId: 2, semesterId: 3, sectionId: 4);

    expect(client.paths.last, contains('sectionId=4'));
    expect(report.belowThresholdCount, 1);
    expect(report.students.single.belowThresholdSubjects.single.subjectCode,
        'CS301');
  });

  test('context metadata is requested without any extra filter', () async {
    final context = await repository
        .getContext(academicSessionId: 1, programId: 2);

    expect(client.paths.last,
        '/hod/attendance/context?academicSessionId=1&programId=2');
    expect(context.complete, isTrue);
  });

  test('export requests the cross-tab path and reads the backend file name',
      () async {
    final payload = await repository.exportMatrix(
      'xlsx',
      academicSessionId: 1,
      programId: 2,
      semesterId: 3,
      sectionId: 4,
    );

    expect(client.paths.last,
        startsWith('/hod/attendance/matrix/export.xlsx?'));
    expect(payload.fileName, 'dagacs_hod_attendance_matrix_all.xlsx');
    expect(payload.contentType, contains('spreadsheetml'));
  });

  test('export refuses to build a request for an incomplete context', () async {
    await expectLater(
      repository.exportMatrix('pdf',
          academicSessionId: 1, programId: null, semesterId: 3, sectionId: 4),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400)),
    );
    expect(client.paths, isEmpty);
  });

  test('a non-map payload is a server error, not a silent empty result',
      () async {
    client.responses['/hod/attendance/matrix'] = <dynamic>[];

    await expectLater(
      repository.getMatrix(
          academicSessionId: 1,
          programId: 2,
          semesterId: 3,
          sectionId: 4),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500)),
    );
  });

  test('no request ever carries a department identifier', () async {
    await repository.getOverview(academicSessionId: 1);
    await repository.getMatrix(
        academicSessionId: 1, programId: 2, semesterId: 3, sectionId: 4);
    await repository.getStudentDetail(studentId: 91, sectionId: 4);
    await repository.getSubjectDetail(subjectId: 101, sectionId: 4);
    await repository.getLowAttendance(sectionId: 4);
    await repository.getContext(sectionId: 4);
    await repository.exportMatrix('xlsx',
        academicSessionId: 1, programId: 2, semesterId: 3, sectionId: 4);

    expect(client.paths, isNotEmpty);
    for (final path in client.paths) {
      expect(path.toLowerCase(), isNot(contains('departmentid')), reason: path);
    }
  });
}
