import 'package:dagacs_frontend/models/student_profile.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/student_profile_repository.dart';
import 'package:dagacs_frontend/screens/student_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStudentProfileRepository extends StudentProfileRepository {
  _FakeStudentProfileRepository();
  Future<StudentProfile> Function()? onGetMyProfile;

  @override
  Future<StudentProfile> getMyProfile() =>
      onGetMyProfile != null
          ? onGetMyProfile!()
          : super.getMyProfile();
}

const _profile = StudentProfile(
  rollNumber: '2201CE001',
  enrollmentNumber: 'ENR-2022-001',
  email: 'student@dagacs.local',
  name: 'Student User',
  gender: 'M',
  fatherName: 'Father',
  motherName: 'Mother',
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

  testWidgets('renders profile details', (tester) async {
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
    expect(find.text('student@dagacs.local'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('Father'), findsOneWidget);
    expect(find.text('Mother'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('2026-01-01'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Computer Science'), findsOneWidget);
    expect(find.text('B1'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
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
}