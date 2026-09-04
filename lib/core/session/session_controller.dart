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

  bool get initialized => _initialized;
  bool get isAuthenticated => _isAuthenticated;
  String get role => _role;
  String? get email => _email;
  String? get fullName => _fullName;

  /// Restores a persisted session (JWT + role) after app restart.
  Future<void> restoreSession() async {
    final token = await TokenService.getToken();
    final hasToken = token != null && token.isNotEmpty;
    _isAuthenticated = hasToken;
    if (hasToken) {
      _role = await TokenService.getRole();
      _email = await TokenService.getEmail();
      _fullName = await TokenService.getFullName();
    }
    _initialized = true;
    notifyListeners();
  }

  /// Marks the session authenticated (called after a successful login).
  void establishSession(String role, {String? email, String? fullName}) {
    _isAuthenticated = true;
    _role = role;
    _email = email;
    _fullName = fullName;
    _initialized = true;
    notifyListeners();
  }

  /// Clears the JWT + session metadata and resets state (logout / 401).
  Future<void> clearSession() async {
    await _authRepository.logout();
    _isAuthenticated = false;
    _role = 'STUDENT';
    _email = null;
    _fullName = null;
    notifyListeners();
  }
}
