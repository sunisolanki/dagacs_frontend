import 'dart:typed_data';

import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/models/batch.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/section.dart';
import 'package:dagacs_frontend/models/student_management.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/repositories/student_management_repository.dart';
import 'package:dagacs_frontend/screens/home_screen.dart';
import 'package:dagacs_frontend/screens/student_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStudentManagementRepository extends StudentManagementRepository {
  _FakeStudentManagementRepository() : super(ApiClient());

  List<StudentManagement> students = const [];
  Object? getStudentsError;
  int getStudentsCalls = 0;

  StudentManagementRequest? lastCreateRequest;
  int? lastUpdateId;
  StudentManagementRequest? lastUpdateRequest;
  int? lastStatusId;
  String? lastStatus;

  int? lastProvisionId;
  String? lastProvisionPassword;
  int? lastLoginStatusId;
  String? lastLoginStatus;
  int? lastPasswordId;
  String? lastPassword;

  StudentImportResult? importResult;
  ApiException? importError;
  String? lastImportFilename;
  List<int>? lastImportBytes;

  @override
  Future<List<StudentManagement>> getStudents() async {
    getStudentsCalls++;
    if (getStudentsError != null) throw getStudentsError!;
    return students;
  }

  @override
  Future<StudentManagement> createStudent(
      StudentManagementRequest request) async {
    lastCreateRequest = request;
    return const StudentManagement(
        id: 99, rollNumber: '2201CE001', name: 'Rahul Kumar');
  }

  @override
  Future<StudentManagement> updateStudent(
      int id, StudentManagementRequest request) async {
    lastUpdateId = id;
    lastUpdateRequest = request;
    return StudentManagement.fromJson({
      'id': id,
      'rollNumber': request.rollNumber,
      'name': request.name,
      'status': request.status ?? 'ACTIVE',
    });
  }

  @override
  Future<StudentManagement> setStudentStatus(int id, String status) async {
    lastStatusId = id;
    lastStatus = status;
    return const StudentManagement(id: 1, status: 'INACTIVE');
  }

  @override
  Future<StudentManagement> provisionLogin(
      int id, StudentLoginPasswordRequest request) async {
    lastProvisionId = id;
    lastProvisionPassword = request.password;
    return const StudentManagement(
        id: 1, loginLinked: true, loginStatus: 'ACTIVE');
  }

  @override
  Future<StudentManagement> setLoginStatus(int id, String status) async {
    lastLoginStatusId = id;
    lastLoginStatus = status;
    return const StudentManagement(
        id: 1, loginLinked: true, loginStatus: 'INACTIVE');
  }

  @override
  Future<StudentManagement> setLoginPassword(
      int id, StudentLoginPasswordRequest request) async {
    lastPasswordId = id;
    lastPassword = request.password;
    return const StudentManagement(
        id: 1, loginLinked: true, loginStatus: 'ACTIVE');
  }

  @override
  Future<StudentImportResult> importStudents({
    required String filename,
    required List<int> bytes,
  }) async {
    lastImportFilename = filename;
    lastImportBytes = bytes;
    if (importError != null) throw importError!;
    return importResult ??
        const StudentImportResult(
            totalRows: 1, importedRows: 1, rejectedRows: 0);
  }
}

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository() : super(ApiClient());

  @override
  Future<List<Program>> getPrograms() async => const [
        Program(id: 1, name: 'Computer Science', code: 'CS'),
        Program(id: 2, name: 'Electrical', code: 'EE'),
      ];

  @override
  Future<List<Batch>> getBatches() async => const [
        Batch(id: 1, name: 'B1', batchCode: 'B1', program: 'Computer Science'),
        Batch(id: 3, name: 'B3CS', batchCode: 'B3CS', program: 'Computer Science'),
        Batch(id: 2, name: 'B2EE', batchCode: 'B2EE', program: 'Electrical'),
      ];

  @override
  Future<List<Section>> getSections() async => const [
        Section(id: 1, name: 'A', sectionCode: 'A', batchId: 1),
        Section(id: 3, name: 'C', sectionCode: 'C', batchId: 3),
        Section(id: 2, name: 'B', sectionCode: 'B', batchId: 2),
      ];
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository();
  @override
  Future<void> persistSession(AuthResponse auth) async {}
  @override
  Future<void> logout() async {}
}

const _active = StudentManagement(
  id: 1,
  rollNumber: '2201CE001',
  name: 'Rahul Kumar',
  gender: 'M',
  enrollmentNumber: 'ENR-001',
  programName: 'Computer Science',
  batchName: 'B1',
  sectionName: 'A',
  status: 'ACTIVE',
  programId: 1,
  batchId: 1,
  sectionId: 1,
);

const _inactive = StudentManagement(
  id: 2,
  rollNumber: '2201CE002',
  name: 'Anjali',
  gender: 'F',
  enrollmentNumber: 'ENR-002',
  programName: 'Electrical',
  batchName: 'B1',
  sectionName: 'B',
  status: 'INACTIVE',
  programId: 2,
  batchId: 2,
  sectionId: 2,
);

void _bigViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _wrap(StudentManagementRepository repo,
        {Future<PickedImportFile?> Function()? picker}) =>
    MaterialApp(
      home: StudentManagementScreen(
        repository: repo,
        masterDataRepository: _FakeMasterDataRepository(),
        pickImportFile: picker,
      ),
    );

Future<void> _selectDropdown(
    WidgetTester tester, Key key, String label) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders student list with details and status badges',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active, _inactive];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('student-list')), findsOneWidget);
    expect(find.textContaining('Rahul Kumar'), findsOneWidget);
    expect(find.textContaining('2201CE001'), findsOneWidget);
    expect(find.textContaining('ENR-001'), findsOneWidget);
    expect(find.textContaining('Computer Science'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('INACTIVE'), findsOneWidget);
    expect(find.text('NO LOGIN'), findsNWidgets(2));
  });

  testWidgets(
      'search filters by name case-insensitively; empty query restores all',
      (tester) async {
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active, _inactive];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('student-search')), 'rahul');
    await tester.pump();

    expect(find.textContaining('Rahul Kumar'), findsOneWidget);
    expect(find.textContaining('Anjali'), findsNothing);

    await tester.enterText(find.byKey(const Key('student-search')), '');
    await tester.pump();

    expect(find.textContaining('Rahul Kumar'), findsOneWidget);
    expect(find.textContaining('Anjali'), findsOneWidget);

    // A whitespace-only query also restores the complete list.
    await tester.enterText(find.byKey(const Key('student-search')), '   ');
    await tester.pump();
    expect(find.textContaining('Rahul Kumar'), findsOneWidget);
    expect(find.textContaining('Anjali'), findsOneWidget);
  });

  testWidgets('search matches roll number and enrollment number',
      (tester) async {
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active, _inactive];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('student-search')), '2201ce002');
    await tester.pump();
    expect(find.textContaining('Anjali'), findsOneWidget);
    expect(find.textContaining('Rahul Kumar'), findsNothing);

    await tester.enterText(find.byKey(const Key('student-search')), 'ENR-001');
    await tester.pump();
    expect(find.textContaining('Rahul Kumar'), findsOneWidget);
    expect(find.textContaining('Anjali'), findsNothing);
  });

  testWidgets('no-match search shows empty state and clear restores the list',
      (tester) async {
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active, _inactive];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('student-search')), 'zzz');
    await tester.pump();

    expect(find.text('No students match'), findsOneWidget);
    expect(find.textContaining('Rahul Kumar'), findsNothing);
    expect(find.textContaining('Anjali'), findsNothing);
    expect(find.byKey(const Key('student-search-clear')), findsOneWidget);

    await tester.tap(find.byKey(const Key('student-search-clear')));
    await tester.pump();
    expect(find.text('No students match'), findsNothing);
    expect(find.textContaining('Rahul Kumar'), findsOneWidget);
    expect(find.textContaining('Anjali'), findsOneWidget);
    expect(find.byKey(const Key('student-search-clear')), findsNothing);
  });

  testWidgets('create and status-toggle remain functional while search is active',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active, _inactive];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('student-search')), 'rahul');
    await tester.pump();

    await tester.tap(find.byKey(const Key('student-tile-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-toggle-status')));
    await tester.pumpAndSettle();
    expect(repo.lastStatusId, 1);
    expect(repo.lastStatus, 'INACTIVE');

    await tester.tap(find.byKey(const Key('add-student')));
    await tester.pumpAndSettle();
    expect(find.text('Add Student'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rahul Kumar'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    final repo = _FakeStudentManagementRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.text('No students found. Use + to add one.'), findsOneWidget);
  });

  testWidgets('shows network error and retry reloads', (tester) async {
    final repo = _FakeStudentManagementRepository();
    repo.getStudentsError = const ApiException.network();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Network error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    repo.getStudentsError = null;
    repo.students = const [_active];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rahul Kumar'), findsOneWidget);
  });

  testWidgets('shows graceful message on forbidden access', (tester) async {
    final repo = _FakeStudentManagementRepository()
      ..getStudentsError = const ApiException.forbidden();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not have access'), findsOneWidget);
  });

  testWidgets('create flow collects form and calls createStudent',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-student')));
    await tester.pumpAndSettle();
    expect(find.text('Add Student'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('field-rollNumber')), '2201CE001');
    await tester.enterText(
        find.byKey(const Key('field-name')), 'Rahul Kumar');
    await tester.enterText(
        find.byKey(const Key('field-fatherName')), 'Father');
    await tester.enterText(
        find.byKey(const Key('field-motherName')), 'Mother');
    await tester.enterText(
        find.byKey(const Key('field-enrollmentNumber')), 'ENR-001');
    await tester.enterText(find.byKey(const Key('field-age')), '20');
    await tester.enterText(
        find.byKey(const Key('field-admissionDate')), '2026-01-01');
    await _selectDropdown(tester, const Key('field-gender'), 'M');

    await tester.tap(find.byKey(const Key('submit-student')));
    await tester.pumpAndSettle();

    final request = repo.lastCreateRequest;
    expect(request, isNotNull);
    expect(request!.rollNumber, '2201CE001');
    expect(request.name, 'Rahul Kumar');
    expect(request.gender, 'M');
    expect(request.age, 20);
    expect(request.admissionDate, '2026-01-01');
    expect(request.programId, 1);
    expect(request.batchId, 1);
    expect(request.sectionId, 1);
  });

  testWidgets('default program/batch/section selection is internally consistent',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-student')));
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: find.byKey(const Key('field-batch')),
            matching: find.text('B1')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('field-section')),
            matching: find.text('A')),
        findsOneWidget);
  });

  testWidgets(
      'program change re-filters batch and section; submit uses consistent triple',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-student')));
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: find.byKey(const Key('field-batch')),
            matching: find.text('B1')),
        findsOneWidget);

    await _selectDropdown(tester, const Key('field-program'), 'Electrical');
    expect(
        find.descendant(
            of: find.byKey(const Key('field-batch')),
            matching: find.text('B2EE')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('field-section')),
            matching: find.text('B')),
        findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('field-rollNumber')), '2201EE001');
    await tester.enterText(find.byKey(const Key('field-name')), 'Priya');
    await _selectDropdown(tester, const Key('field-gender'), 'F');
    await tester.ensureVisible(find.byKey(const Key('submit-student')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-student')));
    await tester.pumpAndSettle();

    final request = repo.lastCreateRequest;
    expect(request, isNotNull);
    expect(request!.programId, 2);
    expect(request.batchId, 2);
    expect(request.sectionId, 2);
  });

  testWidgets(
      'batch change re-filters section; submit uses consistent triple',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-student')));
    await tester.pumpAndSettle();

    await _selectDropdown(tester, const Key('field-batch'), 'B3CS');
    expect(
        find.descendant(
            of: find.byKey(const Key('field-section')),
            matching: find.text('C')),
        findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('field-rollNumber')), '2201CS003');
    await tester.enterText(find.byKey(const Key('field-name')), 'Sohan');
    await _selectDropdown(tester, const Key('field-gender'), 'M');
    await tester.ensureVisible(find.byKey(const Key('submit-student')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-student')));
    await tester.pumpAndSettle();

    final request = repo.lastCreateRequest;
    expect(request, isNotNull);
    expect(request!.programId, 1);
    expect(request.batchId, 3);
    expect(request.sectionId, 3);
  });

  testWidgets('basic validation blocks empty required fields', (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-student')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-student')));
    await tester.pumpAndSettle();

    expect(find.text('Roll number is required'), findsOneWidget);
    expect(find.text('Name is required'), findsOneWidget);
    expect(repo.lastCreateRequest, isNull);
  });

  testWidgets('activate/inactivate is driven from the detail dialog',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('toggle-status-1')), findsNothing);

    await tester.tap(find.byKey(const Key('student-tile-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-toggle-status')));
    await tester.pumpAndSettle();

    expect(repo.lastStatusId, 1);
    expect(repo.lastStatus, 'INACTIVE');
  });

  testWidgets('detail dialog shows fields and can toggle status',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('student-tile-1')));
    await tester.pumpAndSettle();
    expect(find.text('Roll Number'), findsOneWidget);
    expect(find.text('Enrollment No'), findsOneWidget);
    expect(find.text('ENR-001'), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-toggle-status')));
    await tester.pumpAndSettle();

    expect(repo.lastStatusId, 1);
    expect(repo.lastStatus, 'INACTIVE');
  });

  testWidgets('detail then edit prefills form and calls updateStudent',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('student-tile-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-student')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Student'), findsOneWidget);
    expect(find.text('2201CE001'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('field-name')), 'Rahul Kumar Updated');
    await tester.ensureVisible(find.byKey(const Key('submit-student')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-student')));
    await tester.pumpAndSettle();

    expect(repo.lastUpdateId, 1);
    expect(repo.lastUpdateRequest, isNotNull);
    expect(repo.lastUpdateRequest!.name, 'Rahul Kumar Updated');
    expect(repo.lastUpdateRequest!.rollNumber, '2201CE001');
  });

  testWidgets('admin home shows Manage Students tile; student home does not',
      (tester) async {
    final masterData = _FakeMasterDataRepository();

    final adminSession = SessionController(_FakeAuthRepository());
    adminSession.establishSession('ADMIN', email: 'admin@dagacs.local');
    await tester.pumpWidget(MaterialApp(
        home: HomeScreen(session: adminSession, masterDataRepository: masterData)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-students-tile')), findsOneWidget);
    expect(find.text('Manage Students'), findsOneWidget);

    final studentSession = SessionController(_FakeAuthRepository());
    studentSession.establishSession('STUDENT');
    await tester.pumpWidget(MaterialApp(
        home: HomeScreen(session: studentSession, masterDataRepository: masterData)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-students-tile')), findsNothing);
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Manage Students'), findsNothing);
  });

  testWidgets('list shows login badges for linked and unlinked students',
      (tester) async {
    _bigViewport(tester);
    const linkedActive = StudentManagement(
        id: 3,
        rollNumber: '2201CE003',
        name: 'Zoya',
        status: 'ACTIVE',
        loginLinked: true,
        loginStatus: 'ACTIVE');
    const linkedInactive = StudentManagement(
        id: 4,
        rollNumber: '2201CE004',
        name: 'Arjun',
        status: 'ACTIVE',
        loginLinked: true,
        loginStatus: 'INACTIVE');
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active, linkedActive, linkedInactive];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('NO LOGIN'), findsOneWidget);
    expect(find.text('LOGIN ACTIVE'), findsOneWidget);
    expect(find.text('LOGIN INACTIVE'), findsOneWidget);
  });

  testWidgets(
      'detail of an unlinked student offers Create Login which provisions',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('student-tile-1')));
    await tester.pumpAndSettle();
    expect(find.text('Linked'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    expect(find.byKey(const Key('detail-create-login')), findsOneWidget);
    expect(find.byKey(const Key('detail-reset-password')), findsNothing);

    await tester.tap(find.byKey(const Key('detail-create-login')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('field-login-password')), 'StuPass#1');
    await tester.enterText(
        find.byKey(const Key('field-login-confirm')), 'StuPass#1');
    await tester.tap(find.byKey(const Key('submit-login-password')));
    await tester.pumpAndSettle();

    expect(repo.lastProvisionId, 1);
    expect(repo.lastProvisionPassword, 'StuPass#1');
  });

  testWidgets(
      'detail of a linked student offers Reset Password and Login toggle',
      (tester) async {
    _bigViewport(tester);
    const linked = StudentManagement(
        id: 1,
        rollNumber: '2201CE001',
        name: 'Rahul Kumar',
        status: 'ACTIVE',
        loginLinked: true,
        loginStatus: 'ACTIVE');
    final repo = _FakeStudentManagementRepository()..students = const [linked];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('student-tile-1')));
    await tester.pumpAndSettle();
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('Login Status'), findsOneWidget);

    // Reset password.
    await tester.tap(find.byKey(const Key('detail-reset-password')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('field-login-password')), 'NewPass#9');
    await tester.enterText(
        find.byKey(const Key('field-login-confirm')), 'NewPass#9');
    await tester.tap(find.byKey(const Key('submit-login-password')));
    await tester.pumpAndSettle();
    expect(repo.lastPasswordId, 1);
    expect(repo.lastPassword, 'NewPass#9');

    // Deactivate the login.
    await tester.tap(find.byKey(const Key('student-tile-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-toggle-login')));
    await tester.pumpAndSettle();
    expect(repo.lastLoginStatusId, 1);
    expect(repo.lastLoginStatus, 'INACTIVE');
  });

  testWidgets('password dialog enforces minimum length and matching confirm',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('student-tile-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-create-login')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('field-login-password')), 'short');
    await tester.enterText(
        find.byKey(const Key('field-login-confirm')), 'short');
    await tester.tap(find.byKey(const Key('submit-login-password')));
    await tester.pumpAndSettle();
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    expect(repo.lastProvisionId, isNull);

    await tester.enterText(
        find.byKey(const Key('field-login-password')), 'LongEnough#1');
    await tester.enterText(
        find.byKey(const Key('field-login-confirm')), 'Different#2');
    await tester.tap(find.byKey(const Key('submit-login-password')));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(repo.lastProvisionId, isNull);
  });

  testWidgets('import dialog requires a picked file before submitting',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active];
    final callCount = () => repo.getStudentsCalls;
    await tester.pumpWidget(_wrap(
      repo,
      picker: () async =>
          PickedImportFile(name: 'students.xlsx', bytes: Uint8List.fromList([1, 2, 3])),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-students')));
    await tester.pumpAndSettle();
    expect(find.text('Import Students'), findsOneWidget);
    expect(find.textContaining('Program ID'), findsOneWidget);

    // No file chosen yet - tapping submit does nothing.
    await tester.tap(find.byKey(const Key('submit-import')));
    await tester.pumpAndSettle();
    expect(repo.lastImportFilename, isNull);

    // Cancel leaves the dialog without importing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.lastImportFilename, isNull);
    expect(callCount(), 1);
  });

  testWidgets('picking null cancels and keeps the dialog clean',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active];
    await tester.pumpWidget(_wrap(repo, picker: () async => null));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-students')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-import-file')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-file-name')), findsNothing);
  });

  testWidgets('successful import shows summary and refreshes the list',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active]
      ..importResult = const StudentImportResult(
        totalRows: 2,
        importedRows: 2,
        rejectedRows: 0,
        message: 'Imported 2 of 2 students.',
      );
    await tester.pumpWidget(_wrap(
      repo,
      picker: () async =>
          PickedImportFile(name: 'students.xlsx', bytes: Uint8List.fromList([1, 2, 3])),
    ));
    await tester.pumpAndSettle();
    expect(repo.getStudentsCalls, 1);

    await tester.tap(find.byKey(const Key('import-students')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-import-file')));
    await tester.pumpAndSettle();
    expect(find.text('students.xlsx'), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-import')));
    await tester.pumpAndSettle();

    expect(repo.lastImportFilename, 'students.xlsx');
    expect(repo.lastImportBytes, [1, 2, 3]);
    expect(find.text('Import Complete'), findsOneWidget);
    expect(find.text('Imported 2 of 2 students.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-done')));
    await tester.pumpAndSettle();
    expect(find.text('Import Complete'), findsNothing);
    expect(repo.getStudentsCalls, 2);
  });

  testWidgets('rejected import shows row errors and imports nothing',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active]
      ..importResult = const StudentImportResult(
        totalRows: 3,
        importedRows: 0,
        rejectedRows: 2,
        message:
            'Import failed: 2 row(s) rejected. No students were imported.',
        errors: [
          StudentImportError(
              rowNumber: 3,
              field: 'rollNumber',
              message: 'Roll number already exists in this file: DUPR1',
              status: 409),
          StudentImportError(
              rowNumber: 2, field: 'name', message: 'Name is required', status: 400),
        ],
      );
    await tester.pumpWidget(_wrap(
      repo,
      picker: () async =>
          PickedImportFile(name: 'students.csv', bytes: Uint8List.fromList([9])),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-students')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-import-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-import')));
    await tester.pumpAndSettle();

    expect(repo.lastImportFilename, 'students.csv');
    expect(find.text('Import Failed'), findsOneWidget);
    expect(find.textContaining('No students were imported'), findsOneWidget);
    expect(find.text('Row 3:'), findsOneWidget);
    expect(find.textContaining('Roll number already exists'), findsOneWidget);
    expect(find.text('Row 2:'), findsOneWidget);
    expect(find.textContaining('Name is required'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-done')));
    await tester.pumpAndSettle();
    expect(find.text('Import Failed'), findsNothing);
    expect(repo.getStudentsCalls, 1);
  });

  testWidgets('file-level import error surfaces in the dialog', (tester) async {
    _bigViewport(tester);
    final repo = _FakeStudentManagementRepository()
      ..students = const [_active]
      ..importError = const ApiException(
          400, 'Header is missing required column(s): Email');
    await tester.pumpWidget(_wrap(
      repo,
      picker: () async =>
          PickedImportFile(name: 'students.csv', bytes: Uint8List.fromList([4, 5])),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-students')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-import-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-import')));
    await tester.pumpAndSettle();

    expect(
        find.text('Header is missing required column(s): Email'),
        findsOneWidget);
    expect(find.text('Import Failed'), findsNothing);
  });
}