import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository();
  @override
  Future<void> persistSession(AuthResponse auth) async {}
  @override
  Future<void> logout() async {}
}

void main() {
  test('initially unauthenticated with STUDENT default', () {
    final session = SessionController(_FakeAuthRepository());
    expect(session.initialized, isFalse);
    expect(session.isAuthenticated, isFalse);
    expect(session.role, 'STUDENT');
  });

  test('establishSession sets authenticated role and metadata', () {
    final session = SessionController(_FakeAuthRepository());
    session.establishSession('HOD', email: 'hod@dagacs.local', fullName: 'HOD');
    expect(session.isAuthenticated, isTrue);
    expect(session.role, 'HOD');
    expect(session.email, 'hod@dagacs.local');
    expect(session.fullName, 'HOD');
  });

  test('establishSession sets mustChangePassword flag', () {
    final session = SessionController(_FakeAuthRepository());
    session.establishSession('STUDENT',
        email: 's@dagacs.local',
        fullName: 'Student',
        mustChangePassword: true);
    expect(session.mustChangePassword, isTrue);
  });

  test('establishSession defaults mustChangePassword to false', () {
    final session = SessionController(_FakeAuthRepository());
    session.establishSession('ADMIN');
    expect(session.mustChangePassword, isFalse);
  });

  test('clearSession resets to unauthenticated and notifies listeners', () async {
    final session = SessionController(_FakeAuthRepository());
    var notified = 0;
    session.addListener(() => notified++);
    session.establishSession('TEACHER',
        mustChangePassword: true);
    expect(session.mustChangePassword, isTrue);
    await session.clearSession();
    expect(session.isAuthenticated, isFalse);
    expect(session.role, 'STUDENT');
    expect(session.email, isNull);
    expect(session.mustChangePassword, isFalse);
    expect(notified, greaterThanOrEqualTo(2));
  });
}
