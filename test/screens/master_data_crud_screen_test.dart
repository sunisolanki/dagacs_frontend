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
  bool failReads = false;
  bool failDelete = false;
  DepartmentRequest? lastCreateRequest;
  DepartmentRequest? lastUpdateRequest;
  int? lastDeleteId;
  int? lastUpdateId;

  @override
  Future<List<Department>> getDepartments() async {
    if (failReads) throw const ApiException.forbidden();
    return List.of(_departments);
  }

  @override
  Future<Department> createDepartment(DepartmentRequest request) async {
    lastCreateRequest = request;
    final created = Department(
      id: 99,
      name: request.name,
      code: request.code,
      description: request.description,
    );
    _departments = [..._departments, created];
    return created;
  }

  @override
  Future<Department> updateDepartment(int id, DepartmentRequest request) async {
    lastUpdateId = id;
    lastUpdateRequest = request;
    final updated = Department(
      id: id,
      name: request.name,
      code: request.code,
      description: request.description,
    );
    _departments = [
      for (final d in _departments) d.id == id ? updated : d,
    ];
    return updated;
  }

  @override
  Future<void> deleteDepartment(int id) async {
    lastDeleteId = id;
    if (failDelete) {
      throw const ApiException(
          409, 'Cannot delete department. Program(s) exist: CSE');
    }
    _departments = _departments.where((d) => d.id != id).toList();
  }
}

Widget _wrap(MasterDataRepository repository) {
  return MaterialApp(home: DepartmentListScreen(repository: repository));
}

void main() {
  testWidgets('lists departments with edit and delete actions', (tester) async {
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
  });

  testWidgets('shows the empty placeholder when there are no records',
      (tester) async {
    final repo = _FakeMasterDataRepository(const []);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('department-empty')), findsOneWidget);
    expect(find.text('No departments yet. Use + to add one.'), findsOneWidget);
  });

  testWidgets('shows an error message with retry on load failure',
      (tester) async {
    final repo = _FakeMasterDataRepository(const [])
      ..failReads = true;
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(
        find.text('You are not authorized to perform this action.'),
        findsOneWidget);

    repo.failReads = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('department-empty')), findsOneWidget);
  });

  testWidgets('create flow opens the form and refreshes the list on success',
      (tester) async {
    final repo = _FakeMasterDataRepository(const [
      Department(id: 1, name: 'Computer Science', code: 'CS'),
    ]);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('department-add')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('field-name')), 'Mechanical');
    await tester.enterText(find.byKey(const Key('field-code')), 'ME');
    await tester.tap(find.byKey(const Key('submit-department')));
    await tester.pumpAndSettle();

    expect(repo.lastCreateRequest, isNotNull);
    expect(repo.lastCreateRequest!.name, 'Mechanical');
    expect(repo.lastCreateRequest!.code, 'ME');
    expect(repo.lastCreateRequest!.description, isNull);
    expect(find.byKey(const Key('department-tile-99')), findsOneWidget);
    expect(find.text('Mechanical'), findsOneWidget);
  });

  testWidgets('validation blocks submit when required fields are empty',
      (tester) async {
    final repo = _FakeMasterDataRepository(const []);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('department-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submit-department')));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Code is required'), findsOneWidget);
    expect(repo.lastCreateRequest, isNull);
  });

  testWidgets('edit flow prefills and saves updates', (tester) async {
    final repo = _FakeMasterDataRepository(const [
      Department(id: 1, name: 'Computer Science', code: 'CS'),
    ]);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('department-edit-1')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Department'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Computer Science').evaluate(),
        isNotEmpty);

    await tester.enterText(find.byKey(const Key('field-name')), 'CSE dept');
    await tester.tap(find.byKey(const Key('submit-department')));
    await tester.pumpAndSettle();

    expect(repo.lastUpdateId, 1);
    expect(repo.lastUpdateRequest!.name, 'CSE dept');
    expect(repo.lastUpdateRequest!.code, 'CS');
    expect(find.text('CSE dept'), findsOneWidget);
  });

  testWidgets('delete asks for confirmation, then removes and refreshes',
      (tester) async {
    final repo = _FakeMasterDataRepository(const [
      Department(id: 1, name: 'Computer Science', code: 'CS'),
      Department(id: 2, name: 'Electronics', code: 'EC'),
    ]);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('department-delete-2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete "Electronics"? This cannot be undone.'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('department-confirm-delete')));
    await tester.pumpAndSettle();

    expect(repo.lastDeleteId, 2);
    expect(find.byKey(const Key('department-tile-2')), findsNothing);
    expect(find.byKey(const Key('department-tile-1')), findsOneWidget);
  });

  testWidgets('cancelling the delete confirmation keeps the record',
      (tester) async {
    final repo = _FakeMasterDataRepository(const [
      Department(id: 1, name: 'Computer Science', code: 'CS'),
    ]);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('department-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.lastDeleteId, isNull);
    expect(find.byKey(const Key('department-tile-1')), findsOneWidget);
  });

  testWidgets('a 409 delete explains that a referenced record cannot be removed',
      (tester) async {
    final repo = _FakeMasterDataRepository(const [
      Department(id: 1, name: 'Computer Science', code: 'CS'),
    ])
      ..failDelete = true;
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('department-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('department-confirm-delete')));
    await tester.pump();

    expect(
        find.text('Unable to delete this record because it is being used elsewhere.'),
        findsOneWidget);
    expect(find.byKey(const Key('department-tile-1')), findsOneWidget);
  });

  testWidgets('client-side search filters already-loaded records', (tester) async {
    final repo = _FakeMasterDataRepository(const [
      Department(id: 1, name: 'Computer Science', code: 'CS'),
      Department(id: 2, name: 'Electronics', code: 'EC'),
    ]);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('department-search')), 'elect');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('department-tile-1')), findsNothing);
    expect(find.byKey(const Key('department-tile-2')), findsOneWidget);
  });
}
