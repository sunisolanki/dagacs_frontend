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

  @override
  Future<List<StudentManagement>> getStudents() async {
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
}

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository() : super(ApiClient());

  @override
  Future<List<Program>> getPrograms() async => const [
        Program(id: 1, name: 'Computer Science', code: 'CS'),
        Program(id: 2, name: 'Electrical', code: 'EE'),
      ];

  @override
  Future<List<Batch>> getBatches() async =>
      const [Batch(id: 1, name: 'B1', batchCode: 'B1')];

  @override
  Future<List<Section>> getSections() async =>
      const [Section(id: 1, name: 'A', sectionCode: 'A')];
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

Widget _wrap(StudentManagementRepository repo) => MaterialApp(
      home: StudentManagementScreen(
        repository: repo,
        masterDataRepository: _FakeMasterDataRepository(),
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
}