/// Typed application-level errors mapped from backend HTTP responses.
///
/// Backend stack traces / internal exception details are NEVER surfaced to the
/// user - this class only carries an HTTP-ish status, a safe user-facing
/// message, and (when present) the backend's stable machine-readable [code]
/// (M9.5.4). Profile-resolution codes let the app tell "your profile is not
/// usable" apart from "your session expired" - only the latter requires a
/// logout.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  /// Stable backend error code (e.g. `TEACHER_PROFILE_INACTIVE`), when the
  /// response carried one. Null for anonymous/structural errors.
  final String? code;

  const ApiException(this.statusCode, this.message, {this.code});

  @override
  String toString() => 'ApiException($statusCode): $message'
      '${code == null ? '' : ' [$code]'}';

  /// Convenience factories for common cases.
  const ApiException.badRequest([String msg = 'Bad request'])
      : this(400, msg);
  const ApiException.unauthorized([String msg = kSessionExpiredMessage])
      : this(401, msg);
  const ApiException.forbidden([String msg = kNotAuthorizedMessage])
      : this(403, msg);
  const ApiException.notFound([String msg = kNotFoundMessage])
      : this(404, msg);
  const ApiException.conflict([String msg = 'Request conflicts with existing data.'])
      : this(409, msg);
  const ApiException.tooManyRequests([String msg = kTooManyRequestsMessage])
      : this(429, msg);
  const ApiException.serverError([String msg = kServerErrorMessage])
      : this(500, msg);
  const ApiException.network([String msg = kNetworkErrorMessage])
      : this(-1, msg);
  const ApiException.timeout([String msg = kTimeoutMessage])
      : this(kTimeoutStatusCode, msg);
}

/// Standardized, user-safe message strings (M7.5 hardening). Raw backend
/// exception text is never rendered to the user.
const String kNetworkErrorMessage =
    'Unable to connect. Check your internet connection.';
const String kNotAuthorizedMessage =
    'You are not authorized to perform this action.';
const String kNotFoundMessage = 'Requested data was not found.';
const String kServerErrorMessage = 'Something went wrong. Please try again.';
const String kSessionExpiredMessage =
    'Session expired. Please sign in again.';

/// M9.6 M: rate-limited login attempts short-circuit with HTTP 429. This is NOT
/// a session problem, so the client must never treat it like a 401/logout.
const String kTooManyRequestsMessage =
    'Too many login attempts. Please wait and try again later.';

/// M9.14: a request exceeded its bounded timeout. This is a connectivity
/// problem, never a session problem - the user is never logged out.
const int kTimeoutStatusCode = -2;
const String kTimeoutMessage =
    'Request timed out. Please check your connection and try again.';

/// M9.14: non-login HTTP 429 (throttled request that is not the login
/// endpoint). Generic wording - never the login-cooldown text.
const String kRateLimitedMessage =
    'Too many requests. Please wait a moment and try again.';

/// Stable backend identity-resolution codes (D5, M9.5.4).
///
/// A 401 carrying any of these means the *profile* behind the (valid) JWT is
/// missing or unusable - the session itself is fine, so the app must NOT log
/// the user out. Only code-less 401s (invalid/expired JWT) trigger logout.
const List<String> kIdentityResolutionCodes = [
  'UNABLE_TO_RESOLVE_IDENTITY',
  'TEACHER_PROFILE_NOT_LINKED',
  'TEACHER_PROFILE_INACTIVE',
  'STUDENT_PROFILE_NOT_LINKED',
  'STUDENT_PROFILE_INACTIVE',
  'HOD_PROFILE_NOT_LINKED',
  'HOD_PROFILE_INACTIVE',
  'HOD_NOT_DESIGNATED',
  'HOD_NO_DEPARTMENT',
];

/// True when [code] is a known identity/profile-resolution code.
bool isIdentityResolutionCode(String? code) =>
    code != null && kIdentityResolutionCodes.contains(code);

/// Actionable, role-aware message for an identity-resolution [code], or null
/// when the code is unknown/absent.
String? messageForIdentityCode(String? code) {
  switch (code) {
    case 'TEACHER_PROFILE_NOT_LINKED':
      return 'Your account is not linked to a Teacher profile. Contact your '
          'administrator.';
    case 'TEACHER_PROFILE_INACTIVE':
      return 'Your Teacher profile is inactive. Contact your administrator to '
          'reactivate it.';
    case 'STUDENT_PROFILE_NOT_LINKED':
      return 'Your account is not linked to a Student profile. Contact your '
          'administrator.';
    case 'STUDENT_PROFILE_INACTIVE':
      return 'Your Student profile is inactive. Contact your administrator to '
          'reactivate it.';
    case 'HOD_PROFILE_NOT_LINKED':
      return 'Your account is not linked to a HOD profile. Contact your '
          'administrator.';
    case 'HOD_PROFILE_INACTIVE':
      return 'Your HOD profile is inactive. Contact your administrator to '
          'reactivate it.';
    case 'HOD_NOT_DESIGNATED':
      return 'You are not designated as a HOD. Contact your administrator.';
    case 'HOD_NO_DEPARTMENT':
      return 'Your HOD account is not linked to any department. Contact your '
          'administrator.';
    case 'UNABLE_TO_RESOLVE_IDENTITY':
      return 'Your sign-in could not be resolved to a known role. Contact '
          'your administrator.';
    default:
      return null;
  }
}

/// Maps an [ApiException] to its standardized user-facing message.
///
/// Identity-resolution 401 codes keep the user signed in and show WHY the
/// profile cannot be used (D5). 400/409 retain their (already user-safe)
/// backend validation text; every other status uses the fixed strings above so
/// raw backend text is never surfaced.
String userMessageFor(ApiException e) {
  final identityMessage = messageForIdentityCode(e.code);
  if (identityMessage != null) return identityMessage;
  switch (e.statusCode) {
    case 401:
      return kSessionExpiredMessage;
    case 403:
      return kNotAuthorizedMessage;
    case 404:
      return kNotFoundMessage;
    case 429:
      // M9.14: the message is set at throw time in ApiClient - the login
      // branch carries the login cooldown wording, every other 429 carries the
      // generic rate-limit text. An unknown/empty 429 falls back to the generic
      // throttle, never the login wording.
      return e.message.isNotEmpty ? e.message : kRateLimitedMessage;
    case kTimeoutStatusCode:
      return kTimeoutMessage;
    case -1:
      return kNetworkErrorMessage;
    default:
      if (e.statusCode >= 500) return kServerErrorMessage;
      return e.message.isNotEmpty ? e.message : kServerErrorMessage;
  }
}
