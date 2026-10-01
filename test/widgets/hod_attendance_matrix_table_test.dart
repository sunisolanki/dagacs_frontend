import 'package:dagacs_frontend/models/hod_attendance_matrix.dart';
import 'package:dagacs_frontend/widgets/hod/hod_matrix_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Presentation contract of the HOD attendance cross-tab.
///
/// The properties asserted here are the ones a HOD would notice being wrong:
/// dynamic subject columns, a visible denominator, an honest "no data" state
/// instead of a fabricated zero, sortable headers, and a table that stays
/// usable when it is wider than the viewport.
void main() {
  Widget wrap({
    required List<HodAttendanceMatrixColumn> columns,
    required List<HodAttendanceMatrixRow> rows,
    HodMatrixSort sort = HodMatrixSort.enrollmentNumber,
    bool sortAscending = true,
    ValueChanged<HodMatrixSort>? onSortChanged,
    ValueChanged<HodAttendanceMatrixRow>? onRowTap,
    double? thresholdPercentage = 75.0,
    Size size = const Size(1400, 900),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: HodMatrixTable(
            columns: columns,
            rows: rows,
            sort: sort,
            sortAscending: sortAscending,
            onSortChanged: onSortChanged,
            onRowTap: onRowTap,
            thresholdPercentage: thresholdPercentage,
          ),
        ),
      ),
    );
  }

  final columns = [
    const HodAttendanceMatrixColumn(
      subjectId: 101,
      subjectOfferingId: 11,
      subjectCode: 'CS301',
      subjectName: 'Data Structures and Algorithms',
      facultyNames: ['Dr Rao'],
    ),
    const HodAttendanceMatrixColumn(
      subjectId: 102,
      subjectOfferingId: 12,
      subjectCode: 'CS302',
      subjectName: 'Computer Networks',
    ),
  ];

  final rows = [
    HodAttendanceMatrixRow(
      studentId: 91,
      enrollmentNumber: 'CS2025001',
      rollNumber: 'R1',
      studentName: 'Rahul',
      sectionName: 'A',
      subjects: const [
        HodAttendanceMatrixCell(subjectId: 101, present: 32, total: 40, percentage: 80),
        HodAttendanceMatrixCell(subjectId: 102, present: 30, total: 35, percentage: 85.7142),
      ],
      totalPresent: 62,
      totalClasses: 75,
      overallPercentage: 82.6666,
    ),
    // A student with no attendance at all: still rendered, as 0 / 0 and N/A.
    const HodAttendanceMatrixRow(
      studentId: 93,
      enrollmentNumber: 'CS2025003',
      rollNumber: 'R3',
      studentName: 'Neha',
      sectionName: 'A',
      subjects: [
        HodAttendanceMatrixCell(subjectId: 101, present: 0, total: 0),
        HodAttendanceMatrixCell(subjectId: 102, present: 0, total: 0),
      ],
      totalPresent: 0,
      totalClasses: 0,
    ),
  ];

  testWidgets('renders one dynamic column per subject of the context',
      (tester) async {
    await tester.pumpWidget(wrap(columns: columns, rows: rows));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hod-matrix-column-101')), findsOneWidget);
    expect(find.byKey(const Key('hod-matrix-column-102')), findsOneWidget);
    expect(find.text('CS301'), findsOneWidget);
    expect(find.text('CS302'), findsOneWidget);
  });

  testWidgets('shows the fixed identity and total headers', (tester) async {
    await tester.pumpWidget(wrap(columns: columns, rows: rows));
    await tester.pumpAndSettle();

    expect(find.text('Enrollment No.'), findsOneWidget);
    expect(find.text('Student Name'), findsOneWidget);
    expect(find.text('Total Present'), findsOneWidget);
    expect(find.text('Total Classes'), findsOneWidget);
    expect(find.text('Overall Attendance %'), findsOneWidget);
  });

  testWidgets('cells show Present / Total and the percentage beneath',
      (tester) async {
    await tester.pumpWidget(wrap(columns: columns, rows: rows));
    await tester.pumpAndSettle();

    expect(find.text('32 / 40'), findsOneWidget);
    expect(find.text('30 / 35'), findsOneWidget);
    expect(find.text('80.0%'), findsOneWidget);
    expect(find.byKey(const Key('hod-matrix-cell-91-101')), findsOneWidget);
  });

  testWidgets('a student with zero attendance stays visible as 0 / 0 and N/A',
      (tester) async {
    await tester.pumpWidget(wrap(columns: columns, rows: rows));
    await tester.pumpAndSettle();

    expect(find.text('CS2025003'), findsOneWidget);
    expect(find.text('Neha'), findsOneWidget);
    expect(find.byKey(const Key('hod-matrix-cell-93-101')), findsOneWidget);
    expect(find.text('0 / 0'), findsNWidgets(2));
    // The overall percentage of a student with nothing recorded is N/A, never 0%.
    expect(find.text('N/A'), findsWidgets);
  });

  testWidgets('totals come from the row, not from an average of the cells',
      (tester) async {
    await tester.pumpWidget(wrap(columns: columns, rows: rows));
    await tester.pumpAndSettle();

    // 62 / 75 = 82.67%, while the mean of 80.0% and 85.7% would be 82.86%.
    expect(find.text('82.67%'), findsOneWidget);
  });

  testWidgets('a wide matrix scrolls horizontally instead of clipping',
      (tester) async {
    await tester.pumpWidget(wrap(
      columns: columns,
      rows: rows,
      size: const Size(420, 900),
    ));
    await tester.pumpAndSettle();

    final scroll = find.byKey(const Key('hod-matrix-scroll-horizontal'));
    expect(scroll, findsOneWidget);
    final controller = tester.widget<SingleChildScrollView>(scroll).controller;
    expect(
      controller == null || controller.position.maxScrollExtent >= 0,
      isTrue,
    );
    // The first identity column is still rendered on a narrow viewport.
    expect(find.text('CS2025001'), findsOneWidget);
  });

  testWidgets('tapping a sortable header reports the column, tapping again flips',
      (tester) async {
    // A wide surface so the last column is not off-screen.
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final requested = <HodMatrixSort>[];
    await tester.pumpWidget(wrap(
      columns: columns,
      rows: rows,
      onSortChanged: requested.add,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hod-matrix-sort-name')));
    await tester.pumpAndSettle();
    expect(requested, [HodMatrixSort.name]);

    await tester.tap(find.byKey(const Key('hod-matrix-sort-overallPercentage')));
    await tester.pumpAndSettle();
    expect(requested, [HodMatrixSort.name, HodMatrixSort.overallPercentage]);
  });
  testWidgets('the active sort is announced with its direction', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(
      columns: columns,
      rows: rows,
      sort: HodMatrixSort.overallPercentage,
      sortAscending: false,
      onSortChanged: (_) {},
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(
      _labels(tester, find.byType(Semantics)),
      anyElement(contains('Overall Attendance %, sorted descending')),
    );
  });

  testWidgets('a non-interactive column is not announced as a button',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(
      columns: columns,
      rows: rows,
      sort: HodMatrixSort.overallPercentage,
    ));
    await tester.pumpAndSettle();

    // The visual indicator is still shown, but nothing claims to be sortable.
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(
      _labels(tester, find.byType(Semantics)),
      isNot(anyElement(contains('Activate to sort'))),
    );
  });

  testWidgets('an unsorted column is announced as not sorted', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(
      columns: columns,
      rows: rows,
      sort: HodMatrixSort.name,
      onSortChanged: (_) {},
    ));
    await tester.pumpAndSettle();

    expect(
      _labels(tester, find.byType(Semantics)),
      anyElement(contains('Overall Attendance %, not sorted')),
    );
    expect(
      _labels(tester, find.byType(Semantics)),
      anyElement(contains('Student Name, sorted ascending')),
    );
  });
  testWidgets('a row tap reports the student when a handler is supplied',
      (tester) async {
    final tapped = <HodAttendanceMatrixRow>[];
    await tester.pumpWidget(wrap(
      columns: columns,
      rows: rows,
      onRowTap: tapped.add,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hod-matrix-row-91')));
    await tester.pumpAndSettle();

    expect(tapped.single.studentId, 91);
  });

  testWidgets('with no handler the rows are not tappable affordances',
      (tester) async {
    await tester.pumpWidget(wrap(columns: columns, rows: rows));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hod-matrix-row-91')), findsNothing);
  });

  testWidgets('a subject header tooltip carries the name and the faculty',
      (tester) async {
    await tester.pumpWidget(wrap(columns: columns, rows: rows));
    await tester.pumpAndSettle();

    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('hod-matrix-column-101')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, contains('CS301 · Data Structures and Algorithms'));
    expect(tooltip.message, contains('Dr Rao'));
  });

  testWidgets('an unassigned subject says so in its tooltip', (tester) async {
    await tester.pumpWidget(wrap(columns: columns, rows: rows));
    await tester.pumpAndSettle();

    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('hod-matrix-column-102')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, contains('No faculty assigned'));
  });

  testWidgets('a context with no subjects states it instead of an empty table',
      (tester) async {
    await tester.pumpWidget(wrap(columns: const [], rows: const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hod-matrix-no-subjects')), findsOneWidget);
    expect(
      find.text('No subjects are offered in the selected semester.'),
      findsOneWidget,
    );
  });

  testWidgets('cell tooltips name the subject, the counts and the percentage',
      (tester) async {
    await tester.pumpWidget(wrap(columns: columns, rows: rows));
    await tester.pumpAndSettle();

    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('hod-matrix-cell-91-101')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, contains('CS301 · Data Structures and Algorithms'));
    expect(tooltip.message, contains('32 of 40 classes attended'));
    expect(tooltip.message, contains('80.00 percent'));
  });

  testWidgets('a cell with no class is announced as such, not as zero percent',
      (tester) async {
    await tester.pumpWidget(wrap(columns: columns, rows: rows));
    await tester.pumpAndSettle();

    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('hod-matrix-cell-93-101')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, contains('no class conducted'));
  });

  testWidgets('a cell is announced with the subject, counts and percentage',
      (tester) async {
    await tester.pumpWidget(wrap(columns: columns, rows: rows));
    await tester.pumpAndSettle();

    expect(
      _cellSemanticsLabels(tester, 'hod-matrix-cell-91-101'),
      anyElement(contains('32 of 40 classes attended')),
    );
  });
}

/// Semantics labels of the cell identified by [key].
List<String> _cellSemanticsLabels(WidgetTester tester, String key) => _labels(
    tester,
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(Semantics)));

List<String> _labels(WidgetTester tester, Finder finder) => tester
    .widgetList<Semantics>(finder)
    .map((widget) => widget.properties.label)
    .whereType<String>()
    .toList();
