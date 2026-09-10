import 'dart:async';

import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/screens/master_data/department_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository(this._departments) : super(ApiClient());

  List<Department> _departments;
  Completer<List<Department>>? gate;
  ApiException? loadError;

  @override
  Future<List<Department>> getDepartments() async {
    if (gate != null) return gate!.future;
    if (loadError != null) throw loadError!;
    return List.of(_departments);
  }
}

Widget _wrap(MasterDataRepository repository) {
  return MaterialApp(home: DepartmentListScreen(repository: repository));
}

const _sizes = <Size>[
  Size(320, 720),
  Size(390, 844),
  Size(480, 800),
  Size(768, 1024),
  Size(1024, 768),
  Size(1280, 800),
  Size(1440, 900),
];

Future<void> _atSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pump();
}

void main() {
  testWidgets('shows a dedicated loading state while the list loads',
      (tester) async {
    final repo = _FakeMasterDataRepository(const [
      Department(id: 1, name: 'Computer Science', code: 'CS'),
    ])
      ..gate = Completer<List<Department>>();
    await tester.pumpWidget(_wrap(repo));
    await tester.pump();

    expect(find.text('Loading Departments...'), findsOneWidget);

    repo.gate!.complete(const []);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('department-empty')), findsOneWidget);
  });

  testWidgets('search with no matches shows the distinct empty message',
      (tester) async {
    final repo = _FakeMasterDataRepository(const [
      Department(id: 1, name: 'Computer Science', code: 'CS'),
      Department(id: 2, name: 'Electronics', code: 'EC'),
    ]);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('department-search')), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No departments match your search.'), findsOneWidget);
    expect(find.byKey(const Key('department-empty')), findsNothing);
    expect(find.byKey(const Key('department-tile-1')), findsNothing);
  });

  testWidgets('a server failure shows a friendly error and Retry recovers',
      (tester) async {
    final repo = _FakeMasterDataRepository(const [
      Department(id: 1, name: 'Computer Science', code: 'CS'),
    ])
      ..loadError = const ApiException.serverError();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Please try again.'),
        findsOneWidget);

    repo.loadError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('department-tile-1')), findsOneWidget);
  });

  testWidgets('an offline failure shows the network message and Retry recovers',
      (tester) async {
    final repo = _FakeMasterDataRepository(const [
      Department(id: 1, name: 'Computer Science', code: 'CS'),
    ])
      ..loadError = const ApiException.network();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(
        find.text('Unable to connect. Check your internet connection.'),
        findsOneWidget);

    repo.loadError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('department-tile-1')), findsOneWidget);
  });

  testWidgets('the delete confirmation stays usable at narrow widths',
      (tester) async {
    for (final width in [320, 390, 480]) {
      await _atSize(tester, Size(width.toDouble(), 800));
      await tester.pumpWidget(const SizedBox());
      final repo = _FakeMasterDataRepository(const [
        Department(id: 1, name: 'Computer Science', code: 'CS'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('department-delete-1')));
      await tester.pumpAndSettle();

      expect(
          find.textContaining(
              'Delete "Computer Science"? This cannot be undone.'),
          findsOneWidget);
      expect(
          find.byKey(const Key('department-confirm-delete')), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    }
  });

  testWidgets('the list layout stays responsive from 320 to 1440',
      (tester) async {
    for (final size in _sizes) {
      await _atSize(tester, size);
      await tester.pumpWidget(const SizedBox());
      final repo = _FakeMasterDataRepository(const [
        Department(id: 1, name: 'Computer Science', code: 'CS'),
        Department(id: 2, name: 'Electronics', code: 'EC'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('department-tile-1')), findsOneWidget);
      expect(find.byKey(const Key('department-tile-2')), findsOneWidget);
      expect(find.byKey(const Key('department-edit-1')), findsOneWidget);
      expect(find.byKey(const Key('department-delete-1')), findsOneWidget);
      expect(find.byKey(const Key('department-add')), findsOneWidget);
      expect(find.byKey(const Key('department-search')), findsOneWidget);
    }
  });
}