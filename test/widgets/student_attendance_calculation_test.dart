import 'package:dagacs_frontend/models/attendance_percentage.dart';
import 'package:dagacs_frontend/models/attendance_record.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/attendance_repository.dart';
import 'package:dagacs_frontend/screens/student_attendance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAttendanceRepository extends AttendanceRepository {
  _FakeAttendanceRepository();

  Future<List<AttendanceRecord>> Function()? onGetMyAttendance;
  Future<AttendancePercentage> Function()? onGetOverall;
  Future<AttendancePercentage> Function(int subjectId)? onGetSubject;
  int subjectRequestCount = 0;
  int getMyAttendanceCallCount = 0;
  DateTime? lastOverallStartDate;
  DateTime? lastOverallEndDate;
  DateTime? lastSubjectStartDate;
  DateTime? lastSubjectEndDate;

  @override
  Future<List<AttendanceRecord>> getMyAttendance() {
    getMyAttendanceCallCount++;
    return onGetMyAttendance!();
  }

  @override
  Future<AttendancePercentage> getOverallAttendanceCalculation(
      {DateTime? startDate, DateTime? endDate}) {
    lastOverallStartDate = startDate;
    lastOverallEndDate = endDate;
    return onGetOverall!();
  }

  @override
  Future<AttendancePercentage> getSubjectAttendanceCalculation(
      int subjectId,
      {DateTime? startDate, DateTime? endDate}) {
    subjectRequestCount++;
    lastSubjectStartDate = startDate;
    lastSubjectEndDate = endDate;
    return onGetSubject!(subjectId);
  }
}

const _records = [
  AttendanceRecord(
      id: 1, subjectId: 5, status: 'PRESENT', isPresent: true,
      date: '2026-09-04', lecturePeriod: '1st'),
  AttendanceRecord(
      id: 2, subjectId: 5, status: 'ABSENT', isPresent: false,
      date: '2026-09-04', lecturePeriod: '1st'),
  AttendanceRecord(
      id: 3, subjectId: 6, status: 'PRESENT', isPresent: true,
      date: '2026-09-04', lecturePeriod: '2nd'),
];

Widget _wrap(AttendanceRepository repo) =>
    MaterialApp(home: StudentAttendanceScreen(attendanceRepository: repo));

void main() {
  testWidgets('shows loading state while fetching', (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _records;
    };
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 2, totalRecordedCount: 3, percentage: 66.7));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('62.5%'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('valid overall calculation displays correctly', (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 5, totalRecordedCount: 8, percentage: 62.5));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Overall Attendance'), findsOneWidget);
    expect(find.text('5 / 8'), findsOneWidget);
    expect(find.text('62.5%'), findsOneWidget);
    expect(find.text('Present'), findsNWidgets(2));
    expect(find.text('Absent'), findsOneWidget);
  });

  testWidgets('subject calculation values display with records', (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 5, totalRecordedCount: 8, percentage: 62.5));
    repo.onGetSubject = (id) async {
      if (id == 5) {
        return const AttendancePercentage(
            presentCount: 2, totalRecordedCount: 3, percentage: 66.7);
      }
      return const AttendancePercentage(
          presentCount: 1, totalRecordedCount: 1, percentage: 100.0);
    };

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Subject 5'), findsNWidgets(3));
    expect(find.text('Subject 6'), findsNWidgets(2));
    expect(find.textContaining('Present: 2'), findsOneWidget);
    expect(find.textContaining('Recorded: 3'), findsOneWidget);
    expect(find.textContaining('Percentage: 66.7%'), findsOneWidget);
    expect(find.textContaining('Percentage: 100%'), findsOneWidget);
  });

  testWidgets('overall calculation succeeds -> records remain displayed',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 5, totalRecordedCount: 8, percentage: 62.5));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.text('Present'), findsNWidgets(2));
    expect(find.text('5 / 8'), findsOneWidget);
  });

  testWidgets('overall calculation fails -> records still display + error shown',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async => throw const ApiException.network();
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Present'), findsNWidgets(2));
    expect(find.text('Absent'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.textContaining('Unable to connect'), findsOneWidget);
  });

  testWidgets('one subject calculation fails -> others still render + error shown',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 5, totalRecordedCount: 8, percentage: 62.5));
    repo.onGetSubject = (id) async {
      if (id == 5) {
        throw const ApiException.network();
      }
      return const AttendancePercentage(
          presentCount: 1, totalRecordedCount: 1, percentage: 100.0);
    };

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unable to connect'), findsOneWidget);
    expect(find.textContaining('Percentage: 100%'), findsOneWidget);
    expect(find.text('5 / 8'), findsOneWidget);
    expect(find.text('Present'), findsNWidgets(2));
  });

  testWidgets('duplicate subjectIds result in only one request per subject',
      (tester) async {
    final recordsWithDupSubject = [
      const AttendanceRecord(
          id: 1, subjectId: 5, status: 'PRESENT', isPresent: true,
          date: '2026-09-04', lecturePeriod: '1st'),
      const AttendanceRecord(
          id: 2, subjectId: 5, status: 'ABSENT', isPresent: false,
          date: '2026-09-04', lecturePeriod: '1st'),
      const AttendanceRecord(
          id: 3, subjectId: 5, status: 'PRESENT', isPresent: true,
          date: '2026-09-03', lecturePeriod: '3rd'),
    ];
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => recordsWithDupSubject;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 2, totalRecordedCount: 3, percentage: 66.7));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 2, totalRecordedCount: 3, percentage: 66.7));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(repo.subjectRequestCount, 1);
  });

  testWidgets('zero-record calculation preserves null and shows empty state',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 0, totalRecordedCount: 0));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 0, totalRecordedCount: 0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('No attendance records available'), findsWidgets);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('zero-record overall does not display 0%', (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 0, totalRecordedCount: 0));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.text('0%'), findsNothing);
    expect(find.text('No attendance records available'), findsOneWidget);
  });

  testWidgets('screen does not crash when calculation request fails',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async => throw const ApiException.serverError();
    repo.onGetSubject = (_) async => throw const ApiException.serverError();

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Present'), findsNWidgets(2));
    expect(find.text('Absent'), findsOneWidget);
  });

  testWidgets('date selection refreshes calculations without re-fetching records',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 5, totalRecordedCount: 8, percentage: 62.5));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(repo.getMyAttendanceCallCount, 1);
    expect(repo.lastOverallStartDate, isNull);

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Pick a start date via the standard picker dialog.
    await tester.tap(find.byKey(const Key('start-date-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Calculations re-ran with the picked date; records were NOT re-fetched.
    expect(repo.lastOverallStartDate, todayDate);
    expect(repo.lastOverallEndDate, isNull);
    expect(repo.getMyAttendanceCallCount, 1);
    expect(find.text('5 / 8'), findsOneWidget);
  });

  testWidgets('end-date selection refreshes calculations with endDate',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 5, totalRecordedCount: 8, percentage: 62.5));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('end-date-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(repo.lastOverallStartDate, isNull);
    expect(repo.lastOverallEndDate, isNotNull);
    expect(repo.getMyAttendanceCallCount, 1);
  });

  testWidgets('start and end dates forward to subject calculations too',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 5, totalRecordedCount: 8, percentage: 62.5));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-date-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(repo.lastSubjectStartDate, isNotNull);
    expect(repo.lastSubjectStartDate, repo.lastOverallStartDate);
  });

  testWidgets('clearing dates refreshes calculations without dates',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 5, totalRecordedCount: 8, percentage: 62.5));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-date-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repo.lastOverallStartDate, isNotNull);

    await tester.tap(find.byKey(const Key('clear-dates-button')));
    await tester.pumpAndSettle();

    expect(repo.lastOverallStartDate, isNull);
    expect(repo.lastOverallEndDate, isNull);
    expect(repo.getMyAttendanceCallCount, 1);
  });

  testWidgets('overall calc failure with dates selected -> records + error preserved',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async => throw const ApiException.network();
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-date-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Records remain; the calculation error is localized (M4.2 isolation).
    expect(find.text('Present'), findsNWidgets(2));
    expect(find.text('Absent'), findsOneWidget);
    expect(find.textContaining('Unable to connect'), findsOneWidget);
  });

  group('isInvertedDateRange (M9.14)', () {
    final d1 = DateTime(2026, 9, 1);
    final d2 = DateTime(2026, 9, 2);

    test('false when either bound is null', () {
      expect(isInvertedDateRange(null, null), isFalse);
      expect(isInvertedDateRange(d1, null), isFalse);
      expect(isInvertedDateRange(null, d2), isFalse);
    });

    test('false when the bounds are equal (single-day filter is valid)', () {
      expect(isInvertedDateRange(d1, d1), isFalse);
    });

    test('false when start is before end', () {
      expect(isInvertedDateRange(d1, d2), isFalse);
    });

    test('true when start is after end', () {
      expect(isInvertedDateRange(d2, d1), isTrue);
    });
  });

  Future<void> _tapPickerDay(WidgetTester tester, int day) async {
    await tester.tap(find.descendant(
      of: find.byType(CalendarDatePicker),
      matching: find.text('$day'),
    ));
    await tester.pumpAndSettle();
  }

  String? _buttonLabel(WidgetTester tester, Key key) =>
      tester
          .widget<Text>(find.descendant(
            of: find.byKey(key),
            matching: find.byType(Text),
          ))
          .data;

  testWidgets(
      'invalid end-before-start keeps the previous end date and issues no request',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 5, totalRecordedCount: 8, percentage: 62.5));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Valid equal pair on the 2nd of the current month (day 2 always exists).
    await tester.tap(find.byKey(const Key('start-date-button')));
    await tester.pumpAndSettle();
    await _tapPickerDay(tester, 2);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repo.lastOverallStartDate, isNotNull);

    await tester.tap(find.byKey(const Key('end-date-button')));
    await tester.pumpAndSettle();
    await _tapPickerDay(tester, 2);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repo.lastOverallEndDate, isNotNull);

    final endLabelBefore = _buttonLabel(tester, const Key('end-date-button'));
    final startAfterValidPair = repo.lastOverallStartDate;
    final endAfterValidPair = repo.lastOverallEndDate;
    final subjectBase = repo.subjectRequestCount;

    // Attempt an inverted end (day 1 is before start day 2).
    await tester.tap(find.byKey(const Key('end-date-button')));
    await tester.pumpAndSettle();
    await _tapPickerDay(tester, 1);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('date-range-error')), findsOneWidget);
    expect(find.text(kInvertedDateRangeMessage), findsOneWidget);
    expect(_buttonLabel(tester, const Key('end-date-button')), endLabelBefore,
        reason: 'M9.14: the offending end bound must stay unmutated on an invalid pick');
    expect(repo.lastOverallStartDate, startAfterValidPair,
        reason: 'M9.14: an invalid pick must not trigger a new calculation request');
    expect(repo.lastOverallEndDate, endAfterValidPair);
    expect(repo.subjectRequestCount, subjectBase);
  });

  testWidgets(
      'invalid start-after-end keeps the previous start date and issues no request',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 5, totalRecordedCount: 8, percentage: 62.5));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Valid ordered pair: start = day 1, end = day 2.
    await tester.tap(find.byKey(const Key('start-date-button')));
    await tester.pumpAndSettle();
    await _tapPickerDay(tester, 1);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repo.lastOverallStartDate, isNotNull);

    await tester.tap(find.byKey(const Key('end-date-button')));
    await tester.pumpAndSettle();
    await _tapPickerDay(tester, 2);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repo.lastOverallEndDate, isNotNull);

    final startLabelBefore =
        _buttonLabel(tester, const Key('start-date-button'));
    final startAfterValidPair = repo.lastOverallStartDate;
    final endAfterValidPair = repo.lastOverallEndDate;
    final subjectBase = repo.subjectRequestCount;

    // Attempt an inverted start (day 3 is after end day 2).
    await tester.tap(find.byKey(const Key('start-date-button')));
    await tester.pumpAndSettle();
    await _tapPickerDay(tester, 3);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('date-range-error')), findsOneWidget);
    expect(find.text(kInvertedDateRangeMessage), findsOneWidget);
    expect(_buttonLabel(tester, const Key('start-date-button')), startLabelBefore,
        reason: 'M9.14: the offending start bound must stay unmutated on an invalid pick');
    expect(repo.lastOverallStartDate, startAfterValidPair,
        reason: 'M9.14: an invalid pick must not trigger a new calculation request');
    expect(repo.lastOverallEndDate, endAfterValidPair);
    expect(repo.subjectRequestCount, subjectBase);
  });

  testWidgets('equal start and end range is accepted and issues the request',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 5, totalRecordedCount: 8, percentage: 62.5));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-date-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('end-date-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(repo.lastOverallEndDate, isNotNull);
    expect(repo.lastOverallStartDate, repo.lastOverallEndDate);
    expect(repo.subjectRequestCount, greaterThan(0));
    expect(find.byKey(const Key('date-range-error')), findsNothing);
  });

  testWidgets('ordered start-before-end range is accepted and issues the request',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 5, totalRecordedCount: 8, percentage: 62.5));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Start on the first day of the current month (always present in the grid).
    await tester.tap(find.byKey(const Key('start-date-button')));
    await tester.pumpAndSettle();
    await _tapPickerDay(tester, 1);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // End = today (OK default). If today is the 1st, pick day 2 instead so the
    // range stays strictly ordered.
    final today = DateTime.now();
    await tester.tap(find.byKey(const Key('end-date-button')));
    await tester.pumpAndSettle();
    if (today.day <= 1) {
      await _tapPickerDay(tester, 2);
    }
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(repo.lastOverallEndDate, isNotNull);
    expect(repo.lastOverallStartDate!.isBefore(repo.lastOverallEndDate!),
        isTrue,
        reason: 'M9.14: a strictly ordered range must be accepted');
    expect(find.byKey(const Key('date-range-error')), findsNothing);
  });

  testWidgets('date-range error clears when dates are cleared',
      (tester) async {
    final repo = _FakeAttendanceRepository();
    repo.onGetMyAttendance = () async => _records;
    repo.onGetOverall = () async =>
        (const AttendancePercentage(presentCount: 5, totalRecordedCount: 8, percentage: 62.5));
    repo.onGetSubject = (_) async =>
        (const AttendancePercentage(presentCount: 1, totalRecordedCount: 1, percentage: 100.0));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Create a rejected inverted range (start = today, end = day 1).
    await tester.tap(find.byKey(const Key('start-date-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('end-date-button')));
    await tester.pumpAndSettle();
    await _tapPickerDay(tester, 1);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('date-range-error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear-dates-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('date-range-error')), findsNothing);
    expect(repo.lastOverallStartDate, isNull);
    expect(repo.lastOverallEndDate, isNull);
  });
}
