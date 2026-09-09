import 'package:dagacs_frontend/widgets/dagacs_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPrimaryButton', () {
    testWidgets('renders child and triggers onPressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppPrimaryButton(
            onPressed: () => tapped = true,
            child: const Text('Save'),
          ),
        ),
      ));

      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.text('Save'));
      expect(tapped, isTrue);
    });

    testWidgets('shows a spinner and disables taps while loading',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppPrimaryButton(
            onPressed: () => tapped = true,
            loading: true,
            child: const Text('Save'),
          ),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.byType(AppPrimaryButton));
      expect(tapped, isFalse);
    });
  });

  group('AppSecondaryButton', () {
    testWidgets('renders an outlined button with the child',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppSecondaryButton(
            onPressed: () {},
            child: const Text('Cancel'),
          ),
        ),
      ));

      expect(find.text('Cancel'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppSecondaryButton),
          matching: find.byType(OutlinedButton),
        ),
        findsOneWidget,
      );
    });
  });

  group('AppDangerButton', () {
    testWidgets('renders a red ElevatedButton', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppDangerButton(
            onPressed: () {},
            child: const Text('Delete'),
          ),
        ),
      ));

      expect(find.text('Delete'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppDangerButton),
          matching: find.byType(ElevatedButton),
        ),
        findsOneWidget,
      );
    });
  });

  group('AppStatCard', () {
    testWidgets('renders value, label and optional subtitle',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppStatCard(
            icon: Icons.people_outline,
            value: '42',
            label: 'Students',
            subtitle: 'Active this term',
          ),
        ),
      ));

      expect(find.text('42'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('Active this term'), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    testWidgets('invokes onTap when the card is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppStatCard(
            icon: Icons.people_outline,
            value: '42',
            label: 'Students',
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.text('42'));
      expect(tapped, isTrue);
    });
  });

  group('AppFilterBar', () {
    testWidgets('surfaces query changes through onChanged',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? query;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppFilterBar(
            searchController: controller,
            onChanged: (value) => query = value,
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), 'CS');
      expect(query, 'CS');
    });

    testWidgets('shows the trailing widget when provided', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppFilterBar(
            searchController: controller,
            onChanged: (_) {},
            trailing: const Icon(Icons.filter_alt_outlined),
          ),
        ),
      ));

      expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
    });
  });

  group('AppDataTable', () {
    testWidgets('renders header and row content', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppDataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Status')),
            ],
            rows: const [
              DataRow(
                cells: [
                  DataCell(Text('Alice')),
                  DataCell(Text('ACTIVE')),
                ],
              ),
            ],
          ),
        ),
      ));

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('enables horizontal scrolling on narrow screens',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppDataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Roll')),
            ],
            rows: const [
              DataRow(
                cells: [
                  DataCell(Text('Alice')),
                  DataCell(Text('ACTIVE')),
                  DataCell(Text('1')),
                ],
              ),
            ],
          ),
        ),
      ));

      expect(
        find.descendant(
          of: find.byType(AppDataTable),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });
  });
}