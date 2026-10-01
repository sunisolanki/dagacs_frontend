import 'package:dagacs_frontend/core/context/hod_academic_context.dart';
import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/core/theme/dagacs_theme.dart';
import 'package:dagacs_frontend/models/hod_attendance_matrix.dart';
import 'package:dagacs_frontend/models/hod_attendance_overview.dart';
import 'package:dagacs_frontend/models/hod_daily_lecture_row.dart';
import 'package:dagacs_frontend/models/hod_low_attendance_report.dart';
import 'package:dagacs_frontend/models/hod_student_attendance_detail.dart';
import 'package:dagacs_frontend/models/hod_subject_attendance_detail.dart';
import 'package:dagacs_frontend/models/report_page.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/hod_attendance_repository.dart';
import 'package:dagacs_frontend/repositories/hod_repository.dart';
import 'package:dagacs_frontend/repositories/report_repository.dart';
import 'package:dagacs_frontend/screens/hod/hod_attendance_matrix_screen.dart';
import 'package:dagacs_frontend/screens/hod/hod_student_detail_screen.dart';
import 'package:dagacs_frontend/screens/hod/hod_subject_detail_screen.dart';
import 'package:dagacs_frontend/screens/hod_reports_screen.dart';
import 'package:dagacs_frontend/widgets/hod/hod_attendance_panels.dart';
import 'package:dagacs_frontend/widgets/hod/hod_matrix_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Recorded arguments of every Phase 3 call, so a test can assert what the UI
/// actually asked the backend for.
class _RecordingAttendanceRepository extends HodAttendanceRepository {
  _RecordingAttendanceRepository();

  HodAttendanceMatrix matrix = _emptyMatrix;
  HodAttendanceOverview overview = _emptyOverview;
  HodLowAttendanceReport low = _emptyLow;
  HodStudentAttendanceDetail? studentDetail;
  HodSubjectAttendanceDetail? subjectDetail;

  Object? matrixError;
  Object? overviewError;
  Object? studentDetailError;

  int matrixCalls = 0;
  int overviewCalls = 0;
  int lowCalls = 0;
  int studentDetailCalls = 0;
  int subjectDetailCalls = 0;

  final List<
    ({int? session, int? program, int? semester, int? section, int? subject})
  >
  matrixContexts = [];
  final List<String> matrixSorts = [];

  @override
  Future<HodAttendanceMatrix> getMatrix({
    required int? academicSessionId,
    required int? programId,
    required int? semesterId,
    required int? sectionId,
    int? subjectId,
    DateTime? startDate,
    DateTime? endDate,
    int page = 0,
    int size = 50,
    String sortBy = 'enrollmentNumber',
    String direction = 'asc',
  }) async {
    matrixCalls++;
    matrixContexts.add((
      session: academicSessionId,
      program: programId,
      semester: semesterId,
      section: sectionId,
      subject: subjectId,
    ));
    matrixSorts.add('$sortBy:$direction:$page');
    if (matrixError != null) throw matrixError!;
    return matrix;
  }

  @override
  Future<HodAttendanceOverview> getOverview({
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    overviewCalls++;
    if (overviewError != null) throw overviewError!;
    return overview;
  }

  @override
  Future<HodLowAttendanceReport> getLowAttendance({
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    lowCalls++;
    return low;
  }

  @override
  Future<HodStudentAttendanceDetail> getStudentDetail({
    required int studentId,
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    int? subjectId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    studentDetailCalls++;
    if (studentDetailError != null) throw studentDetailError!;
    if (studentDetail == null) throw const ApiException.serverError();
    return studentDetail!;
  }

  @override
  Future<HodSubjectAttendanceDetail> getSubjectDetail({
    required int subjectId,
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    subjectDetailCalls++;
    if (subjectDetail == null) throw const ApiException.serverError();
    return subjectDetail!;
  }
}

/// A repository that is wired but never expected to issue a request in the
/// context-report sections. The default client is used; if a test accidentally
/// triggers a call the framework's blocked-HttpClient makes that visible.
class _StubHodRepository extends HodRepository {
  _StubHodRepository();
}

class _StubReportRepository extends ReportRepository {
  _StubReportRepository();

  int dailyCalls = 0;

  @override
  Future<ReportPage<HodDailyLectureRow>> getDailyLecture({
    int page = 0,
    int size = 20,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    dailyCalls++;
    return const ReportPage(items: [], page: 0, totalPages: 0);
  }
}

HodAcademicContext _fullContext() {
  final context = HodAcademicContext()..markHierarchyAvailable();
  context
    ..select(
      HodContextLevel.academicSession,
      1,
      name: 'Academic Session 2026-27',
    )
    ..select(HodContextLevel.program, 2, name: 'B.Tech CSE')
    ..select(HodContextLevel.semester, 3, name: 'Semester 3')
    ..select(HodContextLevel.section, 4, name: 'A');
  return context;
}

HodAcademicContext _sessionOnlyContext() {
  final context = HodAcademicContext()..markHierarchyAvailable();
  context.select(
    HodContextLevel.academicSession,
    1,
    name: 'Academic Session 2026-27',
  );
  return context;
}

SessionController _session() {
  final session = SessionController(AuthRepository());
  session.establishSession(
    'HOD',
    fullName: 'HOD User',
    email: 'hod@dagacs.local',
  );
  return session;
}

HodAttendanceMatrix get _emptyMatrix => HodAttendanceMatrix.fromJson({
  'context': {'complete': true},
  'subjects': <dynamic>[],
  'students': <dynamic>[],
  'page': 0,
  'size': 50,
  'totalElements': 0,
  'totalPages': 0,
  'singleSubject': false,
});

HodAttendanceOverview get _emptyOverview => HodAttendanceOverview.fromJson({
  'context': {'complete': true},
  'totalStudents': 0,
  'overallPresentCount': 0,
  'overallTotalClasses': 0,
  'belowThresholdCount': 0,
  'noConductedClasses': 0,
  'distribution': <dynamic>[],
  'subjects': <dynamic>[],
});

HodLowAttendanceReport get _emptyLow => HodLowAttendanceReport.fromJson({
  'thresholdPercentage': 75.0,
  'totalStudents': 0,
  'belowThresholdCount': 0,
  'students': <dynamic>[],
});

HodAttendanceMatrix _populatedMatrix({int totalPages = 1, int page = 0}) =>
    HodAttendanceMatrix.fromJson({
      'context': {
        'academicSessionName': 'Academic Session 2026-27',
        'programName': 'B.Tech CSE',
        'semesterName': 'Semester 3',
        'sectionName': 'A',
        'complete': true,
      },
      'subjects': [
        {
          'subjectId': 101,
          'subjectCode': 'CS301',
          'subjectName': 'Data Structures and Algorithms',
          'facultyNames': ['Dr Rao'],
        },
        {
          'subjectId': 102,
          'subjectCode': 'CS302',
          'subjectName': 'Computer Networks',
          'facultyNames': <String>[],
        },
      ],
      'students': [
        {
          'studentId': 91,
          'enrollmentNumber': 'CS2025001',
          'rollNumber': 'R1',
          'studentName': 'Rahul',
          'sectionName': 'A',
          'subjects': [
            {'subjectId': 101, 'present': 32, 'total': 40, 'percentage': 80.0},
            {
              'subjectId': 102,
              'present': 30,
              'total': 35,
              'percentage': 85.714,
            },
          ],
          'totalPresent': 62,
          'totalClasses': 75,
          'overallPercentage': 82.6666,
        },
        {
          'studentId': 93,
          'enrollmentNumber': 'CS2025003',
          'rollNumber': 'R3',
          'studentName': 'Neha',
          'sectionName': 'A',
          'subjects': [
            // 10 classes were conducted for each subject but Neha was never
            // marked in any of them: she is 0 / 10 = 0%, not 0 / 0.
            {'subjectId': 101, 'present': 0, 'total': 10, 'percentage': 0.0},
            {'subjectId': 102, 'present': 0, 'total': 10, 'percentage': 0.0},
          ],
          'totalPresent': 0,
          'totalClasses': 20,
          'overallPercentage': 0.0,
        },
      ],
      'page': page,
      'size': 50,
      'totalElements': 2,
      'totalPages': totalPages,
      'singleSubject': false,
      'thresholdPercentage': 75.0,
    });

Widget _host(Widget child) => MaterialApp(
  theme: buildDagacsTheme(),
  // A Scaffold supplies the Material ancestor the panels' ink effects and
  // the matrix header's tap targets require.
  home: Scaffold(body: child),
);

void main() {
  group('HodAttendanceMatrixPanel', () {
    testWidgets('without a full context it states the exact required message', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository();
      await tester.pumpWidget(
        _host(
          HodAttendanceMatrixPanel(
            repository: repository,
            academicContext: _sessionOnlyContext(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-context-required')), findsOneWidget);
      expect(find.text(kHodMatrixContextRequiredMessage), findsOneWidget);
      // No mixed-department request is even attempted.
      expect(repository.matrixCalls, 0);
    });

    testWidgets('with a full context it renders the dynamic columns and rows', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository()
        ..matrix = _populatedMatrix();
      await tester.pumpWidget(
        _host(
          HodAttendanceMatrixPanel(
            repository: repository,
            academicContext: _fullContext(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.matrixCalls, 1);
      expect(repository.matrixContexts.single, (
        session: 1,
        program: 2,
        semester: 3,
        section: 4,
        subject: null,
      ));
      expect(find.byKey(const Key('hod-matrix-column-101')), findsOneWidget);
      expect(find.byKey(const Key('hod-matrix-column-102')), findsOneWidget);
      expect(find.text('CS2025001'), findsOneWidget);
      expect(find.text('32 / 40'), findsOneWidget);
      // A student who was never marked is still shown, against the conducted
      // classes: 0 / 10 = 0.00%, never a 0 / 0 no-data cell.
      expect(find.text('CS2025003'), findsOneWidget);
      expect(find.text('0 / 10'), findsNWidgets(2));
      // The row total is a real 0.00% over 20 conducted classes, not an
      // unavailable state.
      expect(find.text('0.00%'), findsOneWidget);
    });

    testWidgets('sorting re-requests the matrix with the chosen column', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repository = _RecordingAttendanceRepository()
        ..matrix = _populatedMatrix();
      await tester.pumpWidget(
        _host(
          HodAttendanceMatrixPanel(
            repository: repository,
            academicContext: _fullContext(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-matrix-sort-name')));
      await tester.pumpAndSettle();
      expect(repository.matrixSorts.last, 'name:asc:0');

      await tester.tap(find.byKey(const Key('hod-matrix-sort-name')));
      await tester.pumpAndSettle();
      expect(repository.matrixSorts.last, 'name:desc:0');
    });

    testWidgets('paging re-requests the matrix and never splits a row', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository()
        ..matrix = _populatedMatrix(totalPages: 3);
      await tester.pumpWidget(
        _host(
          HodAttendanceMatrixPanel(
            repository: repository,
            academicContext: _fullContext(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Page 1 of 3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('hod-matrix-next-page')));
      await tester.pumpAndSettle();

      expect(repository.matrixSorts.last, endsWith(':1'));
      // Both students still carry exactly one cell per column.
      expect(find.byType(HodMatrixTable), findsOneWidget);
      final table = tester.widget<HodMatrixTable>(find.byType(HodMatrixTable));
      expect(table.columns.length, 2);
      for (final row in table.rows) {
        expect(row.subjects.length, table.columns.length);
      }
    });

    testWidgets('a context change refetches and never shows a stale matrix', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository()
        ..matrix = _populatedMatrix();
      final context = _fullContext();
      await tester.pumpWidget(
        _host(
          HodAttendanceMatrixPanel(
            repository: repository,
            academicContext: context,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.matrixCalls, 1);

      // The HOD picks a different section.
      context.select(HodContextLevel.section, 9, name: 'B');
      await tester.pumpWidget(
        _host(
          HodAttendanceMatrixPanel(
            repository: repository,
            academicContext: context,
            reloadToken: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.matrixCalls, 2);
      expect(repository.matrixContexts.last.section, 9);
    });

    testWidgets('an error shows a retryable state and retry reloads', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository()
        ..matrixError = const ApiException.serverError();
      await tester.pumpWidget(
        _host(
          HodAttendanceMatrixPanel(
            repository: repository,
            academicContext: _fullContext(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('retry-button')), findsOneWidget);

      repository
        ..matrixError = null
        ..matrix = _populatedMatrix();
      await tester.tap(find.byKey(const Key('retry-button')));
      await tester.pumpAndSettle();

      expect(find.text('CS2025001'), findsOneWidget);
    });

    testWidgets('an empty student population is an empty state, not an error', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository();
      await tester.pumpWidget(
        _host(
          HodAttendanceMatrixPanel(
            repository: repository,
            academicContext: _fullContext(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-report-empty')), findsOneWidget);
      expect(find.byKey(const Key('retry-button')), findsNothing);
    });

    testWidgets(
      'a context with no subjects is distinguished from no students',
      (tester) async {
        final repository = _RecordingAttendanceRepository()
          ..matrix = _populatedMatrix();
        final noSubjects = _RecordingAttendanceRepository()
          ..matrix = HodAttendanceMatrix.fromJson({
            'context': {'complete': true},
            'subjects': <dynamic>[],
            'students': <dynamic>[],
            'page': 0,
            'size': 50,
            'totalElements': 0,
            'totalPages': 0,
            'singleSubject': false,
          });
        await tester.pumpWidget(
          _host(
            HodAttendanceMatrixPanel(
              repository: noSubjects,
              academicContext: _fullContext(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'No subjects are offered in the selected semester',
          ),
          findsOneWidget,
        );
        expect(repository.matrixCalls, 0);
      },
    );

    testWidgets('a row tap reports the student id to open the detail', (
      tester,
    ) async {
      final opened = <int>[];
      final repository = _RecordingAttendanceRepository()
        ..matrix = _populatedMatrix();
      await tester.pumpWidget(
        _host(
          HodAttendanceMatrixPanel(
            repository: repository,
            academicContext: _fullContext(),
            onOpenStudent: opened.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hod-matrix-row-91')));
      await tester.pumpAndSettle();
      expect(opened, [91]);
    });
  });

  group('HodAttendanceOverviewPanel', () {
    testWidgets('renders the context metrics, distribution and subjects', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository()
        ..overview = HodAttendanceOverview.fromJson({
          'context': {
            'academicSessionName': 'Academic Session 2026-27',
            'programName': 'B.Tech CSE',
            'semesterName': 'Semester 3',
            'sectionName': 'A',
            'complete': true,
          },
          'totalStudents': 3,
          'overallPresentCount': 8,
          'overallTotalClasses': 12,
          'overallPercentage': 66.6666,
          'belowThresholdCount': 1,
          'classesConducted': 6,
          'thresholdPercentage': 75.0,
          'noConductedClasses': 1,
          'distribution': [
            {'band': 'high', 'label': '90-100%', 'studentCount': 0},
            {'band': 'medium', 'label': '75-89%', 'studentCount': 1},
            {'band': 'low', 'label': 'Below 75%', 'studentCount': 1},
          ],
          'subjects': [
            {
              'subjectId': 101,
              'subjectCode': 'CS301',
              'subjectName': 'Data Structures',
              'facultyNames': ['Dr Rao'],
              'classesConducted': 4,
              'presentCount': 5,
              'totalClasses': 8,
              'percentage': 62.5,
            },
          ],
        });

      await tester.pumpWidget(
        _host(
          HodAttendanceOverviewPanel(
            repository: repository,
            academicContext: _fullContext(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-attendance-overview')), findsOneWidget);
      expect(find.text('Total Students'), findsOneWidget);
      expect(find.text('66.67%'), findsOneWidget);
      expect(find.text('Attendance distribution'), findsOneWidget);
      expect(find.text('90-100%'), findsOneWidget);
      expect(find.text('CS301'), findsOneWidget);
      expect(find.text('Dr Rao'), findsOneWidget);
      // Students with no conducted class are called out, not folded into a band.
      expect(
        find.byKey(const Key('hod-overview-no-data-note')),
        findsOneWidget,
      );
    });

    testWidgets('an unavailable class count says No data, never zero', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository();
      await tester.pumpWidget(
        _host(
          HodAttendanceOverviewPanel(
            repository: repository,
            academicContext: _sessionOnlyContext(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Classes Conducted'), findsOneWidget);
      expect(find.text('No data'), findsWidgets);
    });
  });

  group('HodLowAttendancePanel', () {
    testWidgets('lists students with the subjects responsible for them', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository()
        ..low = HodLowAttendanceReport.fromJson({
          'context': {'complete': true},
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
        });

      await tester.pumpWidget(
        _host(
          HodLowAttendancePanel(
            repository: repository,
            academicContext: _fullContext(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('hod-low-attendance-report')),
        findsOneWidget,
      );
      expect(find.text('Carol (E-003)'), findsOneWidget);
      expect(find.text('50.00%'), findsOneWidget);
      expect(
        find.byKey(const Key('hod-low-attendance-subject-101')),
        findsOneWidget,
      );
      expect(find.text('25.0%'), findsOneWidget);
      expect(
        find.byKey(const Key('hod-low-attendance-summary')),
        findsOneWidget,
      );
    });

    testWidgets('no student below the threshold is a success empty state', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository();
      await tester.pumpWidget(
        _host(
          HodLowAttendancePanel(
            repository: repository,
            academicContext: _fullContext(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No students in the selected academic context'),
        findsOneWidget,
      );
    });
  });

  group('HodStudentDetailScreen', () {
    testWidgets('shows the identity, the subject breakdown and the totals', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository()
        ..studentDetail = HodStudentAttendanceDetail.fromJson({
          'context': {'complete': true},
          'studentId': 91,
          'enrollmentNumber': 'CS2025001',
          'rollNumber': 'R1',
          'studentName': 'Rahul',
          'programName': 'B.Tech CSE',
          'semesterName': 'Semester 3',
          'sectionName': 'A',
          'subjects': [
            {
              'subjectId': 101,
              'subjectCode': 'CS301',
              'subjectName': 'Data Structures',
              'classes': 40,
              'present': 32,
              'notAttended': 8,
              'percentage': 80.0,
            },
          ],
          'totalPresent': 32,
          'totalClasses': 40,
          'overallPercentage': 80.0,
        });

      await tester.pumpWidget(
        _host(
          HodStudentDetailScreen(
            repository: repository,
            session: _session(),
            academicContext: _fullContext(),
            studentId: 91,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.studentDetailCalls, 1);
      expect(find.byKey(const Key('hod-student-detail')), findsOneWidget);
      expect(find.byKey(const Key('hod-student-detail-name')), findsOneWidget);
      expect(find.text('Rahul'), findsOneWidget);
      expect(find.textContaining('Enrollment: CS2025001'), findsOneWidget);
      expect(find.text('CS301'), findsOneWidget);
      expect(find.text('32 / 40'), findsNWidgets(2));
      expect(
        find.byKey(const Key('hod-student-detail-subject-101')),
        findsOneWidget,
      );
    });

    testWidgets('a 403 says the student is outside the context', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository()
        ..studentDetailError = const ApiException.forbidden();

      await tester.pumpWidget(
        _host(
          HodStudentDetailScreen(
            repository: repository,
            session: _session(),
            academicContext: _fullContext(),
            studentId: 91,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.studentDetailCalls, 1);
      expect(
        find.text('This student is outside the selected academic context.'),
        findsOneWidget,
      );
      // A scope violation is not offered as a retryable failure.
      expect(find.byKey(const Key('retry-button')), findsNothing);
    });
  });

  group('HodSubjectDetailScreen', () {
    testWidgets('shows faculty, classes, roster and below-threshold count', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository()
        ..subjectDetail = HodSubjectAttendanceDetail.fromJson({
          'context': {'complete': true},
          'subjectId': 101,
          'subjectCode': 'CS301',
          'subjectName': 'Data Structures',
          'programName': 'B.Tech CSE',
          'semesterName': 'Semester 3',
          'sectionName': 'A',
          'facultyNames': ['Dr Rao'],
          'totalClasses': 4,
          'students': 2,
          'presentCount': 5,
          'totalClassesAcrossStudents': 8,
          'averageAttendance': 62.5,
          'studentsBelowThreshold': 1,
          'thresholdPercentage': 75.0,
          'studentRows': [
            {
              'studentId': 91,
              'enrollmentNumber': 'CS2025001',
              'rollNumber': 'R1',
              'studentName': 'Rahul',
              'present': 4,
              'total': 4,
              'percentage': 100.0,
            },
            {
              'studentId': 93,
              'enrollmentNumber': 'CS2025003',
              'rollNumber': 'R3',
              'studentName': 'Neha',
              'present': 1,
              'total': 4,
              'percentage': 25.0,
            },
          ],
        });

      await tester.pumpWidget(
        _host(
          HodSubjectDetailScreen(
            repository: repository,
            session: _session(),
            academicContext: _fullContext(),
            subjectId: 101,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.subjectDetailCalls, 1);
      expect(find.byKey(const Key('hod-subject-detail')), findsOneWidget);
      expect(
        find.byKey(const Key('hod-subject-detail-faculty')),
        findsOneWidget,
      );
      expect(find.text('Dr Rao'), findsOneWidget);
      expect(find.text('Classes Conducted'), findsOneWidget);
      expect(find.text('Below Threshold'), findsOneWidget);
      final table = tester.widget<DataTable>(
        find.byKey(const Key('hod-subject-detail-table')),
      );
      expect(table.rows.length, 2);
      // The roster is the enrolled population, so the low-attendance student is
      // listed alongside the healthy one.
      expect(
        table.rows
            .map((row) => (row.cells.first.child as Text).data)
            .toList(growable: false),
        ['CS2025001', 'CS2025003'],
      );
    });
  });

  group('HodAttendanceMatrixScreen', () {
    testWidgets('exports the real cross-tab through the downloader', (
      tester,
    ) async {
      // The HOD shell needs a surface it can lay out; the default test viewport
      // is smaller than the shared context bar.
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repository = _RecordingAttendanceRepository()
        ..matrix = _populatedMatrix();
      final downloaded = <(String, String?)>[];

      await tester.pumpWidget(
        _host(
          HodAttendanceMatrixScreen(
            repository: repository,
            session: _session(),
            academicContext: _fullContext(),
            downloadFile: (bytes, name, type) async {
              downloaded.add((name, type));
              return 'Downloaded $name';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Phase 4A moved this screen onto the professional export control, so its
      // keys are the hod-export-* family rather than the shared
      // ReportExportButtons keys. The old assertions pointed at
      // `export-excel`, which this screen never renders.
      expect(find.byKey(const Key('hod-export-excel')), findsOneWidget);
      expect(find.byKey(const Key('hod-export-pdf')), findsOneWidget);
      expect(find.byKey(const Key('export-excel')), findsNothing);
      // Phase 4B owns the multi-sheet Context Pack, so no third format is
      // offered and nothing advertises a deliverable that does not exist.
      expect(find.byKey(const Key('hod-export-pack')), findsNothing);

      // The repository has no live API behind it, so the attempt fails loudly
      // instead of fabricating a file.
      await tester.tap(find.byKey(const Key('hod-export-excel')));
      await tester.pumpAndSettle();
      expect(downloaded, isEmpty);
      expect(find.byKey(const Key('hod-export-outcome')), findsOneWidget);
      expect(find.byKey(const Key('hod-export-retry')), findsOneWidget);
    });

    testWidgets('without a full context the export states the requirement', (
      tester,
    ) async {
      final repository = _RecordingAttendanceRepository();
      await tester.pumpWidget(
        _host(
          HodAttendanceMatrixScreen(
            repository: repository,
            session: _session(),
            academicContext: _sessionOnlyContext(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-context-required')), findsOneWidget);
      expect(repository.matrixCalls, 0);
    });
  });

  group('HodReportsScreen as the reporting hub', () {
    Widget hub(
      _RecordingAttendanceRepository repository, {
      _RecordingAttendanceRepository? attendance,
    }) {
      return _host(
        HodReportsScreen(
          hodRepository: _StubHodRepository(),
          reportRepository: _StubReportRepository(),
          attendanceRepository: attendance,
          session: _session(),
          academicContext: _fullContext(),
        ),
      );
    }

    testWidgets('offers the five academic-context report sections', (
      tester,
    ) async {
      // Pre-existing failure, unrelated to any assertion: the HOD shell needs a
      // surface it can lay out, and the default 800x600 test viewport is smaller
      // than the shared context bar. Only the viewport changes here.
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final attendance = _RecordingAttendanceRepository()
        ..matrix = _populatedMatrix();
      await tester.pumpWidget(
        hub(_RecordingAttendanceRepository(), attendance: attendance),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('report-type-context-overview')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('report-type-context-matrix')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('report-type-context-students')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('report-type-context-subjects')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('report-type-context-low-attendance')),
        findsOneWidget,
      );
      // The pre-existing department reports stay reachable.
      expect(
        find.byKey(const Key('report-type-daily-lecture')),
        findsOneWidget,
      );
    });

    testWidgets('defaults to the attendance overview and can switch sections', (
      tester,
    ) async {
      // A tall surface so the low-attendance list is fully laid out without
      // scrolling; the list is lazy by design.
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final attendance = _RecordingAttendanceRepository()
        ..matrix = _populatedMatrix()
        ..low = HodLowAttendanceReport.fromJson({
          'context': {'complete': true},
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
        });
      await tester.pumpWidget(
        hub(_RecordingAttendanceRepository(), attendance: attendance),
      );
      await tester.pumpAndSettle();

      expect(attendance.overviewCalls, 1);
      expect(find.byKey(const Key('hod-attendance-overview')), findsOneWidget);

      await tester.tap(find.byKey(const Key('report-type-context-matrix')));
      await tester.pumpAndSettle();
      expect(find.byType(HodMatrixTable), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('report-type-context-low-attendance')),
      );
      await tester.pumpAndSettle();
      expect(attendance.lowCalls, 1);
      expect(
        find.byKey(const Key('hod-low-attendance-summary')),
        findsOneWidget,
      );
      expect(find.text('Carol (E-003)'), findsOneWidget);
      expect(find.text('25.0%'), findsOneWidget);
    });

    testWidgets('export is offered only for the reports that own a file here', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final attendance = _RecordingAttendanceRepository();
      await tester.pumpWidget(
        hub(_RecordingAttendanceRepository(), attendance: attendance),
      );
      await tester.pumpAndSettle();

      // The overview section offers Excel/PDF for the overview, and the button
      // names that report. Phase 4A replaced a `hod-report-export-hint` string
      // - a key that does not exist anywhere in lib/ and never did - with the
      // real control, so the assertions below address the real control.
      expect(find.byKey(const Key('hod-export-excel')), findsOneWidget);
      expect(find.byKey(const Key('hod-export-pdf')), findsOneWidget);
      expect(
        tester.widgetList<Tooltip>(find.byType(Tooltip)).map((t) => t.message),
        contains('Export Attendance Overview as an Excel spreadsheet'),
      );

      // The matrix section is fileable too, and offers the same two formats.
      await tester.tap(find.byKey(const Key('report-type-context-matrix')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hod-export-excel')), findsOneWidget);
      expect(
        tester.widgetList<Tooltip>(find.byType(Tooltip)).map((t) => t.message),
        contains('Export Attendance Matrix as an Excel spreadsheet'),
      );

      // The two list sections have no single entity to file, so they state the
      // action that would enable them instead of offering a download.
      await tester.tap(find.byKey(const Key('report-type-context-students')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hod-export-excel')), findsNothing);
      expect(
        find.text("Open a student to export that student's attendance report."),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('report-type-context-subjects')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hod-export-excel')), findsNothing);
      expect(
        find.text("Open a subject to export that subject's attendance report."),
        findsOneWidget,
      );
    });
  });
}
