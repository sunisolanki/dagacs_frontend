import 'package:flutter/foundation.dart';

import '../../repositories/auth_repository.dart';
import '../../services/token_service.dart';

/// Role-aware application session state (ChangeNotifier).
///
/// Holds the authenticated role/session, restores it on app start, and exposes
/// logout. Routing consumes [isAuthenticated] and [role] to gate screens.
///
/// Client role is informational only - the backend remains authoritative for
/// authorization.
class SessionController extends ChangeNotifier {
  SessionController(this._authRepository);

  final AuthRepository _authRepository;

  bool _initialized = false;
  bool _isAuthenticated = false;
  String _role = 'STUDENT';
  String? _email;
  String? _fullName;
  bool _mustChangePassword = false;

  bool get initialized => _initialized;
  bool get isAuthenticated => _isAuthenticated;
  String get role => _role;
  String? get email => _email;
  String? get fullName => _fullName;
  bool get mustChangePassword => _mustChangePassword;

  /// Restores a persisted session (JWT + role) after app restart.
  Future<void> restoreSession() async {
    final token = await TokenService.getToken();
    final hasToken = token != null && token.isNotEmpty;
    _isAuthenticated = hasToken;
    if (hasToken) {
      _role = await TokenService.getRole();
      _email = await TokenService.getEmail();
      _fullName = await TokenService.getFullName();
      _mustChangePassword = await TokenService.getMustChangePassword() ?? false;
    }
    _initialized = true;
    notifyListeners();
  }

  /// Marks the session authenticated (called after a successful login).
  void establishSession(String role, {String? email, String? fullName, bool mustChangePassword = false}) {
    _isAuthenticated = true;
    _role = role;
    _email = email;
    _fullName = fullName;
    _mustChangePassword = mustChangePassword;
    _initialized = true;
    notifyListeners();
  }

  /// Records a successful forced password change (M10A). The session (JWT and
  /// role) is deliberately kept - only the mustChangePassword flag clears and
  /// is persisted, so the student flows straight into the app.
  Future<void> completePasswordChange() async {
    _mustChangePassword = false;
    await TokenService.setMustChangePassword(false);
    notifyListeners();
  }

  /// Clears the JWT + session metadata and resets state (logout / 401).
  ///
  /// **Phase 5.2.** The in-memory reset is now guaranteed even if persistent
  /// storage throws, because the user has just asked to sign out: leaving
  /// [isAuthenticated] true on a storage failure is how a "logged out" user ends
  /// up still holding a live screen. Storage itself is cleared best-effort by
  /// [TokenService.clearSession].
  Future<void> clearSession() async {
    _isAuthenticated = false;
    _role = 'STUDENT';
    _email = null;
    _fullName = null;
    _mustChangePassword = false;
    try {
      await _authRepository.logout();
    } finally {
      notifyListeners();
    }
  }
}
