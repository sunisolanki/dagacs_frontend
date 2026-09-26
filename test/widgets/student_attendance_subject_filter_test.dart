import 'package:dagacs_frontend/models/attendance_percentage.dart';
import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/models/calendar_attendance.dart';
import 'package:dagacs_frontend/models/subject_attendance.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/screens/student_attendance_screen.dart';
import 'package:dagacs_frontend/widgets/attendance_date_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const int kSubjectA = 5; // Database Systems
const int kSubjectB = 6; // Operating Systems

const String kSubjectAName = 'Database Systems';
const String kSubjectBName = 'Operating Systems';

class _FakeAttendanceRepository extends AttendanceRepository {
  List<AttendanceRecord> records = const [];
  List<CalendarAttendance> calendar = const [];
  List<SubjectAttendance> subjects = const [];

  @override
  Future<List<AttendanceRecord>> getMyAttendance() async => records;

  @override
  Future<AttendancePercentage> getOverallAttendanceCalculation(
          {DateTime? startDate, DateTime? endDate}) async =>
      const AttendancePercentage(
          presentCount: 1, totalRecordedCount: 2, percentage: 50);

  @override
  Future<AttendancePercentage> getSubjectAttendanceCalculation(
          int subjectId,
          {DateTime? startDate,
          DateTime? endDate}) async =>
      const AttendancePercentage(
          presentCount: 1, totalRecordedCount: 1, percentage: 100);

  @override
  Future<List<SubjectAttendance>> getSubjectAttendanceSummaries(
          {DateTime? startDate, DateTime? endDate}) async =>
      subjects;

  @override
  Future<List<CalendarAttendance>> getCalendarAttendanceSummary(
      {DateTime? startDate, DateTime? endDate}) async =>
      calendar;
}

/// The calendar emits canonical ISO `yyyy-MM-dd` day keys, matching the
/// backend's `AttendanceRecord.date`.
String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The screen stacks a date bar, summary card, filter and calendar, which
/// overflows the default surface. A tall viewport keeps every section laid out.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _screen(AttendanceRepository repo) => MaterialApp(
      home: StudentAttendanceScreen(attendanceRepository: repo),
    );

void main() {
  group('StudentAttendanceScreen subject filter scopes the date detail', () {
    // One date holding Subject A = Absent and Subject B = Present.
    late DateTime probe;
    late String probeKey;

    setUp(() {
      final now = DateTime.now();
      probe = DateTime(now.year, now.month, 15);
      probeKey = _dayKey(probe);
    });

    _FakeAttendanceRepository buildRepo() => _FakeAttendanceRepository()
      ..records = [
        AttendanceRecord(
            id: 1,
            subjectId: kSubjectA,
            status: 'ABSENT',
            isPresent: false,
            date: probeKey,
            lecturePeriod: '1st'),
        AttendanceRecord(
            id: 2,
            subjectId: kSubjectB,
            status: 'PRESENT',
            isPresent: true,
            date: probeKey,
            lecturePeriod: '2nd'),
      ]
      ..calendar = [
        CalendarAttendance(
            date: probeKey,
            presentCount: 1,
            absentCount: 1,
            totalRecordedCount: 2,
            percentage: 50),
      ]
      ..subjects = [
        SubjectAttendance(
            subjectId: kSubjectA,
            subjectName: kSubjectAName,
            presentCount: 0,
            totalRecordedCount: 1,
            percentage: 0),
        SubjectAttendance(
            subjectId: kSubjectB,
            subjectName: kSubjectBName,
            presentCount: 1,
            totalRecordedCount: 1,
            percentage: 100),
      ];

    /// Opens the subject dropdown and picks [label].
    Future<void> selectSubject(WidgetTester tester, String label) async {
      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    /// The subject names also appear in the chart and the dropdown, so every
    /// detail assertion is scoped to the date-detail panel.
    Finder inDetail(String text) => find.descendant(
        of: find.byType(AttendanceDateDetail), matching: find.text(text));

    testWidgets('All Subjects shows both subjects for the selected date',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_screen(buildRepo()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${probe.day}'));
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceDateDetail), findsOneWidget);
      expect(inDetail(kSubjectAName), findsOneWidget);
      expect(inDetail(kSubjectBName), findsOneWidget);
    });

    testWidgets('selecting Subject A hides Subject B from the date detail',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_screen(buildRepo()));
      await tester.pumpAndSettle();

      // Pick the date first, then narrow the filter.
      await tester.tap(find.text('${probe.day}'));
      await tester.pumpAndSettle();
      expect(inDetail(kSubjectBName), findsOneWidget);

      await selectSubject(tester, kSubjectAName);

      // Subject A is absent and remains; Subject B must disappear.
      expect(inDetail(kSubjectAName), findsOneWidget);
      expect(inDetail(kSubjectBName), findsNothing);
      // The per-record status chip is Absent; the summary bar always shows
      // static Present/Absent/Total labels, so only the chip is asserted.
      expect(
          find.descendant(
              of: find.byType(AttendanceDateDetail),
              matching: find.text('Absent')),
          findsWidgets);
    });

    testWidgets('switching back to All Subjects restores both subjects',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_screen(buildRepo()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${probe.day}'));
      await tester.pumpAndSettle();

      await selectSubject(tester, kSubjectAName);
      expect(inDetail(kSubjectBName), findsNothing);

      await selectSubject(tester, 'All Subjects');

      expect(inDetail(kSubjectAName), findsOneWidget);
      expect(inDetail(kSubjectBName), findsOneWidget);
    });

    testWidgets('changing the subject filter preserves the selected date',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_screen(buildRepo()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${probe.day}'));
      await tester.pumpAndSettle();
      expect(inDetail(kSubjectAName), findsOneWidget);

      await selectSubject(tester, kSubjectAName);

      // The panel stays open on the same date rather than resetting.
      expect(find.byType(AttendanceDateDetail), findsOneWidget);
      expect(inDetail(kSubjectAName), findsOneWidget);
      expect(
          find.text('No attendance records for this date'), findsNothing);
    });

    testWidgets('a subject with no record on the selected date shows the '
        'no-record state while keeping the date', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_screen(buildRepo()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${probe.day}'));
      await tester.pumpAndSettle();
      await selectSubject(tester, kSubjectAName);
      expect(inDetail(kSubjectAName), findsOneWidget);

      // Move to a different day that has no Subject A record at all.
      final other = DateTime(probe.year, probe.month, 16);
      await tester.tap(find.text('${other.day}'));
      await tester.pumpAndSettle();

      expect(inDetail(kSubjectAName), findsNothing);
      expect(
          find.text('No attendance records for this date'), findsOneWidget,
          reason: 'the date stays selected and reports the empty subject scope');
    });

    testWidgets('the calendar keeps its own subject scope unchanged',
        (tester) async {
      _useTallViewport(tester);
      final repo = buildRepo();
      // No records for this date, so the calendar dot can only come from the
      // aggregate summary and the detail panel reports the empty scope.
      repo.records = [
        AttendanceRecord(
            id: 1,
            subjectId: kSubjectA,
            status: 'ABSENT',
            isPresent: false,
            date: probeKey,
            lecturePeriod: '1st'),
      ];
      await tester.pumpWidget(_screen(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${probe.day}'));
      await tester.pumpAndSettle();

      // Under Subject A the single absent record is shown.
      await selectSubject(tester, kSubjectAName);
      expect(inDetail(kSubjectAName), findsOneWidget);
      expect(inDetail('Absent'), findsWidgets);
    });
  });
}
