import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the JWT in secure storage and non-secret session metadata
/// (role/email/fullName) in SharedPreferences.
///
/// The token is NEVER stored in plaintext source, shared constants, debug
/// logs, or Git-tracked files - it lives only in the platform secure store.
class TokenService {
  TokenService._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _tokenKey = 'access_token';
  static const String _roleKey = 'user_role';
  static const String _emailKey = 'user_email';
  static const String _fullNameKey = 'user_full_name';
  static const String _mustChangePasswordKey = 'must_change_password';

  static Future<void> saveSession(
      {required String token,
      required String role,
      String? email,
      String? fullName,
      bool mustChangePassword = false}) async {
    await _secureStorage.write(key: _tokenKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
    if (email != null) {
      await prefs.setString(_emailKey, email);
    }
    if (fullName != null) {
      await prefs.setString(_fullNameKey, fullName);
    }
    await prefs.setBool(_mustChangePasswordKey, mustChangePassword);
  }

  static Future<bool?> getMustChangePassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_mustChangePasswordKey);
  }

  /// Persists the forced password-change flag (M10A). Called after a successful
  /// change so routing no longer forces the change screen, while the JWT and
  /// the rest of the session stay intact.
  static Future<void> setMustChangePassword(bool mustChangePassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mustChangePasswordKey, mustChangePassword);
  }

  static Future<String?> getToken() async {
    return _secureStorage.read(key: _tokenKey);
  }

  static Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey) ?? 'STUDENT';
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<String?> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fullNameKey);
  }

  /// Removes every trace of the session.
  ///
  /// **Phase 5.2.** This previously left [\_mustChangePasswordKey] behind while
  /// removing everything else, so a "clear the session" that did not clear the
  /// session was possible. Each removal is independent: a failure on one key
  /// must not leave the JWT in place, because a lingering token is the one
  /// outcome that keeps a signed-out user signed in.
  static Future<void> clearSession() async {
    await _ignoreFailure(() => _secureStorage.delete(key: _tokenKey));
    final prefs = await _prefsOrNull();
    if (prefs == null) return;
    for (final key in [
      _roleKey,
      _emailKey,
      _fullNameKey,
      _mustChangePasswordKey,
    ]) {
      await _ignoreFailure(() => prefs.remove(key));
    }
  }

  /// SharedPreferences access that degrades instead of throwing.
  ///
  /// Storage can be unavailable (a platform channel not registered, a corrupt
  /// store). A session clear must still finish rather than leave a half-signed-in
  /// state behind.
  static Future<SharedPreferences?> _prefsOrNull() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _ignoreFailure(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Best effort. The caller is clearing state, and failing loudly here would
      // strand the user in a worse state than the one being cleaned up.
    }
  }
}
