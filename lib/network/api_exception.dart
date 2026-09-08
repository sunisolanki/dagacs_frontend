/// Typed application-level errors mapped from backend HTTP responses.
///
/// Backend stack traces / internal exception details are NEVER surfaced to the
/// user - this class only carries an HTTP-ish status and a safe, user-facing
/// message.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';

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
  const ApiException.serverError([String msg = kServerErrorMessage])
      : this(500, msg);
  const ApiException.network([String msg = kNetworkErrorMessage])
      : this(-1, msg);
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

/// Maps an [ApiException] to its standardized user-facing message.
///
/// 400/409 retain their (already user-safe) backend validation text; every
/// other status uses the fixed strings above so raw backend text is never
/// surfaced.
String userMessageFor(ApiException e) {
  switch (e.statusCode) {
    case 401:
      return kSessionExpiredMessage;
    case 403:
      return kNotAuthorizedMessage;
    case 404:
      return kNotFoundMessage;
    case -1:
      return kNetworkErrorMessage;
    default:
      if (e.statusCode >= 500) return kServerErrorMessage;
      return e.message.isNotEmpty ? e.message : kServerErrorMessage;
  }
}
