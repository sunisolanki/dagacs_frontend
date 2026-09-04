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
  const ApiException.unauthorized([String msg = 'Session expired. Please sign in again.'])
      : this(401, msg);
  const ApiException.forbidden([String msg = 'You do not have permission to access this resource.'])
      : this(403, msg);
  const ApiException.notFound([String msg = 'Resource not found.'])
      : this(404, msg);
  const ApiException.conflict([String msg = 'Request conflicts with existing data.'])
      : this(409, msg);
  const ApiException.serverError([String msg = 'Server error. Please try again later.'])
      : this(500, msg);
  const ApiException.network([String msg = 'Network error. Check your connection and try again.'])
      : this(-1, msg);
}
