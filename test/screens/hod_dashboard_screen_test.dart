import 'package:dagacs_frontend/core/context/hod_academic_context.dart';
import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/hod_audit_log_entry.dart';
import 'package:dagacs_frontend/models/hod_dashboard.dart';
import 'package:dagacs_frontend/models/hod_low_attendance.dart';
import 'package:dagacs_frontend/models/hod_rollup.dart';
import 'package:dagacs_frontend/models/hod_section_attendance.dart';
import 'package:dagacs_frontend/models/hod_student_attendance.dart';
import 'package:dagacs_frontend/models/hod_subject_attendance.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/hod_repository.dart';
import 'package:dagacs_frontend/screens/hod/hod_audit_logs_screen.dart';
import 'package:dagacs_frontend/screens/hod/hod_low_attendance_screen.dart';
import 'package:dagacs_frontend/screens/hod/hod_overview_screen.dart';
import 'package:dagacs_frontend/screens/hod/hod_rollups_screen.dart';
import 'package:dagacs_frontend/screens/hod/hod_sections_screen.dart';
import 'package:dagacs_frontend/screens/hod/hod_students_screen.dart';
import 'package:dagacs_frontend/screens/hod/hod_structure_screen.dart';
import 'package:dagacs_frontend/screens/hod/hod_subjects_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behavioural coverage migrated from the former 7-tab HOD dashboard, extended
/// with the academic-context cases added once the hierarchy shipped.
///
/// Every assertion that previously targeted a tab now targets the equivalent
/// route screen, and the underlying repository contract, date-filter semantics,
/// error handling and empty states are unchanged. Percentage assertions use the
/// consistent two-decimal formatting.
class _FakeHodRepository extends HodRepository {
  _FakeHodRepository();

  Future<HodDashboard> Function()? onGetDashboard;
  Future<List<HodSectionAttendance>> Function(DateTime?, DateTime?)?
      onGetSections;
  Future<List<HodSubjectAttendance>> Function(DateTime?, DateTime?)?
      onGetSubjects;
  Future<List<HodStudentAttendance>> Function(DateTime?, DateTime?)?
      onGetStudents;
  Future<List<HodLowAttendance>> Function(DateTime?, DateTime?)?
      onGetLowAttendance;
  Future<List<HodRollup>> Function(String type)? onGetRollups;
  Future<List<HodAuditLogEntry>> Function(DateTime?, DateTime?)?
      onGetAuditLogs;

  String? lastRollupType;
  DateTime? lastDashboardStart;
  DateTime? lastDashboardEnd;
  DateTime? lastRollupStart;
  DateTime? lastRollupEnd;
  DateTime? lastSectionsStart;
  DateTime? lastSectionsEnd;
  DateTime? lastSubjectsStart;
  DateTime? lastSubjectsEnd;
  DateTime? lastStudentsStart;
  DateTime? lastStudentsEnd;
  DateTime? lastLowStart;
  DateTime? lastLowEnd;
  DateTime? lastAuditStart;
  DateTime? lastAuditEnd;

  // Recorded academic context, so the forwarding can be asserted.
  int? lastSectionsSession;
  int? lastSectionsProgram;
  int? lastSectionsSemester;
  int? lastSectionsSection;
  int? lastSubjectsSemester;
  int? lastStudentsSemester;
  int? lastLowSemester;

  @override
  Future<HodDashboard> getDashboard(
      {DateTime? startDate, DateTime? endDate}) {
    lastDashboardStart = startDate;
    lastDashboardEnd = endDate;
    return onGetDashboard!();
  }

  @override
  Future<List<HodSectionAttendance>> getSections(
      {DateTime? startDate,
      DateTime? endDate,
      int? academicSessionId,
      int? programId,
      int? semesterId,
      int? sectionId}) {
    lastSectionsStart = startDate;
    lastSectionsEnd = endDate;
    lastSectionsSession = academicSessionId;
    lastSectionsProgram = programId;
    lastSectionsSemester = semesterId;
    lastSectionsSection = sectionId;
    return onGetSections!(startDate, endDate);
  }

  @override
  Future<List<HodSubjectAttendance>> getSubjects(
      {DateTime? startDate,
      DateTime? endDate,
      int? academicSessionId,
      int? programId,
      int? semesterId,
      int? sectionId}) {
    lastSubjectsStart = startDate;
    lastSubjectsEnd = endDate;
    lastSubjectsSemester = semesterId;
    return onGetSubjects!(startDate, endDate);
  }

  @override
  Future<List<HodStudentAttendance>> getStudents(
      {DateTime? startDate,
      DateTime? endDate,
      int? academicSessionId,
      int? programId,
      int? semesterId,
      int? sectionId}) {
    lastStudentsStart = startDate;
    lastStudentsEnd = endDate;
    lastStudentsSemester = semesterId;
    return onGetStudents!(startDate, endDate);
  }

  @override
  Future<List<HodLowAttendance>> getLowAttendance(
      {DateTime? startDate,
      DateTime? endDate,
      int? academicSessionId,
      int? programId,
      int? semesterId,
      int? sectionId}) {
    lastLowStart = startDate;
    lastLowEnd = endDate;
    lastLowSemester = semesterId;
    return onGetLowAttendance!(startDate, endDate);
  }

  @override
  Future<List<HodRollup>> getRollups(
      {required String type, DateTime? startDate, DateTime? endDate}) {
    lastRollupType = type;
    lastRollupStart = startDate;
    lastRollupEnd = endDate;
    return onGetRollups!(type);
  }

  @override
  Future<List<HodAuditLogEntry>> getAuditLogs(
      {DateTime? startDate, DateTime? endDate}) {
    lastAuditStart = startDate;
    lastAuditEnd = endDate;
    return onGetAuditLogs!(startDate, endDate);
  }
}

const _dashboard = HodDashboard(
  departmentName: 'Computer Engineering',
  departmentCode: 'CE',
  programCount: 2,
  batchCount: 1,
  sectionCount: 3,
  studentCount: 60,
  totalRecordedCount: 500,
  presentCount: 400,
  overallPercentage: 80.0,
);

const _sections = [
  HodSectionAttendance(
      sectionName: 'A', sectionCode: 'CE-A', studentCount: 30,
      presentCount: 20, totalRecordedCount: 25, percentage: 80.0),
  HodSectionAttendance(
      sectionName: 'B', sectionCode: 'CE-B', studentCount: 30,
      presentCount: 0, totalRecordedCount: 0, percentage: null),
];

const _subjects = [
  HodSubjectAttendance(
      subjectCode: 'DS', subjectName: 'Database Systems',
      presentCount: 10, totalRecordedCount: 12, percentage: 83.33),
];

const _students = [
  HodStudentAttendance(
      rollNumber: 'R1', studentName: 'Alice', sectionName: 'A',
      presentCount: 8, totalRecordedCount: 10, percentage: 80.0),
  HodStudentAttendance(
      rollNumber: 'R2', studentName: 'Bob', sectionName: 'B',
      presentCount: 0, totalRecordedCount: 0, percentage: null),
];

const _low = [
  HodLowAttendance(
      rollNumber: 'R9', studentName: 'Carol', sectionName: 'A',
      presentCount: 5, totalRecordedCount: 10, percentage: 50.0),
];

const _monthly = [
  HodRollup(
      period: '2026-01', presentCount: 100, totalRecordedCount: 130,
      percentage: 76.92),
  HodRollup(
      period: '2026-02', presentCount: 120, totalRecordedCount: 120,
      percentage: 100.0),
];

const _quarterly = [
  HodRollup(
      period: '2026-Q1', presentCount: 190, totalRecordedCount: 250,
      percentage: 76.0),
];

const _audit = [
  HodAuditLogEntry(
      studentName: 'Alice',
      rollNo: 'R1',
      subjectName: 'Database Systems',
      sectionName: 'A',
      date: '2026-09-04',
      previousStatus: 'ABSENT',
      newStatus: 'PRESENT',
      updatedBy: 'Teacher T',
      updatedAt: '2026-09-05T10:15:00',
      reason: 'Marked by mistake'),
];

_FakeHodRepository _repo({
  HodDashboard dashboard = _dashboard,
  List<HodSectionAttendance> sections = _sections,
  List<HodSubjectAttendance> subjects = _subjects,
  List<HodStudentAttendance> students = _students,
  List<HodLowAttendance> low = _low,
  Future<List<HodRollup>> Function(String type)? rollups,
  List<HodAuditLogEntry> audit = _audit,
}) {
  final repo = _FakeHodRepository();
  repo.onGetDashboard = () async => dashboard;
  repo.onGetSections = (_, __) async => sections;
  repo.onGetSubjects = (_, __) async => subjects;
  repo.onGetStudents = (_, __) async => students;
  repo.onGetLowAttendance = (_, __) async => low;
  repo.onGetRollups = rollups ?? _rollupsByType;
  repo.onGetAuditLogs = (_, __) async => audit;
  return repo;
}

Future<List<HodRollup>> _rollupsByType(String type) async =>
    type == 'monthly' ? _monthly : _quarterly;

SessionController _hodSession() {
  final session = SessionController(AuthRepository());
  session.establishSession('HOD',
      fullName: 'HOD User', email: 'hod@dagacs.local');
  return session;
}

/// A tablet-width surface keeps the navigation in drawer mode, so page titles
/// are not shadowed by identically-labelled sidebar entries.
const Size _surface = Size(1000, 1600);

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.binding.setSurfaceSize(_surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (_) => screen)));
}

Widget _overview(_FakeHodRepository repo, HodAcademicContext ctx) =>
    HodOverviewScreen(
      hodRepository: repo,
      session: _hodSession(),
      academicContext: ctx,
    );

HodAcademicContext _fullContext() => HodAcademicContext()
  ..select(HodContextLevel.academicSession, 1, name: '2026-27')
  ..select(HodContextLevel.program, 10, name: 'B.Tech CSE')
  ..select(HodContextLevel.semester, 100, name: 'Semester 3')
  ..select(HodContextLevel.section, 200, name: 'Section A');

void main() {
  group('HOD Overview route', () {
    testWidgets('shows loading state while fetching', (tester) async {
      final repo = _repo();
      repo.onGetDashboard = () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _dashboard;
      };

      await _pumpScreen(tester, _overview(repo, HodAcademicContext()));
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.pumpAndSettle();
    });

    testWidgets('renders department, KPIs and overall attendance',
        (tester) async {
      await _pumpScreen(tester, _overview(_repo(), HodAcademicContext()));
      await tester.pumpAndSettle();

      expect(find.text('HOD Overview'), findsOneWidget);
      expect(find.text('Computer Engineering'), findsOneWidget);
      expect(find.text('Code: CE'), findsOneWidget);
      expect(find.text('Programs'), findsOneWidget);
      expect(find.text('Batches'), findsOneWidget);
      expect(find.text('Sections'), findsOneWidget);
      expect(find.text('Overall Attendance'), findsOneWidget);
      expect(find.text('400 / 500 recorded'), findsOneWidget);
      expect(find.text('80.00%'), findsWidgets);

      await tester.scrollUntilVisible(
        find.text('Overall attendance'),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('hod-overview-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('400 / 500'), findsOneWidget);
    });

    testWidgets('null overall percentage shows no-data message, never 0%',
        (tester) async {
      final repo = _repo(
        dashboard: const HodDashboard(
          departmentName: 'CE',
          departmentCode: 'CE',
          programCount: 0,
          batchCount: 0,
          sectionCount: 0,
          studentCount: 0,
          totalRecordedCount: 0,
          presentCount: 0,
          overallPercentage: null,
        ),
      );

      await _pumpScreen(tester, _overview(repo, HodAcademicContext()));
      await tester.pumpAndSettle();
      expect(find.text('0.00%'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('No attendance records available'),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('hod-overview-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('No attendance records available'), findsOneWidget);
    });

    testWidgets('shows the below-75% count from the low-attendance feed',
        (tester) async {
      final repo = _repo(
        dashboard: const HodDashboard(
          departmentName: 'Computer Engineering',
          departmentCode: 'CE',
          programCount: 4,
          batchCount: 9,
          sectionCount: 5,
          studentCount: 60,
          totalRecordedCount: 500,
          presentCount: 400,
          overallPercentage: 80.0,
        ),
      );

      await _pumpScreen(tester, _overview(repo, HodAcademicContext()));
      await tester.pumpAndSettle();

      expect(find.text('Below 75%'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('renders metrics with no data source as explicitly '
        'unavailable, never as a fabricated zero', (tester) async {
      await _pumpScreen(tester, _overview(_repo(), HodAcademicContext()));
      await tester.pumpAndSettle();

      expect(find.text('Classes Conducted'), findsOneWidget);
      expect(find.text("Today's Classes"), findsOneWidget);
      expect(find.text('No data source yet'), findsNWidgets(2));
      expect(
          find.byKey(const Key('hod-academic-overview-pending')), findsOneWidget);
    });

    testWidgets('dashboard failure shows an isolated error with retry',
        (tester) async {
      final repo = _repo();
      repo.onGetDashboard = () async => throw const ApiException.serverError();

      await _pumpScreen(tester, _overview(repo, HodAcademicContext()));
      await tester.pumpAndSettle();
      expect(find.text('Failed to load dashboard.'), findsOneWidget);

      repo.onGetDashboard = () async => _dashboard;
      await tester.tap(find.byKey(const Key('retry-button')));
      await tester.pumpAndSettle();
      expect(find.text('Computer Engineering'), findsOneWidget);
      expect(find.text('Failed to load dashboard.'), findsNothing);
    });

    testWidgets('a failing secondary feed does not break the overview',
        (tester) async {
      final repo = _repo();
      repo.onGetLowAttendance = (_, __) async =>
          throw const ApiException.network();

      await _pumpScreen(tester, _overview(repo, HodAcademicContext()));
      await tester.pumpAndSettle();

      expect(find.text('Computer Engineering'), findsOneWidget);
      expect(find.text('Failed to load dashboard.'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('HOD Sections route', () {
    testWidgets('lists sections with null-percentage no-data', (tester) async {
      await _pumpScreen(
        tester,
        HodSectionsScreen(
          hodRepository: _repo(),
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sections'), findsOneWidget);
      expect(find.text('A (CE-A)'), findsOneWidget);
      expect(find.text('B (CE-B)'), findsOneWidget);
      expect(find.text('80.00%'), findsOneWidget);
      expect(find.text('No data'), findsOneWidget);
    });

    testWidgets('empty sections shows empty message', (tester) async {
      await _pumpScreen(
        tester,
        HodSectionsScreen(
          hodRepository: _repo(sections: const []),
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No section data yet.'), findsOneWidget);
    });

    testWidgets('section failure shows an isolated error with retry',
        (tester) async {
      final repo = _repo();
      repo.onGetSections = (_, __) async =>
          throw const ApiException.serverError();

      await _pumpScreen(
        tester,
        HodSectionsScreen(
          hodRepository: repo,
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Failed to load data.'), findsOneWidget);
    });
  });

  group('HOD Subjects route', () {
    testWidgets('lists subjects with present/recorded counts', (tester) async {
      await _pumpScreen(
        tester,
        HodSubjectsScreen(
          hodRepository: _repo(),
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Subjects'), findsOneWidget);
      expect(find.text('Database Systems (DS)'), findsOneWidget);
      expect(find.text('10 present / 12 recorded'), findsOneWidget);
      expect(find.text('83.33%'), findsOneWidget);
    });

    testWidgets('empty subjects shows empty message', (tester) async {
      await _pumpScreen(
        tester,
        HodSubjectsScreen(
          hodRepository: _repo(subjects: const []),
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No subject data yet.'), findsOneWidget);
    });
  });

  group('HOD Students route', () {
    testWidgets('shows per-student rows', (tester) async {
      await _pumpScreen(
        tester,
        HodStudentsScreen(
          hodRepository: _repo(),
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice (R1)'), findsOneWidget);
      expect(find.text('Bob (R2)'), findsOneWidget);
      expect(find.text('80.00%'), findsOneWidget);
      expect(find.text('No data'), findsOneWidget);
    });
  });

  group('HOD Low Attendance route', () {
    testWidgets('shows fixed-threshold note and rows', (tester) async {
      await _pumpScreen(
        tester,
        HodLowAttendanceScreen(
          hodRepository: _repo(),
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.text('Students below the fixed 75.0% attendance threshold.'),
          findsOneWidget);
      expect(find.text('Carol (R9)'), findsOneWidget);
      expect(find.text('50.00%'), findsOneWidget);
    });

    testWidgets('empty state shows OK message', (tester) async {
      await _pumpScreen(
        tester,
        HodLowAttendanceScreen(
          hodRepository: _repo(low: const []),
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No students below the threshold.'), findsOneWidget);
    });

    testWidgets('failure shows an isolated error with retry', (tester) async {
      final repo = _repo();
      repo.onGetLowAttendance = (_, __) async =>
          throw const ApiException.network();

      await _pumpScreen(
        tester,
        HodLowAttendanceScreen(
          hodRepository: repo,
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Failed to load low-attendance students.'),
          findsOneWidget);
    });
  });

  group('HOD Rollups route', () {
    testWidgets('defaults to monthly and never offers semester',
        (tester) async {
      final repo = _repo();

      await _pumpScreen(
        tester,
        HodRollupsScreen(
          hodRepository: repo,
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.lastRollupType, 'monthly');
      expect(find.text('2026-01'), findsOneWidget);
      expect(find.text('2026-02'), findsOneWidget);
      expect(find.text('100.00%'), findsOneWidget);
      // The rollup selector must never offer a semester option. (The shared
      // context bar legitimately contains a "Semester" level label, so the
      // assertion is scoped to the selector itself.)
      expect(
        find.descendant(
          of: find.byKey(const Key('rollup-type-selector')),
          matching: find.textContaining('Semester'),
        ),
        findsNothing,
      );
    });

    testWidgets('switching type to quarterly re-fetches with that type',
        (tester) async {
      final repo = _repo();

      await _pumpScreen(
        tester,
        HodRollupsScreen(
          hodRepository: repo,
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quarterly'));
      await tester.pumpAndSettle();

      expect(repo.lastRollupType, 'quarterly');
      expect(find.text('2026-Q1'), findsOneWidget);
      expect(find.text('76.00%'), findsOneWidget);
    });
  });

  group('HOD Audit Logs route', () {
    testWidgets('renders correction details', (tester) async {
      await _pumpScreen(
        tester,
        HodAuditLogsScreen(
          hodRepository: _repo(),
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice  (R1)'), findsOneWidget);
      expect(find.text('ABSENT \u2192 PRESENT'), findsOneWidget);
      expect(find.textContaining('Reason: Marked by mistake'), findsOneWidget);
    });

    testWidgets('empty audit log shows honest empty message', (tester) async {
      await _pumpScreen(
        tester,
        HodAuditLogsScreen(
          hodRepository: _repo(audit: const []),
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No audit log entries yet.'), findsOneWidget);
    });
  });

  group('HOD Structure route', () {
    testWidgets('states that the hierarchy is not yet available and shows no '
        'invented academic values', (tester) async {
      await _pumpScreen(
        tester,
        HodStructureScreen(
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-structure-pending')), findsOneWidget);
      expect(find.textContaining('Phase 2'), findsWidgets);
      expect(find.textContaining('2026-27'), findsNothing);
    });
  });

  group('shared date filter behaviour', () {
    testWidgets('selecting a start date forwards it to the overview request',
        (tester) async {
      final repo = _repo();

      await _pumpScreen(tester, _overview(repo, HodAcademicContext()));
      await tester.pumpAndSettle();
      expect(repo.lastDashboardStart, isNull);
      expect(repo.lastDashboardEnd, isNull);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await tester.tap(find.byKey(const Key('start-date-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(repo.lastDashboardStart, today);
      expect(repo.lastDashboardEnd, isNull);
    });

    testWidgets('the selected range is shared across HOD routes',
        (tester) async {
      final repo = _repo();
      final context = HodAcademicContext();

      await _pumpScreen(tester, _overview(repo, context));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await tester.tap(find.byKey(const Key('start-date-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(repo.lastDashboardStart, today);

      await tester.pumpWidget(
        MaterialApp(
          home: HodRollupsScreen(
            hodRepository: repo,
            session: _hodSession(),
            academicContext: context,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.lastRollupStart, today);
      expect(repo.lastRollupType, 'monthly');
    });

    testWidgets('clearing dates resets the overview request dates',
        (tester) async {
      final repo = _repo();

      await _pumpScreen(tester, _overview(repo, HodAcademicContext()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start-date-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(repo.lastDashboardStart, isNotNull);

      await tester.tap(find.byKey(const Key('clear-dates-button')));
      await tester.pumpAndSettle();

      expect(repo.lastDashboardStart, isNull);
      expect(repo.lastDashboardEnd, isNull);
    });

    testWidgets(
        'invalid date range (start after end) blocks requests, shows inline '
        'validation, and reset clears it', (tester) async {
      final repo = _repo();
      var dashboardCalls = 0;
      repo.onGetDashboard = () async {
        dashboardCalls++;
        return _dashboard;
      };

      await _pumpScreen(tester, _overview(repo, HodAcademicContext()));
      await tester.pumpAndSettle();
      expect(dashboardCalls, 1);
      expect(find.text('Start date must not be after end date.'), findsNothing);

      await tester.tap(find.byKey(const Key('start-date-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(dashboardCalls, 2);

      await tester.tap(find.byKey(const Key('end-date-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(dashboardCalls, 2);
      expect(find.text('Start date must not be after end date.'), findsOneWidget);
      expect(find.text('Computer Engineering'), findsOneWidget);

      await tester.tap(find.byKey(const Key('clear-dates-button')));
      await tester.pumpAndSettle();

      expect(find.text('Start date must not be after end date.'), findsNothing);
      expect(dashboardCalls, 3);
      expect(repo.lastDashboardStart, isNull);
    });
  });

  group('academic-context aware data views', () {
    testWidgets('the selected academic context is forwarded to every view',
        (tester) async {
      final repo = _repo();
      final context = _fullContext();

      await _pumpScreen(
        tester,
        HodSectionsScreen(
          hodRepository: repo,
          session: _hodSession(),
          academicContext: context,
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.lastSectionsSession, 1);
      expect(repo.lastSectionsProgram, 10);
      expect(repo.lastSectionsSemester, 100);
      expect(repo.lastSectionsSection, 200);

      await _pumpScreen(
        tester,
        HodSubjectsScreen(
          hodRepository: repo,
          session: _hodSession(),
          academicContext: context,
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.lastSubjectsSemester, 100);

      await _pumpScreen(
        tester,
        HodStudentsScreen(
          hodRepository: repo,
          session: _hodSession(),
          academicContext: context,
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.lastStudentsSemester, 100);

      await _pumpScreen(
        tester,
        HodLowAttendanceScreen(
          hodRepository: repo,
          session: _hodSession(),
          academicContext: context,
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.lastLowSemester, 100);
    });

    testWidgets('no context selected means no context parameters are sent',
        (tester) async {
      final repo = _repo();

      await _pumpScreen(
        tester,
        HodSectionsScreen(
          hodRepository: repo,
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.lastSectionsSession, isNull);
      expect(repo.lastSectionsProgram, isNull);
      expect(repo.lastSectionsSemester, isNull);
      expect(repo.lastSectionsSection, isNull);
    });

    testWidgets('changing a parent context resets the dependent levels',
        (tester) async {
      final repo = _repo();
      final context = HodAcademicContext();
      context
        ..select(HodContextLevel.academicSession, 1, name: '2026-27')
        ..select(HodContextLevel.semester, 100, name: 'Semester 3');

      await _pumpScreen(
        tester,
        HodSectionsScreen(
          hodRepository: repo,
          session: _hodSession(),
          academicContext: context,
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.lastSectionsSemester, 100);

      // Switching to a different program must not keep the old semester,
      // section or subject.
      context.select(HodContextLevel.program, 11, name: 'M.Tech CSE');
      expect(context.semesterId, isNull);
      expect(context.sectionId, isNull);
      expect(context.subjectId, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: HodSectionsScreen(
            hodRepository: repo,
            session: _hodSession(),
            academicContext: context,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.lastSectionsSemester, isNull);
      expect(repo.lastSectionsProgram, 11);
    });

    testWidgets('students show their real academic context and enrolment number',
        (tester) async {
      final repo = _repo(
        students: const [
          HodStudentAttendance(
            rollNumber: 'R1',
            enrollmentNumber: 'BTECHCSE001',
            studentName: 'Rahul',
            sectionName: 'A',
            academicSessionName: '2026-27',
            programName: 'B.Tech CSE',
            semesterName: 'Semester 3',
            presentCount: 7,
            totalRecordedCount: 11,
            percentage: 63.64,
          ),
        ],
      );
      final context = HodAcademicContext();
      context.select(HodContextLevel.semester, 100, name: 'Semester 3');

      await _pumpScreen(
        tester,
        HodStudentsScreen(
          hodRepository: repo,
          session: _hodSession(),
          academicContext: context,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('BTECHCSE001'), findsOneWidget);
      expect(find.textContaining('B.Tech CSE'), findsWidgets);
      expect(find.textContaining('Semester 3'), findsWidgets);
      expect(find.text('63.64%'), findsOneWidget);
    });

    testWidgets('a scoped view does not claim to be department-wide',
        (tester) async {
      await _pumpScreen(
        tester,
        HodSectionsScreen(
          hodRepository: _repo(),
          session: _hodSession(),
          academicContext: _fullContext(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-scope-notice')), findsNothing);
    });

    testWidgets('an unscoped view keeps the department-wide notice',
        (tester) async {
      await _pumpScreen(
        tester,
        HodSectionsScreen(
          hodRepository: _repo(),
          session: _hodSession(),
          academicContext: HodAcademicContext(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hod-scope-notice')), findsOneWidget);
    });
  });
}
