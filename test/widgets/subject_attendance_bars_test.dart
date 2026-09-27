import 'package:dagacs_frontend/models/subject_attendance.dart';
import 'package:dagacs_frontend/widgets/subject_attendance_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(List<SubjectAttendance> subjects, {double width = 1000}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: SubjectAttendanceBars(subjects: subjects),
        ),
      ),
    ),
  );
}

SubjectAttendance _subject(
  int id,
  String name, {
  required int present,
  required int total,
  double? percentage,
}) =>
    SubjectAttendance(
      subjectId: id,
      subjectName: name,
      presentCount: present,
      totalRecordedCount: total,
      percentage: percentage,
    );

void main() {
  group('SubjectAttendanceBars', () {
    testWidgets('renders subject name, present/total and percentage',
        (tester) async {
      await tester.pumpWidget(_wrap([
        _subject(5, 'Database Systems', present: 42, total: 45, percentage: 93),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Database Systems'), findsOneWidget);
      expect(find.text('42/45'), findsOneWidget);
      expect(find.text('93%'), findsOneWidget);
    });

    testWidgets('renders every subject supplied', (tester) async {
      await tester.pumpWidget(_wrap([
        _subject(5, 'DSA', present: 42, total: 45, percentage: 93),
        _subject(6, 'DBMS', present: 38, total: 42, percentage: 90),
        _subject(7, 'ML', present: 35, total: 40, percentage: 87.5),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('DSA'), findsOneWidget);
      expect(find.text('DBMS'), findsOneWidget);
      expect(find.text('ML'), findsOneWidget);
      expect(find.text('42/45'), findsOneWidget);
      expect(find.text('38/42'), findsOneWidget);
      expect(find.text('35/40'), findsOneWidget);
      // 87.5 rounds for display but is never inflated.
      expect(find.text('88%'), findsOneWidget);
    });

    testWidgets('animated bar settles on the attendance ratio',
        (tester) async {
      await tester.pumpWidget(_wrap([
        _subject(5, 'DSA', present: 8, total: 10, percentage: 80),
      ]));

      // Mid-flight the track is only partially filled.
      await tester.pump(const Duration(milliseconds: 40));
      final midway = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((w) => w.widthFactor)
          .toList();
      expect(midway, isNotEmpty);
      expect(midway.any((v) => v != null && v < 0.8), isTrue,
          reason: 'bar should animate in rather than snap');

      await tester.pumpAndSettle();
      final settled = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((w) => w.widthFactor)
          .toList();
      expect(settled.any((v) => v != null && (v - 0.8).abs() < 0.001), isTrue);
    });

    testWidgets('null percentage shows N/A and does not render a fake value',
        (tester) async {
      await tester.pumpWidget(_wrap([
        _subject(5, 'DSA', present: 0, total: 0),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('N/A'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty subject list shows the empty message', (tester) async {
      await tester.pumpWidget(_wrap(const []));
      await tester.pumpAndSettle();

      expect(find.text('No subject attendance data available'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long subject names truncate without overflowing at 320px',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        [
          _subject(5,
              'Introduction to Very Long Subject Name That Will Not Fit',
              present: 42,
              total: 45,
              percentage: 93),
        ],
        width: 320,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Counts and percentage stay fully visible even when the name truncates.
      expect(find.text('42/45'), findsOneWidget);
      expect(find.text('93%'), findsOneWidget);
    });

    testWidgets('lays out multiple columns on wide viewports', (tester) async {
      await tester.pumpWidget(_wrap([
        _subject(1, 'A', present: 1, total: 1, percentage: 100),
        _subject(2, 'B', present: 1, total: 1, percentage: 100),
        _subject(3, 'C', present: 1, total: 1, percentage: 100),
        _subject(4, 'D', present: 1, total: 1, percentage: 100),
      ], width: 1400));
      await tester.pumpAndSettle();

      // Two per row at >=1100px, so four subjects occupy two rows.
      final positions = <double, List<double>>{};
      for (final name in ['A', 'B', 'C', 'D']) {
        final topLeft = tester.getTopLeft(find.text(name));
        positions.putIfAbsent(topLeft.dy, () => <double>[]).add(topLeft.dx);
      }
      expect(positions.length, 2, reason: 'expected two rows of two subjects');
      for (final row in positions.values) {
        expect(row.length, 2);
      }
    });

    testWidgets('stacks into a single column on narrow viewports',
        (tester) async {
      await tester.pumpWidget(_wrap([
        _subject(1, 'A', present: 1, total: 1, percentage: 100),
        _subject(2, 'B', present: 1, total: 1, percentage: 100),
      ], width: 360));
      await tester.pumpAndSettle();

      final a = tester.getTopLeft(find.text('A'));
      final b = tester.getTopLeft(find.text('B'));
      expect(a.dx, b.dx, reason: 'single column shares one left edge');
      expect(b.dy, greaterThan(a.dy));
      expect(tester.takeException(), isNull);
    });
  });
}
