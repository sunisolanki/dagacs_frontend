import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/models/calendar_attendance.dart';
import 'package:dagacs_frontend/widgets/attendance_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The calendar emits canonical ISO `yyyy-MM-dd` day keys (zero-padded month
/// and day), matching the backend's `AttendanceRecord.date`.
String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The month caption rendered by the navigation row.
String _monthLabel(DateTime d) =>
    '${d.year} ${d.month.toString().padLeft(2, '0')}';

CalendarAttendance _summary(String date, int present, int absent) {
  final total = present + absent;
  return CalendarAttendance(
    date: date,
    presentCount: present,
    absentCount: absent,
    totalRecordedCount: total,
    percentage: total == 0 ? null : (present / total) * 100,
  );
}

Widget _calendar({
  required List<CalendarAttendance> data,
  ValueChanged<String>? onDateSelected,
  String? selectedDate,
  int? subjectId,
  List<AttendanceRecord>? allRecords,
}) =>
    MaterialApp(
      home: Scaffold(
        body: AttendanceCalendar(
          calendarData: data,
          loading: false,
          error: null,
          onRetry: () {},
          onDateSelected: onDateSelected ?? (String _) {},
          selectedDate: selectedDate,
          subjectId: subjectId,
          allRecords: allRecords,
        ),
      ),
    );

/// Reads the colour of the indicator dot rendered inside a day's cell.
Color _dotColorForDay(WidgetTester tester, String dayNumber) {
  final cell = find
      .ancestor(of: find.text(dayNumber), matching: find.byType(GestureDetector))
      .first;
  expect(cell, findsWidgets,
      reason: 'expected a day cell for "$dayNumber"');

  for (final container in tester.widgetList<Container>(
      find.descendant(of: cell, matching: find.byType(Container)))) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.shape == BoxShape.circle) {
      final color = decoration.color;
      expect(color, isNotNull);
      return color!;
    }
  }
  fail('no attendance indicator dot was rendered for day "$dayNumber"');
}

void main() {
  group('AttendanceCalendar day states', () {
    // A mid-month day keeps the assertions clear of month boundaries.
    final target = DateTime.now();
    final probe = DateTime(target.year, target.month, 15);
    final probeKey = _dayKey(probe);
    final day = '${probe.day}';

    testWidgets('all-present day renders the Present state', (tester) async {
      await tester.pumpWidget(_calendar(data: [_summary(probeKey, 3, 0)]));
      await tester.pumpAndSettle();

      expect(
          _dotColorForDay(tester, day),
          getStateColor(CalendarAttendanceState.presentOnly));
      expect(getStateColor(CalendarAttendanceState.presentOnly), Colors.green);
    });

    testWidgets('all-absent day renders the Absent state', (tester) async {
      await tester.pumpWidget(_calendar(data: [_summary(probeKey, 0, 2)]));
      await tester.pumpAndSettle();

      expect(
          _dotColorForDay(tester, day),
          getStateColor(CalendarAttendanceState.absentOnly));
      expect(getStateColor(CalendarAttendanceState.absentOnly), Colors.red);
    });

    testWidgets('mixed day renders the Mixed state', (tester) async {
      await tester.pumpWidget(_calendar(data: [_summary(probeKey, 2, 1)]));
      await tester.pumpAndSettle();

      expect(_dotColorForDay(tester, day),
          getStateColor(CalendarAttendanceState.mixed));
      expect(getStateColor(CalendarAttendanceState.mixed), Colors.orange);
    });

    testWidgets('day without records renders the No Record state',
        (tester) async {
      await tester.pumpWidget(_calendar(data: const []));
      await tester.pumpAndSettle();

      expect(
          _dotColorForDay(tester, day),
          getStateColor(CalendarAttendanceState.noRecord));
      expect(getStateColor(CalendarAttendanceState.noRecord), Colors.grey);
    });
  });

  group('classifyAttendanceState', () {
    test('present only', () {
      expect(classifyAttendanceState(3, 0), CalendarAttendanceState.presentOnly);
    });

    test('absent only', () {
      expect(classifyAttendanceState(0, 2), CalendarAttendanceState.absentOnly);
    });

    test('mixed', () {
      expect(classifyAttendanceState(2, 1), CalendarAttendanceState.mixed);
    });

    test('no record', () {
      expect(classifyAttendanceState(0, 0), CalendarAttendanceState.noRecord);
    });
  });

  group('AttendanceCalendar month navigation', () {
    testWidgets('starts on the current month', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_calendar(data: const []));
      await tester.pumpAndSettle();

      expect(find.text(_monthLabel(now)), findsOneWidget);
    });

    testWidgets('previous and next chevrons move the displayed month',
        (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_calendar(data: const []));
      await tester.pumpAndSettle();

      final previous = DateTime(now.year, now.month - 1);
      final next = DateTime(now.year, now.month + 1);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text(_monthLabel(previous)), findsOneWidget);
      expect(find.text(_monthLabel(now)), findsNothing);

      // One step forward returns to the current month, a second moves ahead.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text(_monthLabel(now)), findsOneWidget);
      expect(find.text(_monthLabel(previous)), findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text(_monthLabel(next)), findsOneWidget);
      expect(find.text(_monthLabel(now)), findsNothing);
    });

    testWidgets('Today returns to the current month and selects today',
        (tester) async {
      final now = DateTime.now();
      final selected = <String>[];
      await tester.pumpWidget(
          _calendar(data: const [], onDateSelected: selected.add));
      await tester.pumpAndSettle();

      // Navigate away first so the Today action has something to undo.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text(_monthLabel(DateTime(now.year, now.month - 1))),
          findsOneWidget);

      selected.clear();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.text(_monthLabel(now)), findsOneWidget);
      expect(selected, [_dayKey(DateTime(now.year, now.month, now.day))]);
    });

    testWidgets('changing month clears the selected date', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
          _calendar(data: const [], onDateSelected: selected.add));
      await tester.pumpAndSettle();

      selected.clear();
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(selected, ['']);
    });

    testWidgets('a tapped day is emitted as zero-padded ISO yyyy-MM-dd',
        (tester) async {
      final now = DateTime.now();
      final selected = <String>[];
      await tester.pumpWidget(
          _calendar(data: const [], onDateSelected: selected.add));
      await tester.pumpAndSettle();

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // Regression guard: this used to be "2026-9-15", which never matched a
      // backend `AttendanceRecord.date` of "2026-09-15".
      expect(selected, ['${now.year}-09-15']);
      expect(selected.single, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    testWidgets('a tapped day in a single-digit month is still padded',
        (tester) async {
      // Jump the displayed month back to January, where an unpadded month
      // previously produced "2027-1-05".
      final now = DateTime.now();
      final january = DateTime(now.year, 1);
      final selected = <String>[];
      await tester.pumpWidget(
          _calendar(data: const [], onDateSelected: selected.add));
      await tester.pumpAndSettle();

      // Navigate to January of the displayed year.
      var taps = 0;
      while (find.text(_monthLabel(january)).evaluate().isEmpty && taps < 14) {
        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pumpAndSettle();
        taps++;
      }
      expect(find.text(_monthLabel(january)), findsOneWidget);

      // Chevron taps each report an empty selection; only the day tap matters.
      selected.clear();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();

      expect(selected, ['${january.year}-01-05']);
    });

    testWidgets('a tapped day matches an AttendanceRecord with the same '
        'ISO date', (tester) async {
      // The record key a real backend response would carry.
      const recordDate = '2026-09-15';
      final record = AttendanceRecord(
          id: 1,
          subjectId: 5,
          status: 'PRESENT',
          isPresent: true,
          date: recordDate,
          lecturePeriod: '1st');

      final now = DateTime.now();
      final probe = DateTime(now.year, now.month, 15);
      final selected = <String>[];
      await tester.pumpWidget(
        _calendar(
          data: [
            CalendarAttendance(
                date: _dayKey(probe),
                presentCount: 1,
                absentCount: 0,
                totalRecordedCount: 1,
                percentage: 100),
          ],
          allRecords: [record],
          onDateSelected: selected.add,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // The emitted selection is directly comparable to the record date, and
      // the calendar resolves the matching summary/record for that day.
      expect(selected, [recordDate]);
      final matching =
          [record].where((r) => r.date == selected.single).toList();
      expect(matching, hasLength(1));
      expect(_dotColorForDay(tester, '15'), Colors.green);
    });

    testWidgets('Today emits zero-padded ISO yyyy-MM-dd', (tester) async {
      final now = DateTime.now();
      final selected = <String>[];
      await tester.pumpWidget(
          _calendar(data: const [], onDateSelected: selected.add));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(selected, [_dayKey(now)]);
      expect(selected.single, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    testWidgets('tapping a day reports that day', (tester) async {
      final now = DateTime.now();
      final probe = DateTime(now.year, now.month, 15);
      final selected = <String>[];
      await tester.pumpWidget(
          _calendar(data: const [], onDateSelected: selected.add));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${probe.day}'));
      await tester.pumpAndSettle();

      expect(selected, [_dayKey(probe)]);
    });
  });

  group('AttendanceCalendar subject filter', () {
    final now = DateTime.now();
    final probe = DateTime(now.year, now.month, 15);
    final probeKey = _dayKey(probe);

    // The aggregate row says present-only, but the subject-scoped records for
    // the same day are absent-only, so the dot must follow the subject filter.
    final records = [
      AttendanceRecord(
          id: 1,
          subjectId: 5,
          status: 'ABSENT',
          isPresent: false,
          date: probeKey,
          lecturePeriod: '1st'),
      AttendanceRecord(
          id: 2,
          subjectId: 6,
          status: 'PRESENT',
          isPresent: true,
          date: probeKey,
          lecturePeriod: '2nd'),
    ];

    testWidgets('no subject filter uses the aggregate summary',
        (tester) async {
      await tester.pumpWidget(_calendar(
        data: [_summary(probeKey, 1, 0)],
        allRecords: records,
      ));
      await tester.pumpAndSettle();

      expect(_dotColorForDay(tester, '${probe.day}'), Colors.green);
    });

    testWidgets('subject filter re-scopes the day state from records',
        (tester) async {
      await tester.pumpWidget(_calendar(
        data: [_summary(probeKey, 1, 0)],
        subjectId: 5,
        allRecords: records,
      ));
      await tester.pumpAndSettle();

      expect(_dotColorForDay(tester, '${probe.day}'), Colors.red);
    });

    testWidgets('a subject with no record on that day shows No Record',
        (tester) async {
      await tester.pumpWidget(_calendar(
        data: [_summary(probeKey, 1, 0)],
        subjectId: 99,
        allRecords: records,
      ));
      await tester.pumpAndSettle();

      expect(_dotColorForDay(tester, '${probe.day}'), Colors.grey);
    });
  });
}
