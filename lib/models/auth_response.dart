/// Matches backend `AuthResponse` (AuthController / AuthService.login).
class AuthResponse {
  final String token;
  final String? email;
  final String? fullName;
  final String? role;
  final bool mustChangePassword;

  const AuthResponse({
    required this.token,
    this.email,
    this.fullName,
    this.role,
    this.mustChangePassword = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String? ?? '',
      email: json['email'] as String?,
      fullName: json['fullName'] as String?,
      role: json['role'] as String?,
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
    );
  }
}
