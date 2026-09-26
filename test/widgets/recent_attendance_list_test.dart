import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/widgets/recent_attendance_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _names = {5: 'Database Systems', 6: 'Operating Systems'};

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
      await tester.pumpWidget(_wrap(const [
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
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Recent Attendance'), findsOneWidget);
      expect(find.text('21 Sep 2026 — Database Systems'), findsOneWidget);
      expect(find.text('22 Sep 2026 — Operating Systems'), findsOneWidget);
    });

    testWidgets('shows Present status for a present record', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_wrap(const [
        AttendanceRecord(
            id: 1,
            subjectId: 5,
            status: 'PRESENT',
            isPresent: true,
            date: '2026-09-21',
            lecturePeriod: '1st'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Absent'), findsNothing);
    });

    testWidgets('shows Absent status for an absent record', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_wrap(const [
        AttendanceRecord(
            id: 2,
            subjectId: 6,
            status: 'ABSENT',
            isPresent: false,
            date: '2026-09-22',
            lecturePeriod: '2nd'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('Present'), findsNothing);
    });

    testWidgets('isPresent flag drives status even when status text differs',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_wrap(const [
        AttendanceRecord(
            id: 3,
            subjectId: 5,
            status: 'UNMARKED',
            isPresent: true,
            date: '2026-09-23',
            lecturePeriod: '3rd'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Present'), findsOneWidget);
    });

    testWidgets('orders newest first and caps the list at ten rows',
        (tester) async {
      _useTallViewport(tester);
      final records = [
        for (var i = 1; i <= 12; i++)
          AttendanceRecord(
              id: i,
              subjectId: 5,
              status: 'PRESENT',
              isPresent: true,
              date: '2026-09-${i.toString().padLeft(2, '0')}',
              lecturePeriod: '$i'),
      ];
      await tester.pumpWidget(_wrap(records));
      await tester.pumpAndSettle();

      // Newest (12th) first, oldest 10th day dropped by the take(10) cap.
      expect(find.textContaining('12 Sep 2026'), findsOneWidget);
      expect(find.textContaining('03 Sep 2026'), findsOneWidget);
      expect(find.textContaining('02 Sep 2026'), findsNothing);
      expect(find.text('Present'), findsNWidgets(10));
    });

    testWidgets('empty records show the empty state', (tester) async {
      await tester.pumpWidget(_wrap(const []));
      await tester.pumpAndSettle();

      expect(find.text('No recent attendance records'), findsOneWidget);
      expect(find.text('Recent Attendance'), findsNothing);
    });

    testWidgets('falls back to the subject id label without crashing',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_wrap(const [
        AttendanceRecord(
            id: 9,
            subjectId: 77,
            status: 'PRESENT',
            isPresent: true,
            date: '2026-09-21',
            lecturePeriod: '1st'),
      ]));
      await tester.pumpAndSettle();

      // 77 is absent from the name map, so the id-based label is used.
      expect(find.text('21 Sep 2026 — Subject 77'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a null subject id without crashing', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_wrap(const [
        AttendanceRecord(
            id: 10,
            status: 'ABSENT',
            isPresent: false,
            date: '2026-09-21',
            lecturePeriod: '1st'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('21 Sep 2026 — Subject -'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a missing date without crashing', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_wrap(const [
        AttendanceRecord(
            id: 11,
            subjectId: 5,
            status: 'PRESENT',
            isPresent: true,
            lecturePeriod: '1st'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('- — Database Systems'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
