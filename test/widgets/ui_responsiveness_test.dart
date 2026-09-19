import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/academic_session.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/models/batch.dart';
import 'package:dagacs_frontend/models/department.dart';
import 'package:dagacs_frontend/models/program.dart';
import 'package:dagacs_frontend/models/section.dart';
import 'package:dagacs_frontend/models/semester.dart';
import 'package:dagacs_frontend/models/student_management.dart';
import 'package:dagacs_frontend/models/subject.dart';
import 'package:dagacs_frontend/models/subject_offering.dart';
import 'package:dagacs_frontend/models/teacher.dart';
import 'package:dagacs_frontend/models/teacher_assignment.dart';
import 'package:dagacs_frontend/models/teacher_management.dart';
import 'package:dagacs_frontend/network/api_client.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:dagacs_frontend/repositories/master_data_repository.dart';
import 'package:dagacs_frontend/repositories/student_management_repository.dart';
import 'package:dagacs_frontend/repositories/teacher_management_repository.dart';
import 'package:dagacs_frontend/screens/home_screen.dart';
import 'package:dagacs_frontend/screens/login_screen.dart';
import 'package:dagacs_frontend/screens/master_data/department_list_screen.dart';
import 'package:dagacs_frontend/screens/master_data_screen.dart';
import 'package:dagacs_frontend/screens/student_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository();
  @override
  Future<void> persistSession(AuthResponse auth) async {}
  @override
  Future<void> logout() async {}
}

class _FakeMasterDataRepository extends MasterDataRepository {
  _FakeMasterDataRepository() : super(ApiClient());

  @override
  Future<List<Department>> getDepartments() async => const [
        Department(id: 1, name: 'Computer Science', code: 'CS'),
        Department(id: 2, name: 'Electronics', code: 'EC'),
      ];

  @override
  Future<List<Program>> getPrograms() async =>
      const [Program(id: 1, name: 'B.Tech CSE', code: 'CS')];

  @override
  Future<List<AcademicSession>> getAcademicSessions() async =>
      const [AcademicSession(id: 1, name: '2026-27', code: 'S1')];

  @override
  Future<List<Semester>> getSemesters() async =>
      const [Semester(id: 1, name: 'Semester 1', code: 'S1')];

  @override
  Future<List<Semester>> getSemestersBySession(int sessionId) async =>
      const [Semester(id: 1, name: 'Semester 1', code: 'S1')];

  @override
  Future<List<Batch>> getBatches() async =>
      const [Batch(id: 1, name: 'B1', batchCode: 'B1', academicSessionId: 1)];

  @override
  Future<List<Section>> getSections() async =>
      const [Section(id: 1, name: 'A', sectionCode: 'A')];

  @override
  Future<List<Subject>> getSubjects() async =>
      const [Subject(id: 1, code: 'CS301', name: 'DBMS')];

  @override
  Future<List<SubjectOffering>> getSubjectOfferings() async =>
      const [SubjectOffering(id: 1, subjectId: 1, semesterId: 1)];

  @override
  Future<List<TeacherAssignment>> getTeacherAssignments() async =>
      const [TeacherAssignment(id: 1, teacherId: 1, subjectOfferingId: 1, sectionId: 1)];

  @override
  Future<List<Teacher>> getTeachers() async =>
      const [Teacher(id: 1, fullName: 'Dr A Sharma')];
}

class _FakeTeacherManagementRepository extends TeacherManagementRepository {
  _FakeTeacherManagementRepository() : super(ApiClient());

  @override
  Future<List<TeacherManagement>> getTeachers() async => const [
        TeacherManagement(
            id: 5,
            email: 'teacher@dagacs.local',
            fullName: 'Dr A Sharma',
            status: 'ACTIVE'),
      ];
}

class _FakeStudentManagementRepository extends StudentManagementRepository {
  _FakeStudentManagementRepository() : super(ApiClient());

  @override
  Future<StudentFilterOptionsData> getFilterOptions({
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? batchId,
    int? sectionId,
  }) async =>
      const StudentFilterOptionsData();

  @override
  Future<StudentPage> searchStudents(StudentSearchQuery query) async {
    return StudentPage(
      content: [
        StudentManagement.fromJson({
          'id': 1,
          'rollNumber': '2201CE001',
          'enrollmentNumber': 'ENR-2026-0001',
          'name': 'Rahul Kumar Singh',
          'programName': 'Computer Science and Engineering',
          'academicSessionName': '2026-27',
          'semesterName': 'Sem 1',
          'batchName': '2026 Batch Alpha',
          'sectionName': 'Section Alpha',
          'status': 'ACTIVE',
          'academicSessionId': 1,
          'programId': 1,
          'semesterId': 1,
          'batchId': 1,
          'sectionId': 1,
        }),
      ],
      page: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
    );
  }
}

const _sizes = <Size>[
  Size(320, 600), // narrow phone
  Size(800, 600), // tablet
  Size(1280, 800), // desktop
];

Future<void> _atSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pump();
}

SessionController _session(String role) {
  final session = SessionController(_FakeAuthRepository());
  session.establishSession(role);
  return session;
}

Widget _home(String role) {
  return MaterialApp(
    home: HomeScreen(session: _session(role), masterDataRepository: _FakeMasterDataRepository()),
  );
}

Widget _masterHub() {
  return MaterialApp(
    home: MasterDataScreen(
      session: _session('ADMIN'),
      repository: _FakeMasterDataRepository(),
      teacherManagementRepository: _FakeTeacherManagementRepository(),
    ),
  );
}

Widget _departmentCrud() {
  return MaterialApp(
    home: DepartmentListScreen(repository: _FakeMasterDataRepository()),
  );
}

Widget _students() {
  return MaterialApp(
    home: StudentManagementScreen(
      repository: _FakeStudentManagementRepository(),
      masterDataRepository: _FakeMasterDataRepository(),
    ),
  );
}

void main() {
  group('premium UI responsiveness', () {
    for (final size in _sizes) {
      testWidgets('login renders without overflow at ${size.width.toInt()}px',
          (tester) async {
        await _atSize(tester, size);
        await tester.pumpWidget(MaterialApp(
          home: LoginScreen(
            authRepository: _FakeAuthRepository(),
            session: _session('STUDENT'),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.byKey(const Key('login-identifier')), findsOneWidget);
        expect(find.byKey(const Key('login-password')), findsOneWidget);
      });

      testWidgets('ADMIN home renders without overflow at ${size.width.toInt()}px',
          (tester) async {
        await _atSize(tester, size);
        await tester.pumpWidget(_home('ADMIN'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('admin-master-data-tile')), findsOneWidget);
        expect(find.byKey(const Key('admin-students-tile')), findsOneWidget);
        expect(find.text('Manage Students'), findsOneWidget);
      });

      testWidgets('TEACHER home renders without overflow at ${size.width.toInt()}px',
          (tester) async {
        await _atSize(tester, size);
        await tester.pumpWidget(_home('TEACHER'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Attendance'), findsOneWidget);
        expect(find.byKey(const Key('teacher-reports-tile')), findsOneWidget);
      });

      testWidgets('master data hub renders without overflow at ${size.width.toInt()}px',
          (tester) async {
        await _atSize(tester, size);
        await tester.pumpWidget(_masterHub());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('master-data-departments')), findsOneWidget);
        expect(find.byKey(const Key('master-data-subjects')), findsOneWidget);
        expect(find.text('1 record'), findsWidgets);
      });

      testWidgets('department crud renders without overflow at ${size.width.toInt()}px',
          (tester) async {
        await _atSize(tester, size);
        await tester.pumpWidget(_departmentCrud());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('department-tile-1')), findsOneWidget);
        expect(find.byKey(const Key('department-list')), findsOneWidget);
      });

      testWidgets('student list renders without overflow at ${size.width.toInt()}px',
          (tester) async {
        await _atSize(tester, size);
        await tester.pumpWidget(_students());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('student-tile-1')), findsOneWidget);
        expect(find.text('ACTIVE'), findsOneWidget);
      });

      if (size.width <= 320) {
        testWidgets('student form dialog opens without overflow at 320px',
            (tester) async {
          await _atSize(tester, size);
          await tester.pumpWidget(_students());
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('add-student')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Add Student'), findsOneWidget);
          expect(find.byKey(const Key('submit-student')), findsOneWidget);
        });

        testWidgets('department form dialog opens without overflow at 320px',
            (tester) async {
          await _atSize(tester, size);
          await tester.pumpWidget(_departmentCrud());
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('department-add')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Add Department'), findsOneWidget);
          expect(find.byKey(const Key('submit-department')), findsOneWidget);
        });
      }
    }
  });
}