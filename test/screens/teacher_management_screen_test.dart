import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/teacher_management.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/repositories/teacher_management_repository.dart';
import 'package:dagacs_frontend/screens/master_data/teacher_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTeacherManagementRepository
    extends TeacherManagementRepository {
  _FakeTeacherManagementRepository() : super(ApiClient());

  List<TeacherManagement> teachers = const [];
  Object? getTeachersError;

  TeacherCreateRequest? lastCreateRequest;
  int? lastUpdateId;
  TeacherUpdateRequest? lastUpdateRequest;
  int? lastStatusId;
  String? lastStatus;
  int? lastLoginId;
  String? lastPassword;
  String? lastLoginStatusId;
  String? lastLoginStatus;
  int? lastHodTeacherId;
  TeacherHodDesignationRequest? lastHodRequest;

  @override
  Future<List<TeacherManagement>> getTeachers() async {
    if (getTeachersError != null) throw getTeachersError!;
    return teachers;
  }

  @override
  Future<TeacherManagement> createTeacher(TeacherCreateRequest request) async {
    lastCreateRequest = request;
    return TeacherManagement.fromJson({
      'id': 99,
      'email': request.email,
      'fullName': request.fullName,
      'status': request.status ?? 'ACTIVE',
    });
  }

  @override
  Future<TeacherManagement> updateTeacher(
      int id, TeacherUpdateRequest request) async {
    lastUpdateId = id;
    lastUpdateRequest = request;
    return TeacherManagement.fromJson({
      'id': id,
      'fullName': request.fullName ?? 'Updated',
    });
  }

  @override
  Future<TeacherManagement> setTeacherStatus(int id, String status) async {
    lastStatusId = id;
    lastStatus = status;
    return TeacherManagement.fromJson({'id': id, 'status': status});
  }

  @override
  Future<TeacherManagement> provisionLogin(
      int id, TeacherLoginPasswordRequest request) async {
    lastLoginId = id;
    lastPassword = request.password;
    return TeacherManagement.fromJson(
        {'id': id, 'loginLinked': true, 'loginStatus': 'ACTIVE'});
  }

  @override
  Future<TeacherManagement> setLoginPassword(
      int id, TeacherLoginPasswordRequest request) async {
    lastLoginId = id;
    lastPassword = request.password;
    return TeacherManagement.fromJson(
        {'id': id, 'loginLinked': true, 'loginStatus': 'ACTIVE'});
  }

  @override
  Future<TeacherManagement> setLoginStatus(int id, String status) async {
    lastLoginStatusId = '$id';
    lastLoginStatus = status;
    return TeacherManagement.fromJson(
        {'id': id, 'loginLinked': true, 'loginStatus': status});
  }

  @override
  Future<HodIdentity> designateHod(
      int teacherId, TeacherHodDesignationRequest request) async {
    lastHodTeacherId = teacherId;
    lastHodRequest = request;
    return HodIdentity.fromJson({
      'email': 'hod@dagacs.local',
      'teacherName': 'HOD Teacher',
      'hod': true,
      'departmentName': 'Computer Science',
      'departmentCode': 'CSE',
    });
  }
}

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository() : super(ApiClient());

  @override
  Future<List<Department>> getDepartments() async => const [
        Department(id: 1, name: 'Computer Science', code: 'CS'),
        Department(id: 2, name: 'Electronics', code: 'EC'),
      ];
}

const _withLogin = TeacherManagement(
  id: 1,
  email: 'meera@dagacs.local',
  fullName: 'Meera Iyer',
  designation: 'Professor',
  departmentName: 'Computer Science',
  status: 'ACTIVE',
  isHod: true,
  loginLinked: true,
  loginStatus: 'ACTIVE',
);

const _noLogin = TeacherManagement(
  id: 2,
  email: 'kiran@dagacs.local',
  fullName: 'Kiran Rao',
  designation: 'Lecturer',
  departmentName: 'Electronics',
  status: 'INACTIVE',
  isHod: false,
  loginLinked: false,
  loginStatus: null,
);

void _bigViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _wrap(TeacherManagementRepository repo) => MaterialApp(
      home: TeacherListScreen(
        repository: repo,
        masterDataRepository: _FakeMasterDataRepository(),
      ),
    );

void main() {
  testWidgets('renders teacher list with profile and login badges',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeTeacherManagementRepository()
      ..teachers = const [_withLogin, _noLogin];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('teacher-list')), findsOneWidget);
    expect(find.textContaining('Meera Iyer'), findsOneWidget);
    expect(find.textContaining('Kiran Rao'), findsOneWidget);
    expect(find.textContaining('meera@dagacs.local'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('INACTIVE'), findsOneWidget);
    expect(find.text('LOGIN ACTIVE'), findsOneWidget);
    expect(find.text('NO LOGIN'), findsOneWidget);
    expect(find.text('HOD'), findsOneWidget);
  });

  testWidgets('search filters by name/email/designation and restores on clear',
      (tester) async {
    final repo = _FakeTeacherManagementRepository()
      ..teachers = const [_withLogin, _noLogin];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('teacher-search')), 'meera');
    await tester.pump();
    expect(find.textContaining('Meera Iyer'), findsOneWidget);
    expect(find.textContaining('Kiran Rao'), findsNothing);

    await tester.enterText(find.byKey(const Key('teacher-search')), 'kiran@');
    await tester.pump();
    expect(find.textContaining('Kiran Rao'), findsOneWidget);
    expect(find.textContaining('Meera Iyer'), findsNothing);

    await tester.tap(find.byKey(const Key('teacher-search-clear')));
    await tester.pump();
    expect(find.textContaining('Meera Iyer'), findsOneWidget);
    expect(find.textContaining('Kiran Rao'), findsOneWidget);
  });

  testWidgets('no-match search shows empty state', (tester) async {
    final repo = _FakeTeacherManagementRepository()
      ..teachers = const [_withLogin];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('teacher-search')), 'zzz');
    await tester.pump();
    expect(find.text('No teachers match'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    final repo = _FakeTeacherManagementRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.text('No teachers found. Use + to add one.'), findsOneWidget);
  });

  testWidgets('shows network error and retry reloads', (tester) async {
    final repo = _FakeTeacherManagementRepository()
      ..getTeachersError = const ApiException.network();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Network error'), findsOneWidget);

    repo.getTeachersError = null;
    repo.teachers = const [_withLogin];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Meera Iyer'), findsOneWidget);
  });

  testWidgets('shows graceful message on forbidden access', (tester) async {
    final repo = _FakeTeacherManagementRepository()
      ..getTeachersError = const ApiException.forbidden();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not have access'), findsOneWidget);
  });

  testWidgets('create flow collects form including password and calls create',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeTeacherManagementRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-teacher')));
    await tester.pumpAndSettle();
    expect(find.text('Add Teacher'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('field-email')), 'new@dagacs.local');
    await tester.enterText(
        find.byKey(const Key('field-fullName')), 'New Teacher');
    await tester.enterText(
        find.byKey(const Key('field-designation')), 'Assoc Professor');
    await tester.enterText(
        find.byKey(const Key('field-password')), 'Pass1234');
    await tester.enterText(
        find.byKey(const Key('field-confirmPassword')), 'Pass1234');
    await tester.tap(find.byKey(const Key('field-department')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Electronics').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submit-teacher')));
    await tester.pumpAndSettle();

    final request = repo.lastCreateRequest;
    expect(request, isNotNull);
    expect(request!.email, 'new@dagacs.local');
    expect(request.fullName, 'New Teacher');
    expect(request.designation, 'Assoc Professor');
    expect(request.departmentId, 2);
    expect(request.password, 'Pass1234');
    expect(request.status, 'ACTIVE');
  });

  testWidgets('create validation blocks empty required fields',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeTeacherManagementRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-teacher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-teacher')));
    await tester.pumpAndSettle();

    expect(find.text('This field is required'), findsOneWidget);
    expect(find.text('Full name is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(repo.lastCreateRequest, isNull);
  });

  testWidgets('create validation blocks mismatched passwords', (tester) async {
    _bigViewport(tester);
    final repo = _FakeTeacherManagementRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-teacher')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('field-email')), 'new@dagacs.local');
    await tester.enterText(
        find.byKey(const Key('field-fullName')), 'New Teacher');
    await tester.enterText(
        find.byKey(const Key('field-password')), 'Pass1234');
    await tester.enterText(
        find.byKey(const Key('field-confirmPassword')), 'Different');
    await tester.tap(find.byKey(const Key('submit-teacher')));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(repo.lastCreateRequest, isNull);
  });

  testWidgets('detail dialog shows profile and login facts', (tester) async {
    _bigViewport(tester);
    final repo = _FakeTeacherManagementRepository()
      ..teachers = const [_withLogin];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacher-tile-1')));
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('meera@dagacs.local'), findsOneWidget);
    expect(find.text('Login Account'), findsOneWidget);
    expect(find.text('Linked'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.byKey(const Key('detail-reset-password')), findsOneWidget);
    expect(find.byKey(const Key('detail-toggle-login')), findsOneWidget);
    expect(find.byKey(const Key('detail-demote-hod')), findsOneWidget);
    expect(find.byKey(const Key('detail-designate-hod')), findsNothing);
  });

  testWidgets('create login flow calls provisionLogin', (tester) async {
    _bigViewport(tester);
    final repo = _FakeTeacherManagementRepository()
      ..teachers = const [_noLogin];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacher-tile-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-create-login')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('field-login-password')), 'Pass1234');
    await tester.enterText(
        find.byKey(const Key('field-login-confirm')), 'Pass1234');
    await tester.tap(find.byKey(const Key('submit-login-password')));
    await tester.pumpAndSettle();

    expect(repo.lastLoginId, 2);
    expect(repo.lastPassword, 'Pass1234');
    expect(repo.lastLoginStatus, isNull);
  });

  testWidgets('reset password flow calls setLoginPassword', (tester) async {
    _bigViewport(tester);
    final repo = _FakeTeacherManagementRepository()
      ..teachers = const [_withLogin];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacher-tile-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-reset-password')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('field-login-password')), 'NewPass12');
    await tester.enterText(
        find.byKey(const Key('field-login-confirm')), 'NewPass12');
    await tester.tap(find.byKey(const Key('submit-login-password')));
    await tester.pumpAndSettle();

    expect(repo.lastLoginId, 1);
    expect(repo.lastPassword, 'NewPass12');
  });

  testWidgets('toggle login status calls setLoginStatus', (tester) async {
    _bigViewport(tester);
    final repo = _FakeTeacherManagementRepository()
      ..teachers = const [_withLogin];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacher-tile-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-toggle-login')));
    await tester.pumpAndSettle();

    expect(repo.lastLoginStatusId, '1');
    expect(repo.lastLoginStatus, 'INACTIVE');
  });

  testWidgets('designate HOD picks a department and calls designateHod',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeTeacherManagementRepository()
      ..teachers = const [_noLogin];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacher-tile-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-designate-hod')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('field-hod-department')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Computer Science').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submit-designate-hod')));
    await tester.pumpAndSettle();

    expect(repo.lastHodTeacherId, 2);
    expect(repo.lastHodRequest, isNotNull);
    expect(repo.lastHodRequest!.designated, isTrue);
    expect(repo.lastHodRequest!.departmentId, 1);
  });

  testWidgets('demote HOD requires confirmation and calls designateHod(false)',
      (tester) async {
    _bigViewport(tester);
    final repo = _FakeTeacherManagementRepository()
      ..teachers = const [_withLogin];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacher-tile-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-demote-hod')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Remove HOD designation'), findsNothing);
    // Cancel does nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.lastHodTeacherId, isNull);

    await tester.tap(find.byKey(const Key('teacher-tile-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-demote-hod')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-demote-hod')));
    await tester.pumpAndSettle();

    expect(repo.lastHodTeacherId, 1);
    expect(repo.lastHodRequest!.designated, isFalse);
  });

  testWidgets('detail edit prefills and calls updateTeacher', (tester) async {
    _bigViewport(tester);
    final repo = _FakeTeacherManagementRepository()
      ..teachers = const [_withLogin];
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('teacher-tile-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-edit-teacher')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Teacher'), findsOneWidget);
    expect(find.textContaining('Meera Iyer'), findsWidgets);

    await tester.enterText(
        find.byKey(const Key('field-fullName')), 'Meera Iyer Updated');
    await tester.ensureVisible(find.byKey(const Key('submit-teacher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-teacher')));
    await tester.pumpAndSettle();

    expect(repo.lastUpdateId, 1);
    expect(repo.lastUpdateRequest, isNotNull);
    expect(repo.lastUpdateRequest!.fullName, 'Meera Iyer Updated');
    expect(repo.lastUpdateRequest!.departmentId, isNull);
  });
}