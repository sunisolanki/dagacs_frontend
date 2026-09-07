import 'package:dagacs_frontend/core/session/session_controller.dart';
import 'package:dagacs_frontend/models/auth_response.dart';
import 'package:dagacs_frontend/repositories/auth_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stub AuthRepository that records whether persistSession/logout were called.
class _RecordingAuthRepository extends AuthRepository {
  _RecordingAuthRepository();
  bool persistedSession = false;
  bool loggedOut = false;
  AuthResponse? lastPersistedAuth;

  @override
  Future<void> persistSession(AuthResponse auth) async {
    persistedSession = true;
    lastPersistedAuth = auth;
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
  }
}

/// Sets up mock platform channel responses for FlutterSecureStorage
/// so that TokenService.getToken() returns the provided token.
///
/// SharedPreferences is mocked via SharedPreferences.setMockInitialValues
/// which is the standard Flutter test approach for testing SharedPreferences
/// without requiring native platform plugins.
void _mockPlatformChannels(String? token) {
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  final messenger = TestDefaultBinaryMessengerBinding.instance
      .defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    secureStorageChannel,
    (MethodCall call) async {
      switch (call.method) {
        case 'write':
          return null;
        case 'read':
          // FlutterSecureStorage.read passes arguments as Map<String, String>
          final args = call.arguments as Map;
          final key = args['key'] as String;
          if (key == 'access_token') {
            return token;
          }
          return null;
        case 'delete':
          return null;
        default:
          return null;
      }
    },
  );

  // Mock SharedPreferences via setMockInitialValues.
  // This must be called before SharedPreferences.getInstance() is called.
  SharedPreferences.setMockInitialValues({
    'user_role': 'TEACHER',
    'user_email': 'teacher@dagacs.local',
    'user_full_name': 'Teacher',
  });
}

/// Clears all mock platform channel handlers.
void _clearMockPlatformChannels() {
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger = TestDefaultBinaryMessengerBinding.instance
      .defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(secureStorageChannel, null);
}

void main() {
  group('SessionController Web-compatible session restoration', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDownAll(() {
      _clearMockPlatformChannels();
    });

    test('restoreSession restores authenticated state from token',
        () async {
      _mockPlatformChannels('test-jwt');

      final repo = _RecordingAuthRepository();
      final session = SessionController(repo);

      // Actually call restoreSession() — this exercises the real
      // TokenService.getToken(), getRole(), getEmail(), getFullName()
      // calls that restoreSession() uses internally.
      await session.restoreSession();

      expect(session.initialized, isTrue);
      expect(session.isAuthenticated, isTrue);
      expect(session.role, 'TEACHER');
      expect(session.email, 'teacher@dagacs.local');
      expect(session.fullName, 'Teacher');
    });

    test('restoreSession with no token starts unauthenticated', () async {
      SharedPreferences.setMockInitialValues({});
      _mockPlatformChannels(null);

      final repo = _RecordingAuthRepository();
      final session = SessionController(repo);

      // Actually call restoreSession() when no token is stored.
      await session.restoreSession();

      expect(session.initialized, isTrue);
      expect(session.isAuthenticated, isFalse);
      expect(session.role, 'STUDENT');
      expect(session.email, isNull);
      expect(session.fullName, isNull);
    });

    test('clearSession resets to unauthenticated and notifies listeners',
        () async {
      final repo = _RecordingAuthRepository();
      final session = SessionController(repo);
      var notified = 0;
      session.addListener(() => notified++);
      session.establishSession('TEACHER');
      await session.clearSession();
      expect(session.isAuthenticated, isFalse);
      expect(session.role, 'STUDENT');
      expect(session.email, isNull);
      expect(notified, greaterThanOrEqualTo(2));
    });

    test('establishSession preserves role and metadata', () {
      final repo = _RecordingAuthRepository();
      final session = SessionController(repo);

      session.establishSession('HOD',
          email: 'hod@dagacs.local', fullName: 'HOD User');
      expect(session.isAuthenticated, isTrue);
      expect(session.role, 'HOD');
      expect(session.email, 'hod@dagacs.local');
      expect(session.fullName, 'HOD User');
    });

    test('clearSession calls repository logout and resets state', () async {
      final repo = _RecordingAuthRepository();
      final session = SessionController(repo);

      session.establishSession('TEACHER');
      expect(session.isAuthenticated, isTrue);
      expect(repo.persistedSession, isFalse);

      await session.clearSession();
      expect(session.isAuthenticated, isFalse);
      expect(session.role, 'STUDENT');
      expect(repo.loggedOut, isTrue);
    });

    test('role-based access gates are preserved', () {
      final repo = _RecordingAuthRepository();
      final session = SessionController(repo);

      session.establishSession('TEACHER');
      expect(session.role, 'TEACHER');
      expect(session.isAuthenticated, isTrue);

      session.establishSession('STUDENT');
      expect(session.role, 'STUDENT');
      expect(session.isAuthenticated, isTrue);

      session.establishSession('ADMIN');
      expect(session.role, 'ADMIN');
      expect(session.isAuthenticated, isTrue);
    });
  });
}
