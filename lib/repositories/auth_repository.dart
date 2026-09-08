import '../models/auth_response.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../services/token_service.dart';

/// Logs in against the real backend `POST /api/auth/login` contract.
class AuthRepository {
  AuthRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<AuthResponse> login(String email, String password) async {
    try {
      final data = await _client.post('/auth/login', body: {
        'email': email,
        'password': password,
      }, notifyUnauthorized: false);
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return AuthResponse.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  /// Persists the obtained session (JWT -> secure storage; metadata -> prefs).
  Future<void> persistSession(AuthResponse auth) async {
    final role = auth.role ?? 'STUDENT';
    await TokenService.saveSession(
      token: auth.token,
      role: role,
      email: auth.email,
      fullName: auth.fullName,
    );
  }

  Future<void> logout() => TokenService.clearSession();
}
