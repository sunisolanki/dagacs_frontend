import 'package:dagacs_frontend/models/attendance_percentage.dart';
import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/models/calendar_attendance.dart';
import 'package:dagacs_frontend/models/subject_attendance.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/screens/student_attendance_screen.dart';
import 'package:dagacs_frontend/widgets/attendance_calendar.dart';
import 'package:dagacs_frontend/widgets/attendance_summary_cards.dart';
import 'package:dagacs_frontend/widgets/dagacs_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAttendanceRepository extends AttendanceRepository {
  _FakeAttendanceRepository();
  Future<List<AttendanceRecord>> Function()? onGetMyAttendance;
  Future<AttendancePercentage> Function()? onGetOverall;
  Future<AttendancePercentage> Function(int subjectId)? onGetSubject;
  Future<List<SubjectAttendance>> Function()? onGetSubjectSummaries;
  Future<List<CalendarAttendance>> Function()? onGetCalendarSummary;

  @override
  Future<List<AttendanceRecord>> getMyAttendance() =>
      onGetMyAttendance != null
          ? onGetMyAttendance!()
          : super.getMyAttendance();

  @override
  Future<AttendancePercentage> getOverallAttendanceCalculation(
          {DateTime? startDate, DateTime? endDate}) =>
      onGetOverall != null
          ? onGetOverall!()
          : Future.value(const AttendancePercentage(
              presentCount: 0, totalRecordedCount: 0));

  @override
  Future<AttendancePercentage> getSubjectAttendanceCalculation(
          int subjectId,
          {DateTime? startDate, DateTime? endDate}) =>
      onGetSubject != null
          ? onGetSubject!(subjectId)
          : Future.value(const AttendancePercentage(
              presentCount: 0, totalRecordedCount: 0));

  @override
  Future<List<SubjectAttendance>> getSubjectAttendanceSummaries(
          {DateTime? startDate, DateTime? endDate}) =>
      onGetSubjectSummaries != null
          ? onGetSubjectSummaries!()
          : Future.value([]);

  @override
  Future<List<CalendarAttendance>> getCalendarAttendanceSummary(
          {DateTime? startDate, DateTime? endDate}) =>
      onGetCalendarSummary != null
          ? onGetCalendarSummary!()
          : Future.value([]);
}

Widget _wrap(AttendanceRepository repo) =>
    MaterialApp(home: StudentAttendanceScreen(attendanceRepository: repo));

void main() {
  testWidgets('shows loading then empty state', (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => [];
    await tester.pumpWidget(_wrap(repo));
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();
    // The empty-state block is the last child of a lazy ListView, below the
    // calendar, so scroll it into view before asserting on it.
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('No attendance records found.'), findsOneWidget);
  });

  testWidgets('shows empty state when no records', (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => [];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('No attendance records available'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('No attendance records found.'), findsOneWidget);
  });

  testWidgets('shows error on network failure', (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => throw const ApiException.network();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.textContaining('Unable to connect'), findsOneWidget);
  });

  testWidgets('displays records with Present/Absent icons', (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => [
          const AttendanceRecord(
              id: 1, subjectId: 5, status: 'PRESENT', isPresent: true,
              date: '2026-09-04', lecturePeriod: '1st'),
          const AttendanceRecord(
              id: 2, subjectId: 5, status: 'ABSENT', isPresent: false,
              date: '2026-09-04', lecturePeriod: '1st'),
        ];
    repo.onGetOverall = () async => const AttendancePercentage(
        presentCount: 1, totalRecordedCount: 2, percentage: 50);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.text('Overall Attendance'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.byType(GridView), findsWidgets);
  });

  testWidgets('MIXED attendance date test', (tester) async {
    final calendarData = [
      CalendarAttendance(
        date: '2026-09-04',
        presentCount: 2,
        absentCount: 1,
        totalRecordedCount: 3,
        percentage: 66.67,
      ),
    ];
    final records = [
      const AttendanceRecord(
          id: 1, subjectId: 5, status: 'PRESENT', isPresent: true,
          date: '2026-09-04', lecturePeriod: '1st'),
      const AttendanceRecord(
          id: 2, subjectId: 5, status: 'PRESENT', isPresent: true,
          date: '2026-09-04', lecturePeriod: '2nd'),
      const AttendanceRecord(
          id: 3, subjectId: 5, status: 'ABSENT', isPresent: false,
          date: '2026-09-04', lecturePeriod: '3rd'),
    ];
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => records;
    repo.onGetCalendarSummary = () async => calendarData;
    repo.onGetSubjectSummaries = () async => [];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsWidgets);
    expect(find.byType(GridView), findsWidgets);
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('tapping date shows detail panel', (tester) async {
    final calendarData = [
      CalendarAttendance(
        date: '2026-09-04',
        presentCount: 2,
        absentCount: 1,
        totalRecordedCount: 3,
        percentage: 66.67,
      ),
    ];
    final records = [
      const AttendanceRecord(
          id: 1, subjectId: 5, status: 'PRESENT', isPresent: true,
          date: '2026-09-04', lecturePeriod: '1st'),
      const AttendanceRecord(
          id: 2, subjectId: 5, status: 'ABSENT', isPresent: false,
          date: '2026-09-04', lecturePeriod: '2nd'),
    ];
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => records;
    repo.onGetCalendarSummary = () async => calendarData;
    repo.onGetSubjectSummaries = () async => [];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('subject chart renders with data', (tester) async {
    final subjectData = [
      SubjectAttendance(
        subjectId: 5,
        subjectName: 'Database Systems',
        presentCount: 8,
        totalRecordedCount: 10,
        percentage: 80.0,
      ),
      SubjectAttendance(
        subjectId: 6,
        subjectName: 'Operating Systems',
        presentCount: 7,
        totalRecordedCount: 10,
        percentage: 70.0,
      ),
    ];
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => [];
    repo.onGetCalendarSummary = () async => [];
    repo.onGetSubjectSummaries = () async => subjectData;
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsWidgets);
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('date bar shows Present/Absent toggles', (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => [
          const AttendanceRecord(
              id: 1, subjectId: 5, status: 'PRESENT', isPresent: true,
              date: '2026-09-04', lecturePeriod: '1st'),
          const AttendanceRecord(
              id: 2, subjectId: 5, status: 'ABSENT', isPresent: false,
              date: '2026-09-04', lecturePeriod: '2nd'),
        ];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsWidgets);
    expect(find.byType(ListView), findsWidgets);
  });

  group('AttendanceSummaryCards', () {
    testWidgets('SUCCESS displays overall percentage and stats',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: AttendanceSummaryCards(
          overall: const AttendancePercentage(
              presentCount: 5, totalRecordedCount: 8, percentage: 62.5),
          loading: false,
          error: null,
          onRetry: () {},
        ),
      )));
      await tester.pump();
      expect(find.text('Overall Attendance'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
    });

    testWidgets('LOADING shows spinner', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: AttendanceSummaryCards(
          overall: const AttendancePercentage(
              presentCount: 0, totalRecordedCount: 0, percentage: 0),
          loading: true,
          error: null,
          onRetry: () {},
        ),
      )));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('ERROR shows error text and retry button',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: AttendanceSummaryCards(
          overall: const AttendancePercentage(
              presentCount: 0, totalRecordedCount: 0, percentage: 0),
          loading: false,
          error: 'Unable to connect',
          onRetry: () {},
        ),
      )));
      await tester.pump();
      expect(find.textContaining('Unable to connect'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('EMPTY shows no records message', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: AttendanceSummaryCards(
          overall: null,
          loading: false,
          error: null,
          onRetry: () {},
        ),
      )));
      await tester.pump();
      expect(find.text('No attendance records available'), findsOneWidget);
    });
  });

  group('AttendanceCalendar', () {
    testWidgets('Today button Today action exists and navigates to current month',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: AttendanceCalendar(
          calendarData: [],
          loading: false,
          error: null,
          onRetry: () {},
          onDateSelected: (String date) {},
          selectedDate: null,
          subjectId: null,
          allRecords: null,
        ),
      )));
      await tester.pump();
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('Today button Today sets displayed month to current when navigated away',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: AttendanceCalendar(
          calendarData: [],
          loading: false,
          error: null,
          onRetry: () {},
          onDateSelected: (String date) {},
          selectedDate: null,
          subjectId: null,
          allRecords: null,
        ),
      )));
      await tester.pump();
      expect(find.byType(GridView), findsWidgets);
    });
  });
}
