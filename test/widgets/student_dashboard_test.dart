import 'package:dagacs_frontend/models/attendance_percentage.dart';
import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/models/calendar_attendance.dart';
import 'package:dagacs_frontend/models/subject_attendance.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/widgets/attendance_subject_chart.dart';
import 'package:dagacs_frontend/widgets/attendance_summary_cards.dart';
import 'package:dagacs_frontend/widgets/recent_attendance_list.dart';
import 'package:dagacs_frontend/widgets/student_dashboard.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records served by `getMyAttendance()`. Recent Attendance is built from
/// these, so they must be visually distinguishable from anything the
/// calendar-summary endpoint could contribute.
const _myRecords = [
  AttendanceRecord(
      id: 1,
      subjectId: 5,
      status: 'PRESENT',
      isPresent: true,
      date: '2026-09-21',
      lecturePeriod: '1st'),
  AttendanceRecord(
      id: 2,
      subjectId: 6,
      status: 'ABSENT',
      isPresent: false,
      date: '2026-09-22',
      lecturePeriod: '2nd'),
];

class _FakeAttendanceRepository extends AttendanceRepository {
  int getMyAttendanceCalls = 0;
  int calendarSummaryCalls = 0;
  int overallCalls = 0;
  int subjectSummariesCalls = 0;

  List<AttendanceRecord> records = _myRecords;
  AttendancePercentage? overall;
  List<SubjectAttendance> subjects = const [];

  @override
  Future<List<AttendanceRecord>> getMyAttendance() async {
    getMyAttendanceCalls++;
    return records;
  }

  @override
  Future<AttendancePercentage> getOverallAttendanceCalculation(
      {DateTime? startDate, DateTime? endDate}) async {
    overallCalls++;
    return overall ??
        const AttendancePercentage(
            presentCount: 0, totalRecordedCount: 0);
  }

  @override
  Future<List<SubjectAttendance>> getSubjectAttendanceSummaries(
          {DateTime? startDate, DateTime? endDate}) async =>
      subjects;

  @override
  Future<List<CalendarAttendance>> getCalendarAttendanceSummary(
      {DateTime? startDate, DateTime? endDate}) async {
    calendarSummaryCalls++;
    return const <CalendarAttendance>[];
  }
}

_FakeAttendanceRepository _populatedRepo() {
  return _FakeAttendanceRepository()
    ..overall = const AttendancePercentage(
        presentCount: 8, totalRecordedCount: 10, percentage: 80)
    ..subjects = [
      SubjectAttendance(
          subjectId: 5,
          subjectName: 'Database Systems',
          presentCount: 8,
          totalRecordedCount: 10,
          percentage: 80),
      SubjectAttendance(
          subjectId: 6,
          subjectName: 'Operating Systems',
          presentCount: 7,
          totalRecordedCount: 10,
          percentage: 70),
    ];
}

/// The dashboard stacks a summary card, a chart and the recent list, which
/// overflows the default 800x600 surface. A tall viewport keeps every section
/// laid out so `find` resolves the real content.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _dashboard(AttendanceRepository repo) => MaterialApp(
      home: Scaffold(
        body: StudentDashboard(attendanceRepository: repo),
      ),
    );

/// Wraps the dashboard in a router so the View Full Attendance CTA can be
/// observed landing on the real `/student/attendance` route.
Widget _dashboardWithRoutes(AttendanceRepository repo) => MaterialApp(
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/student/attendance':
            return MaterialPageRoute(
                builder: (_) =>
                    const Scaffold(body: Text('STUDENT-ATTENDANCE-ROUTE')));
          default:
            return MaterialPageRoute(builder: (_) => const SizedBox());
        }
      },
      home: Scaffold(
        body: StudentDashboard(attendanceRepository: repo),
      ),
    );

void main() {
  group('StudentDashboard', () {
    testWidgets('overall attendance renders with counts and percentage',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_dashboard(_populatedRepo()));
      await tester.pumpAndSettle();

      final summary = find.byType(AttendanceSummaryCards);
      expect(summary, findsOneWidget);
      expect(find.text('Overall Attendance'), findsOneWidget);

      expect(
          find.descendant(of: summary, matching: find.text('Present')),
          findsOneWidget);
      expect(
          find.descendant(of: summary, matching: find.text('Absent')),
          findsOneWidget);
      expect(
          find.descendant(of: summary, matching: find.text('Total')),
          findsOneWidget);
      // presentCount / totalRecordedCount
      expect(find.descendant(of: summary, matching: find.text('8')),
          findsOneWidget);
      expect(find.descendant(of: summary, matching: find.text('10')),
          findsOneWidget);

      // The donut percentages are painted by fl_chart rather than emitted as
      // Text widgets, so assert the chart data the user actually sees.
      final pie = tester.widget<PieChart>(find.byType(PieChart));
      final titles = pie.data.sections.map((s) => s.title).toList();
      expect(titles, contains('80%'));
      expect(titles, contains('20%'));
    });

    testWidgets('subject-wise attendance chart renders', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_dashboard(_populatedRepo()));
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceSubjectChart), findsOneWidget);
      expect(find.text('Subject Attendance'), findsOneWidget);
      expect(find.text('Database Systems'), findsOneWidget);
      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.text('8/10'), findsOneWidget);
      expect(find.text('7/10'), findsOneWidget);
    });

    testWidgets('Recent Attendance renders record status per entry',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_dashboard(_populatedRepo()));
      await tester.pumpAndSettle();

      expect(find.byType(RecentAttendanceList), findsOneWidget);
      expect(find.text('Recent Attendance'), findsOneWidget);

      final recent = find.byType(RecentAttendanceList);
      expect(
          find.descendant(of: recent, matching: find.text('Present')),
          findsOneWidget);
      expect(
          find.descendant(of: recent, matching: find.text('Absent')),
          findsOneWidget);
    });

    testWidgets('Recent Attendance is built from getMyAttendance() records, '
        'not the calendar summary', (tester) async {
      _useTallViewport(tester);
      final repo = _populatedRepo();
      await tester.pumpWidget(_dashboard(repo));
      await tester.pumpAndSettle();

      expect(repo.getMyAttendanceCalls, 1,
          reason: 'recent attendance must be sourced from getMyAttendance()');
      expect(repo.calendarSummaryCalls, 0,
          reason: 'the dashboard must not use the calendar summary endpoint');

      // Each getMyAttendance() record surfaces as its own dated row.
      expect(find.text('22 Sep 2026 — Operating Systems'), findsOneWidget);
      expect(find.text('21 Sep 2026 — Database Systems'), findsOneWidget);
    });

    testWidgets('subject names are resolved through subjectNamesById',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_dashboard(_populatedRepo()));
      await tester.pumpAndSettle();

      final recent = find.byType(RecentAttendanceList);
      // Each row renders "<date> — <resolved subject name>", never the raw id.
      expect(
          find.descendant(
              of: recent, matching: find.text('21 Sep 2026 — Database Systems')),
          findsOneWidget);
      expect(
          find.descendant(
              of: recent,
              matching: find.text('22 Sep 2026 — Operating Systems')),
          findsOneWidget);
      expect(
          find.descendant(
              of: recent, matching: find.textContaining('Subject 5')),
          findsNothing);
      expect(
          find.descendant(
              of: recent, matching: find.textContaining('Subject 6')),
          findsNothing);
    });

    testWidgets('View Full Attendance CTA is visible', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_dashboard(_populatedRepo()));
      await tester.pumpAndSettle();

      expect(find.text('View Full Attendance →'), findsOneWidget);
    });

    testWidgets('View Full Attendance CTA navigates to /student/attendance',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_dashboardWithRoutes(_populatedRepo()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Full Attendance →'));
      await tester.pumpAndSettle();

      expect(find.text('STUDENT-ATTENDANCE-ROUTE'), findsOneWidget);
    });

    testWidgets('loading state precedes the dashboard content', (tester) async {
      final repo = _FakeAttendanceRepository();
      await tester.pumpWidget(_dashboard(repo));

      expect(find.byType(AttendanceSummaryCards), findsNothing);
      expect(find.byType(RecentAttendanceList), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(AttendanceSummaryCards), findsOneWidget);
    });
  });
}
