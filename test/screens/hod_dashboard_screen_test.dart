import 'package:dagacs_frontend/models/hod_audit_log_entry.dart';
import 'package:dagacs_frontend/models/hod_dashboard.dart';
import 'package:dagacs_frontend/models/hod_low_attendance.dart';
import 'package:dagacs_frontend/models/hod_rollup.dart';
import 'package:dagacs_frontend/models/hod_section_attendance.dart';
import 'package:dagacs_frontend/models/hod_student_attendance.dart';
import 'package:dagacs_frontend/models/hod_subject_attendance.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/hod_repository.dart';
import 'package:dagacs_frontend/screens/hod_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHodRepository extends HodRepository {
  _FakeHodRepository();

  Future<HodDashboard> Function()? onGetDashboard;
  Future<List<HodSectionAttendance>> Function(DateTime?, DateTime?)? onGetSections;
  Future<List<HodSubjectAttendance>> Function(DateTime?, DateTime?)? onGetSubjects;
  Future<List<HodStudentAttendance>> Function(DateTime?, DateTime?)? onGetStudents;
  Future<List<HodLowAttendance>> Function(DateTime?, DateTime?)? onGetLowAttendance;
  Future<List<HodRollup>> Function(String type)? onGetRollups;
  Future<List<HodAuditLogEntry>> Function(DateTime?, DateTime?)? onGetAuditLogs;

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

  @override
  Future<HodDashboard> getDashboard(
      {DateTime? startDate, DateTime? endDate}) {
    lastDashboardStart = startDate;
    lastDashboardEnd = endDate;
    return onGetDashboard!();
  }

  @override
  Future<List<HodSectionAttendance>> getSections(
      {DateTime? startDate, DateTime? endDate}) {
    lastSectionsStart = startDate;
    lastSectionsEnd = endDate;
    return onGetSections!(startDate, endDate);
  }

  @override
  Future<List<HodSubjectAttendance>> getSubjects(
      {DateTime? startDate, DateTime? endDate}) {
    lastSubjectsStart = startDate;
    lastSubjectsEnd = endDate;
    return onGetSubjects!(startDate, endDate);
  }

  @override
  Future<List<HodStudentAttendance>> getStudents(
      {DateTime? startDate, DateTime? endDate}) {
    lastStudentsStart = startDate;
    lastStudentsEnd = endDate;
    return onGetStudents!(startDate, endDate);
  }

  @override
  Future<List<HodLowAttendance>> getLowAttendance(
      {DateTime? startDate, DateTime? endDate}) {
    lastLowStart = startDate;
    lastLowEnd = endDate;
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

Widget _wrap(_FakeHodRepository repo) =>
    MaterialApp(home: HodDashboardScreen(hodRepository: repo));

void main() {
  testWidgets('shows loading state while fetching', (tester) async {
    final repo = _repo();
    repo.onGetDashboard = () async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _dashboard;
    };

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('dashboard tab renders department and overall attendance',
      (tester) async {
    final repo = _repo();

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('HOD Dashboard'), findsOneWidget);
    expect(find.text('Computer Engineering'), findsOneWidget);
    expect(find.text('Code: CE'), findsOneWidget);
    expect(find.text('400 / 500'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('Programs'), findsOneWidget);
    expect(find.text('Batches'), findsOneWidget);
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

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('0%'), findsNothing);
    expect(find.text('No attendance records available'), findsOneWidget);
  });

  testWidgets('sections tab lists sections with null-percentage no-data',
      (tester) async {
    final repo = _repo();

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-sections')));
    await tester.pumpAndSettle();

    expect(find.text('A (CE-A)'), findsOneWidget);
    expect(find.text('B (CE-B)'), findsOneWidget);
    expect(find.text('80%'), findsNWidgets(1));
    expect(find.text('No data'), findsNWidgets(1));
  });

  testWidgets('students tab shows per-student rows', (tester) async {
    final repo = _repo();

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-students')));
    await tester.pumpAndSettle();

    expect(find.text('Alice (R1)'), findsOneWidget);
    expect(find.text('Bob (R2)'), findsOneWidget);
    expect(find.text('80%'), findsNWidgets(1));
    expect(find.text('No data'), findsNWidgets(1));
  });

  testWidgets('low attendance tab shows fixed-threshold note and rows',
      (tester) async {
    final repo = _repo();

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Low Attendance'));
    await tester.pumpAndSettle();

    expect(
        find.text('Students below the fixed 75.0% attendance threshold.'),
        findsOneWidget);
    expect(find.text('Carol (R9)'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('low attendance empty state shows OK message', (tester) async {
    final repo = _repo(low: const []);

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Low Attendance'));
    await tester.pumpAndSettle();

    expect(find.text('No students below the threshold.'), findsOneWidget);
  });

  testWidgets('rollups tab defaults to monthly and never offers semester',
      (tester) async {
    final repo = _repo();

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rollups'));
    await tester.pumpAndSettle();

    expect(repo.lastRollupType, 'monthly');
    expect(find.text('2026-01'), findsOneWidget);
    expect(find.text('2026-02'), findsOneWidget);
    expect(find.text('100.0%'), findsNothing);
    expect(find.text('100%'), findsOneWidget);
    expect(find.textContaining('Semester'), findsNothing);
    expect(find.textContaining('semester'), findsNothing);
  });

  testWidgets('switching rollup type to quarterly re-fetches with that type',
      (tester) async {
    final repo = _repo();

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rollups'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quarterly'));
    await tester.pumpAndSettle();

    expect(repo.lastRollupType, 'quarterly');
    expect(find.text('2026-Q1'), findsOneWidget);
    expect(find.text('76%'), findsOneWidget);
  });

  testWidgets('audit logs tab renders correction details', (tester) async {
    final repo = _repo();

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Audit Logs'));
    await tester.pumpAndSettle();

    expect(find.text('Alice  (R1)'), findsOneWidget);
    expect(find.text('ABSENT \u2192 PRESENT'), findsOneWidget);
    expect(find.textContaining('Reason: Marked by mistake'), findsOneWidget);
  });

  testWidgets('selecting a start date forwards dates to dashboard and rollups',
      (tester) async {
    final repo = _repo();

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(repo.lastDashboardStart, isNull);
    expect(repo.lastDashboardEnd, isNull);

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    await tester.tap(find.byKey(const Key('start-date-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(repo.lastDashboardStart, todayDate);
    expect(repo.lastDashboardEnd, isNull);
    expect(repo.lastRollupStart, todayDate);
    expect(repo.lastRollupType, 'monthly');
    // Still on the dashboard tab after a date change.
    expect(find.text('Computer Engineering'), findsOneWidget);
  });

  testWidgets('clearing dates resets the dashboard request dates',
      (tester) async {
    final repo = _repo();

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
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
    expect(repo.lastRollupStart, isNull);
  });

  testWidgets('dashboard failure shows an isolated error with retry',
      (tester) async {
    final repo = _repo();
    repo.onGetDashboard = () async => throw const ApiException.serverError();

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Failed to load dashboard.'), findsOneWidget);

    repo.onGetDashboard = () async => _dashboard;
    await tester.tap(find.byKey(const Key('retry-button')));
    await tester.pumpAndSettle();

    expect(find.text('Computer Engineering'), findsOneWidget);
    expect(find.text('Failed to load dashboard.'), findsNothing);
  });

  testWidgets('one failed list endpoint does not break other tabs',
      (tester) async {
    final repo = _repo();
    repo.onGetLowAttendance = (_, __) async => throw const ApiException.network();

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Dashboard unaffected.
    expect(find.text('Computer Engineering'), findsOneWidget);

    await tester.tap(find.text('Low Attendance'));
    await tester.pumpAndSettle();

    expect(
        find.text('Failed to load low-attendance students.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('empty sections tab shows empty message', (tester) async {
    final repo = _repo(sections: const []);

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-sections')));
    await tester.pumpAndSettle();

    expect(find.text('No section data yet.'), findsOneWidget);
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

    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(dashboardCalls, 1);
    expect(find.text('Start date must not be after end date.'), findsNothing);

    // Start = today (date picker OK default).
    await tester.tap(find.byKey(const Key('start-date-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(dashboardCalls, 2);

    // End = 15th of the previous month -> start (today) is strictly after end.
    await tester.tap(find.byKey(const Key('end-date-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // No dashboard API request was issued for the invalid range.
    expect(dashboardCalls, 2);
    expect(find.text('Start date must not be after end date.'), findsOneWidget);
    // Previously loaded data is preserved.
    expect(find.text('Computer Engineering'), findsOneWidget);

    // Clearing the dates restores normal fetches and removes the hint.
    await tester.tap(find.byKey(const Key('clear-dates-button')));
    await tester.pumpAndSettle();

    expect(find.text('Start date must not be after end date.'), findsNothing);
    expect(dashboardCalls, 3);
    expect(repo.lastDashboardStart, isNull);
    expect(repo.lastRollupStart, isNull);
  });
}