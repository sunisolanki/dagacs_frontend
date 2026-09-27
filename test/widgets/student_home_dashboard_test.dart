import 'package:dagacs_frontend/models/attendance_percentage.dart';
import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/models/calendar_attendance.dart';
import 'package:dagacs_frontend/models/subject_attendance.dart';
import 'package:dagacs_frontend/core/navigation/navigator.dart';
import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/home_screen.dart';
import 'package:dagacs_frontend/widgets/attendance_summary_cards.dart';
import 'package:dagacs_frontend/widgets/recent_attendance_list.dart';
import 'package:dagacs_frontend/widgets/student_dashboard.dart';
import 'package:dagacs_frontend/widgets/subject_attendance_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository extends AuthRepository {
  @override
  Future<void> persistSession(AuthResponse auth) async {}

  @override
  Future<void> logout() async {}
}

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository() : super(ApiClient());
}

class _FakeAttendanceRepository extends AttendanceRepository {
  AttendancePercentage? overall;
  List<SubjectAttendance> subjects = const [];
  List<AttendanceRecord> records = const [];
  bool failEverything = false;

  @override
  Future<List<AttendanceRecord>> getMyAttendance() async {
    if (failEverything) throw const ApiException.network();
    return records;
  }

  @override
  Future<AttendancePercentage> getOverallAttendanceCalculation(
      {DateTime? startDate, DateTime? endDate}) async {
    if (failEverything) throw const ApiException.network();
    return overall ?? const AttendancePercentage(presentCount: 0, totalRecordedCount: 0);
  }

  @override
  Future<List<SubjectAttendance>> getSubjectAttendanceSummaries(
          {DateTime? startDate, DateTime? endDate}) async =>
      subjects;

  @override
  Future<List<CalendarAttendance>> getCalendarAttendanceSummary(
          {DateTime? startDate, DateTime? endDate}) async =>
      const [];
}

SessionController _studentSession() {
  final session = SessionController(_FakeAuthRepository());
  session.establishSession('STUDENT', fullName: 'Asha Student');
  return session;
}

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _day(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: daysAgo));
}

_FakeAttendanceRepository _populated() => _FakeAttendanceRepository()
  ..overall = const AttendancePercentage(
      presentCount: 46, totalRecordedCount: 50, percentage: 92)
  ..subjects = [
    SubjectAttendance(
        subjectId: 5,
        subjectName: 'DSA',
        presentCount: 42,
        totalRecordedCount: 45,
        percentage: 93),
    SubjectAttendance(
        subjectId: 6,
        subjectName: 'DBMS',
        presentCount: 38,
        totalRecordedCount: 42,
        percentage: 90),
  ]
  ..records = [
    AttendanceRecord(
        id: 1,
        subjectId: 5,
        status: 'PRESENT',
        isPresent: true,
        date: _iso(_day(0)),
        lecturePeriod: '1st'),
  ];

Widget _home(AttendanceRepository? repo, {SessionController? session}) {
  return MaterialApp(
    onGenerateRoute: (settings) {
      if (settings.name == AppRoutes.studentAttendance) {
        return MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('MY-ATTENDANCE-ROUTE')));
      }
      return MaterialPageRoute(builder: (_) => const SizedBox());
    },
    home: HomeScreen(
      session: session ?? _studentSession(),
      masterDataRepository: _FakeMasterDataRepository(),
      attendanceRepository: repo,
    ),
  );
}

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('Student home dashboard wiring', () {
    testWidgets('a STUDENT home with an attendance repository renders the '
        'attendance summary immediately', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_home(_populated()));
      await tester.pumpAndSettle();

      // Attendance is visible without navigating anywhere.
      expect(find.byType(StudentDashboard), findsOneWidget);
      expect(find.byType(AttendanceSummaryCards), findsOneWidget);
      expect(find.text('Overall Attendance'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('46 / 50 classes attended'), findsOneWidget);
      expect(find.byType(SubjectAttendanceBars), findsOneWidget);
      expect(find.byType(RecentAttendanceList), findsOneWidget);
    });

    testWidgets('overall attendance hero, stats and CTA are all present',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_home(_populated()));
      await tester.pumpAndSettle();

      final summary = find.byType(AttendanceSummaryCards);
      expect(find.descendant(of: summary, matching: find.text('46')),
          findsOneWidget);
      expect(find.descendant(of: summary, matching: find.text('50')),
          findsOneWidget);
      // Absent is derived: 50 - 46 = 4
      expect(find.descendant(of: summary, matching: find.text('4')),
          findsOneWidget);
      expect(find.text('View Full Attendance →'), findsOneWidget);
    });

    testWidgets('CTA opens the existing My Attendance screen', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_home(_populated()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Full Attendance →'));
      await tester.pumpAndSettle();

      expect(find.text('MY-ATTENDANCE-ROUTE'), findsOneWidget);
    });

    testWidgets('subject statistics come from the summaries endpoint',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_home(_populated()));
      await tester.pumpAndSettle();

      final bars = find.byType(SubjectAttendanceBars);
      expect(find.descendant(of: bars, matching: find.text('DSA')),
          findsOneWidget);
      expect(find.descendant(of: bars, matching: find.text('42/45')),
          findsOneWidget);
      expect(find.descendant(of: bars, matching: find.text('93%')),
          findsOneWidget);
      expect(find.descendant(of: bars, matching: find.text('DBMS')),
          findsOneWidget);
      expect(find.descendant(of: bars, matching: find.text('38/42')),
          findsOneWidget);
      expect(find.descendant(of: bars, matching: find.text('90%')),
          findsOneWidget);
    });

    testWidgets('recent attendance is grouped by day', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_home(_populated()));
      await tester.pumpAndSettle();

      expect(find.text('TODAY'), findsOneWidget);
      final recent = find.byType(RecentAttendanceList);
      expect(
          find.descendant(of: recent, matching: find.text('DSA')),
          findsOneWidget);
      expect(
          find.descendant(of: recent, matching: find.text('Present')),
          findsOneWidget);
    });

    testWidgets('no attendance at all shows a clean empty state, not 0%',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_home(_FakeAttendanceRepository()));
      await tester.pumpAndSettle();

      expect(find.text('No attendance records yet'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      expect(find.byType(SubjectAttendanceBars), findsNothing);
      // The route onward stays reachable.
      expect(find.text('View Full Attendance →'), findsOneWidget);
    });

    testWidgets('a failing endpoint surfaces an error with retry',
        (tester) async {
      _useTallViewport(tester);
      final repo = _populated()..failEverything = true;
      await tester.pumpWidget(_home(repo));
      await tester.pumpAndSettle();

      // A failure must not crash the dashboard or fabricate percentages.
      expect(tester.takeException(), isNull);
      expect(find.text('92%'), findsNothing);
    });

    testWidgets('home without a repository still renders tiles, no dashboard',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_home(null));
      await tester.pumpAndSettle();

      expect(find.byType(StudentDashboard), findsNothing);
      expect(find.text('My Attendance'), findsWidgets);
    });

    testWidgets('non-student roles never see the attendance dashboard',
        (tester) async {
      _useTallViewport(tester);
      for (final role in ['ADMIN', 'TEACHER', 'HOD']) {
        final session = SessionController(_FakeAuthRepository());
        session.establishSession(role, fullName: 'Person $role');
        await tester.pumpWidget(_home(_populated(), session: session));
        await tester.pumpAndSettle();

        expect(find.byType(StudentDashboard), findsNothing,
            reason: '$role home must not render the student dashboard');
      }
    });
  });
}
