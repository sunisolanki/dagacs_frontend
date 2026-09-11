import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/token_service.dart';
import 'api_exception.dart';

/// Centralized authenticated HTTP client.
///
/// Every request automatically attaches `Authorization: Bearer <JWT>` - the
/// token logic lives here only, never duplicated across screens.
///
/// Response mapping (Phase 6 / M9.5.4):
///   - 200/201/204 -> decoded body (or null)
///   - 400/403/404/409/429/500 -> typed [ApiException] (carrying the backend
///     machine-readable [ApiException.code] when the body had one)
///   - 429 -> typed [ApiException] with a fixed safe message; NEVER a logout
///     trigger (M9.6 M - a rate-limited login is not a session problem)
///   - 401 -> typed [ApiException]. Only a 401 WITHOUT an identity-resolution
///     code (invalid/expired JWT, D5) invokes [onUnauthorized] to clear the
///     session and route back to login. A 401 WITH a profile code keeps the
///     user signed in - their session is valid but their profile is unusable.
///   - network failure -> [ApiException.network]
class ApiClient {
  ApiClient({
    http.Client? httpClient,
    Future<String?> Function()? tokenProvider,
    this.onUnauthorized,
    this.baseUrl = '',
  })  : _http = httpClient ?? http.Client(),
        _tokenProvider = tokenProvider ?? _defaultTokenProvider;

  final http.Client _http;
  final Future<String?> Function() _tokenProvider;
  final void Function()? onUnauthorized;
  final String baseUrl;

  String get _base => baseUrl.isNotEmpty ? baseUrl : AppConfig.apiBaseUrl;

  static Future<String?> _defaultTokenProvider() => TokenService.getToken();

  Future<dynamic> get(String path) => _send('GET', path);

  /// Issues an authenticated GET that preserves the raw binary body and
  /// response headers (used for M7.2 file exports).
  ///
  /// Returns the raw [http.Response] on success so the caller can read
  /// `bodyBytes` and `Content-Disposition`. Non-2xx statuses go through the
  /// exact same mapping as [get]/[_send] (including the 401 logout hook).
  Future<http.Response> getBytes(String path) async {
    final uri = Uri.parse('$_base$path');
    final token = await _tokenProvider();
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;
    try {
      final request = http.Request('GET', uri)..headers.addAll(headers);
      final streamed = await _http.send(request);
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      throw const ApiException.network();
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return response;
    }
    _throwForStatus(status, response);
  }

  Never _throwForStatus(int status, http.Response response,
      {bool notifyUnauthorized = true}) {
    String message = '';
    String? code;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        message = (decoded['message'] as String?) ?? '';
        code = (decoded['code'] as String?)?.trim();
        if (code != null && code.isEmpty) code = null;
      }
    } catch (_) {
      message = '';
    }
    switch (status) {
      case 400:
        throw ApiException(400, message.isNotEmpty ? message : 'Bad request',
            code: code);
      case 401:
        // A code-less 401 on an authenticated request means the JWT is
        // expired/invalid, so the global logout hook fires (D5). A 401 WITH an
        // identity-resolution code means the profile behind a VALID session is
        // missing/inactive: no logout - the user stays signed in and sees the
        // actionable reason instead. Login (POST /auth/login) opts out of the
        // hook entirely: an invalid-credentials 401 is a normal flow.
        // Raw body text is never surfaced (M7.5): the message is the fixed
        // session-expired string, or the standardized identity message when an
        // identity code was present.
        if (notifyUnauthorized && !isIdentityResolutionCode(code)) {
          onUnauthorized?.call();
        }
        throw ApiException(
            401,
            messageForIdentityCode(code) ?? kSessionExpiredMessage,
            code: code);
      case 403:
        throw ApiException(403, kNotAuthorizedMessage, code: code);
      case 404:
        throw ApiException(404, kNotFoundMessage, code: code);
      case 409:
        throw ApiException(
            409,
            message.isNotEmpty
                ? message
                : 'Request conflicts with existing data.',
            code: code);
      case 429:
        // M9.6 M: login rate limited. Never a session problem - no
        // onUnauthorized, no logout. Prefer the backend's own (already
        // user-safe) message, fall back to the fixed string otherwise.
        throw ApiException(
            429,
            message.isNotEmpty ? message : kTooManyRequestsMessage,
            code: code);
      default:
        throw ApiException(500, kServerErrorMessage, code: code);
    }
  }

  Future<dynamic> post(String path, {Object? body, bool notifyUnauthorized = true}) =>
      _send('POST', path, body: body, notifyUnauthorized: notifyUnauthorized);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path,
      {Object? body, bool notifyUnauthorized = true}) async {
    final uri = Uri.parse('$_base$path');

    final token = await _tokenProvider();

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) {
        request.body = jsonEncode(body);
      }
      final streamed = await _http.send(request);
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      throw const ApiException.network();
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (status == 204 || response.body.trim().isEmpty) {
        return null;
      }
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    }

    _throwForStatus(status, response, notifyUnauthorized: notifyUnauthorized);
  }
}
