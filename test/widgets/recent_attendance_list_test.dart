import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/widgets/recent_attendance_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _names = {5: 'Database Systems', 6: 'Operating Systems'};

/// Calendar key in the same zero-padded ISO form the API returns.
String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `daysAgo` days before today at midnight, so day labels are stable.
DateTime _day(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: daysAgo));
}

Widget _wrap(List<AttendanceRecord> records, {Map<int, String>? names}) =>
    MaterialApp(
      home: Scaffold(
        body: RecentAttendanceList(
          records: records,
          subjectNamesById: names ?? _names,
        ),
      ),
    );

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('RecentAttendanceList', () {
    testWidgets('renders one row per record with resolved subject name',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_wrap([
        AttendanceRecord(
            id: 1,
            subjectId: 5,
            status: 'PRESENT',
            isPresent: true,
            date: _iso(_day(0)),
            lecturePeriod: '1st'),
        AttendanceRecord(
            id: 2,
            subjectId: 6,
            status: 'ABSENT',
            isPresent: false,
            date: _iso(_day(0)),
            lecturePeriod: '2nd'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Recent Attendance'), findsOneWidget);
      // One row per record, each labelled with the resolved subject name.
      expect(find.text('Database Systems'), findsOneWidget);
      expect(find.text('Operating Systems'), findsOneWidget);
    });

    testWidgets('shows Present status for a present record', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_wrap([
        AttendanceRecord(
            id: 1,
            subjectId: 5,
            status: 'PRESENT',
            isPresent: true,
            date: _iso(_day(0)),
            lecturePeriod: '1st'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Absent'), findsNothing);
    });

    testWidgets('shows Absent status for an absent record', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_wrap([
        AttendanceRecord(
            id: 2,
            subjectId: 6,
            status: 'ABSENT',
            isPresent: false,
            date: _iso(_day(0)),
            lecturePeriod: '2nd'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('Present'), findsNothing);
    });

    testWidgets('isPresent flag drives status even when status text differs',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_wrap([
        AttendanceRecord(
            id: 3,
            subjectId: 5,
            status: 'UNMARKED',
            isPresent: true,
            date: _iso(_day(0)),
            lecturePeriod: '3rd'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Present'), findsOneWidget);
    });

    testWidgets('groups newest first, labels Today/Yesterday and caps the '
        'day groups', (tester) async {
      _useTallViewport(tester);
      // Seven distinct days; the widget keeps at most five day groups.
      final records = [
        for (var i = 0; i < 7; i++)
          AttendanceRecord(
              id: i,
              subjectId: 5,
              status: 'PRESENT',
              isPresent: true,
              date: _iso(_day(i)),
              lecturePeriod: '$i'),
      ];
      await tester.pumpWidget(_wrap(records));
      await tester.pumpAndSettle();

      // Relative day labels.
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);

      // Newest first, and the oldest two groups are dropped by the cap.
      final fourth = _day(4);
      final fifth = _day(5);
      String header(DateTime d) =>
          '${d.day} ${const [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
          ][d.month - 1]} ${d.year}'
              .toUpperCase();

      expect(find.text(header(fourth)), findsOneWidget);
      expect(find.text(header(fifth)), findsNothing);

      // Five kept groups, one row each.
      expect(find.text('Present'), findsNWidgets(5));
    });

    testWidgets('empty records show the empty state', (tester) async {
      await tester.pumpWidget(_wrap(const []));
      await tester.pumpAndSettle();

      expect(find.text('No recent attendance records'), findsOneWidget);
      expect(find.text('Present'), findsNothing);
      expect(find.text('Absent'), findsNothing);
    });

    testWidgets('falls back to the subject id label without crashing',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_wrap([
        AttendanceRecord(
            id: 9,
            subjectId: 77,
            status: 'PRESENT',
            isPresent: true,
            date: _iso(_day(0)),
            lecturePeriod: '1st'),
      ]));
      await tester.pumpAndSettle();

      // 77 is absent from the name map, so the id-based label is used.
      expect(find.text('Subject 77'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a null subject id without crashing', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_wrap([
        AttendanceRecord(
            id: 10,
            status: 'ABSENT',
            isPresent: false,
            date: _iso(_day(0)),
            lecturePeriod: '1st'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Subject -'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a missing date without crashing', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_wrap([
        AttendanceRecord(
            id: 11,
            subjectId: 5,
            status: 'PRESENT',
            isPresent: true,
            lecturePeriod: '1st'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Database Systems'), findsOneWidget);
      expect(find.text('UNKNOWN DATE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
