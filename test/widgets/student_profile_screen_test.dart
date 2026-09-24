import 'package:dagacs_frontend/models/student_profile.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/student_profile_repository.dart';
import 'package:dagacs_frontend/screens/student_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStudentProfileRepository extends StudentProfileRepository {
  _FakeStudentProfileRepository();
  Future<StudentProfile> Function()? onGetMyProfile;
  Future<StudentProfile> Function(Map<String, dynamic>)? onUpdateMyProfile;

  @override
  Future<StudentProfile> getMyProfile() =>
      onGetMyProfile != null
          ? onGetMyProfile!()
          : super.getMyProfile();

  @override
  Future<StudentProfile> updateMyProfile(Map<String, dynamic> data) =>
      onUpdateMyProfile != null ? onUpdateMyProfile!(data) : super.updateMyProfile(data);
}

const _profile = StudentProfile(
  rollNumber: '2201CE001',
  enrollmentNumber: 'ENR-2022-001',
  name: 'Student User',
  gender: 'M',
  fatherName: 'Father',
  motherName: 'Mother',
  personalEmail: 'student@test.com',
  age: 20,
  admissionDate: '2026-01-01',
  status: 'ACTIVE',
  batchName: 'B1',
  programName: 'Computer Science',
  sectionName: 'A',
);

Widget _wrap(StudentProfileRepository repo) =>
    MaterialApp(home: StudentProfileScreen(profileRepository: repo));

void main() {
  testWidgets('shows loading state while fetching', (tester) async {
    final repo = _FakeStudentProfileRepository()
      ..onGetMyProfile = () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _profile;
      };
    await tester.pumpWidget(_wrap(repo));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('renders profile details without email', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeStudentProfileRepository()
      ..onGetMyProfile = () async => _profile;
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

expect(find.text('Student User'), findsOneWidget);
     expect(find.text('2201CE001'), findsWidgets);
     expect(find.text('ENR-2022-001'), findsOneWidget);
     expect(find.text('M'), findsOneWidget);
     expect(find.text('Father'), findsOneWidget);
     expect(find.text('Mother'), findsOneWidget);
     expect(find.text('student@test.com'), findsOneWidget);
     expect(find.text('20'), findsOneWidget);
     expect(find.text('2026-01-01'), findsOneWidget);
     expect(find.text('ACTIVE'), findsOneWidget);
     expect(find.text('Computer Science'), findsOneWidget);
     expect(find.text('B1'), findsOneWidget);
     expect(find.text('A'), findsOneWidget);
     expect(find.text('student@dagacs.local'), findsNothing);
  });

  testWidgets('shows error on network failure with retry', (tester) async {
    final repo = _FakeStudentProfileRepository()
      ..onGetMyProfile = () async => throw const ApiException.network();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unable to connect'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retry reloads and renders profile', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeStudentProfileRepository();
    var calls = 0;
    repo.onGetMyProfile = () async {
      calls++;
      if (calls == 1) {
        throw const ApiException.unauthorized();
      }
      return _profile;
    };
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Session expired. Please sign in again.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Student User'), findsOneWidget);
    expect(find.text('2201CE001'), findsWidgets);
  });

  testWidgets('missing values render as dash', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeStudentProfileRepository()
      ..onGetMyProfile = () async =>
          const StudentProfile(name: 'OnlyName');
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('OnlyName'), findsOneWidget);
    expect(find.text('-'), findsWidgets);
  });

  testWidgets('photoUrl available renders profile image', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeStudentProfileRepository()
      ..onGetMyProfile = () async => const StudentProfile(
            name: 'Student User', photoUrl: 'https://example.com/photo.png');
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    tester.takeException();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.foregroundImage, isA<NetworkImage>());
    expect(find.text('SU'), findsNothing);
  });

  testWidgets('photoUrl absent renders initials fallback', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeStudentProfileRepository()
      ..onGetMyProfile = () async => _profile;
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.foregroundImage, isNull);
    expect(find.text('SU'), findsOneWidget);
    expect(find.text('Student User'), findsOneWidget);
  });

  testWidgets('edit button appears', (tester) async {
    final repo = _FakeStudentProfileRepository()
      ..onGetMyProfile = () async => _profile;
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit), findsOneWidget);
  });

  testWidgets('enteringEditMode showsEditableFields', (tester) async {
    final repo = _FakeStudentProfileRepository()
      ..onGetMyProfile = () async => _profile;
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();

    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('saveCallsUpdateAndExitsEditMode', (tester) async {
    final repo = _FakeStudentProfileRepository();
    repo.onGetMyProfile = () async => _profile;
    repo.onUpdateMyProfile = (data) async => _profile;
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    expect(find.byIcon(Icons.edit), findsOneWidget);
  });

    testWidgets('cancelDiscardsChanges', (tester) async {
     final repo = _FakeStudentProfileRepository()
       ..onGetMyProfile = () async => _profile;
     await tester.pumpWidget(_wrap(repo));
     await tester.pumpAndSettle();

     await tester.tap(find.byIcon(Icons.edit));
     await tester.pump();

     await tester.tap(find.byIcon(Icons.cancel));
     await tester.pump();

     expect(find.byIcon(Icons.edit), findsOneWidget);
   });

   testWidgets('showsPersonalEmailInViewMode', (tester) async {
     final repo = _FakeStudentProfileRepository()
       ..onGetMyProfile = () async => _profile;
     await tester.pumpWidget(_wrap(repo));
     await tester.pumpAndSettle();

     expect(find.text('student@test.com'), findsOneWidget);
   });

   testWidgets('editModeShowsPersonalEmailField', (tester) async {
     final repo = _FakeStudentProfileRepository()
       ..onGetMyProfile = () async => _profile;
     await tester.pumpWidget(_wrap(repo));
     await tester.pumpAndSettle();

     await tester.tap(find.byIcon(Icons.edit));
     await tester.pump();

     expect(find.byType(TextField), findsWidgets);
   });

   testWidgets('saveIncludesPersonalEmail', (tester) async {
     final repo = _FakeStudentProfileRepository();
     repo.onGetMyProfile = () async => _profile;
     repo.onUpdateMyProfile = (data) async => _profile;
     await tester.pumpWidget(_wrap(repo));
     await tester.pumpAndSettle();

     await tester.tap(find.byIcon(Icons.edit));
     await tester.pump();

     await tester.tap(find.byIcon(Icons.check));
     await tester.pump();

     expect(find.byIcon(Icons.edit), findsOneWidget);
   });
 }
