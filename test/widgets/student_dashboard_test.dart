import 'package:dagacs_frontend/models/attendance_percentage.dart';
import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/models/calendar_attendance.dart';
import 'package:dagacs_frontend/models/subject_attendance.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/widgets/attendance_summary_cards.dart';
import 'package:dagacs_frontend/widgets/recent_attendance_list.dart';
import 'package:dagacs_frontend/widgets/student_dashboard.dart';
import 'package:dagacs_frontend/widgets/subject_attendance_bars.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records served by `getMyAttendance()`. Recent Attendance is built from
/// these, so they must be visually distinguishable from anything the
/// calendar-summary endpoint could contribute. Dates are relative to today so
/// the day grouping renders deterministic TODAY / YESTERDAY headers.
String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _day(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: daysAgo));
}

late final List<AttendanceRecord> _myRecords = [
  AttendanceRecord(
      id: 1,
      subjectId: 5,
      status: 'PRESENT',
      isPresent: true,
      date: _iso(_day(1)),
      lecturePeriod: '1st'),
  AttendanceRecord(
      id: 2,
      subjectId: 6,
      status: 'ABSENT',
      isPresent: false,
      date: _iso(_day(0)),
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
      // The compact hero shows the backend percentage and the ratio line.
      expect(find.descendant(of: summary, matching: find.text('80%')),
          findsOneWidget);
      expect(
          find.descendant(
              of: summary, matching: find.text('8 / 10 classes attended')),
          findsOneWidget);
      // No donut is rendered on the dashboard.
      expect(find.descendant(of: summary, matching: find.byType(PieChart)),
          findsNothing);
    });

    testWidgets('subject-wise attendance bars render', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_dashboard(_populatedRepo()));
      await tester.pumpAndSettle();

      expect(find.byType(SubjectAttendanceBars), findsOneWidget);
      expect(find.text('Subject Attendance'), findsOneWidget);

      // Subject names also appear in Recent Attendance, so scope to the bars.
      final bars = find.byType(SubjectAttendanceBars);
      expect(
          find.descendant(of: bars, matching: find.text('Database Systems')),
          findsOneWidget);
      expect(
          find.descendant(of: bars, matching: find.text('Operating Systems')),
          findsOneWidget);
      expect(find.descendant(of: bars, matching: find.text('8/10')),
          findsOneWidget);
      expect(find.descendant(of: bars, matching: find.text('7/10')),
          findsOneWidget);
      expect(find.descendant(of: bars, matching: find.text('80%')),
          findsOneWidget);
      expect(find.descendant(of: bars, matching: find.text('70%')),
          findsOneWidget);
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

      // Each getMyAttendance() record surfaces under its own day group.
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(
          find.descendant(of: find.byType(RecentAttendanceList),
              matching: find.text('Operating Systems')),
          findsOneWidget);
      expect(
          find.descendant(of: find.byType(RecentAttendanceList),
              matching: find.text('Database Systems')),
          findsOneWidget);
    });

    testWidgets('subject names are resolved through subjectNamesById',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_dashboard(_populatedRepo()));
      await tester.pumpAndSettle();

      final recent = find.byType(RecentAttendanceList);
      // Rendered from the name, never the raw subject id.
      expect(
          find.descendant(
              of: recent, matching: find.text('Database Systems')),
          findsOneWidget);
      expect(
          find.descendant(
              of: recent, matching: find.text('Operating Systems')),
          findsOneWidget);
      expect(find.descendant(of: recent, matching: find.text('Subject 5')),
          findsNothing);
      expect(find.descendant(of: recent, matching: find.text('Subject 6')),
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
      final repo = _FakeAttendanceRepository()..records = const [];
      await tester.pumpWidget(_dashboard(repo));

      // Nothing is shown while the requests are in flight.
      expect(find.byType(AttendanceSummaryCards), findsNothing);
      expect(find.byType(RecentAttendanceList), findsNothing);
      expect(find.text('Loading attendance summary...'), findsOneWidget);

      await tester.pumpAndSettle();

      // Resolved: with no recorded data the dashboard shows its empty state.
      expect(find.text('Loading attendance summary...'), findsNothing);
      expect(find.text('No attendance records yet'), findsOneWidget);
    });

    testWidgets('content appears once loading completes', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_dashboard(_populatedRepo()));
      expect(find.text('Loading attendance summary...'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Loading attendance summary...'), findsNothing);
      expect(find.byType(AttendanceSummaryCards), findsOneWidget);
      expect(find.text('80%'), findsWidgets);
    });
  });
}
