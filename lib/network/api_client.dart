import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/token_service.dart';
import 'api_exception.dart';

/// M9.14: bounded standard API timeout - every JSON request must terminate
/// within this window or surface a typed timeout error (never an infinite
/// spinner). Chosen well above observed sub-second response times.
const Duration kStandardRequestTimeout = Duration(seconds: 15);

/// M9.14: bounded file-transfer timeout for exports (`getBytes`) and the
/// bulk student import (`postMultipart`) - user-initiated ops that may take
/// longer server-side, but still never hang indefinitely.
const Duration kFileTransferTimeout = Duration(seconds: 60);

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
    Duration? timeout,
    Duration? fileTimeout,
  })  : _http = httpClient ?? http.Client(),
        _tokenProvider = tokenProvider ?? _defaultTokenProvider,
        timeout = timeout ?? kStandardRequestTimeout,
        fileTimeout = fileTimeout ?? kFileTransferTimeout;

  final http.Client _http;
  final Future<String?> Function() _tokenProvider;
  final void Function()? onUnauthorized;
  final String baseUrl;

  final Duration timeout;
  final Duration fileTimeout;

  String get _base => baseUrl.isNotEmpty ? baseUrl : AppConfig.apiBaseUrl;

  static Future<String?> _defaultTokenProvider() => TokenService.getToken();

  /// M9.14: applies ONE overall time budget to a complete request operation.
  ///
  /// Token acquisition, connect, request send and full response-body
  /// consumption all share a single hard ceiling, so the operation as a whole
  /// can never exceed [budget] (a per-phase chain would allow n independent
  /// windows). A [TimeoutException] propagates to the caller's typed handling.
  Future<T> _runWithinBudget<T>(Future<T> Function() operation, Duration budget) {
    return operation().timeout(budget);
  }

  Future<dynamic> get(String path) => _send('GET', path);

  /// Issues an authenticated GET that preserves the raw binary body and
  /// response headers (used for M7.2 file exports).
  ///
  /// Returns the raw [http.Response] on success so the caller can read
  /// `bodyBytes` and `Content-Disposition`. Non-2xx statuses go through the
  /// exact same mapping as [get]/[_send] (including the 401 logout hook).
  Future<http.Response> getBytes(String path) async {
    final uri = Uri.parse('$_base$path');

    http.Response response;
    try {
      // One 60s budget for the whole operation: token + send + full body read.
      response = await _runWithinBudget(() async {
        final token = await _tokenProvider();
        final headers = <String, String>{};
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
        final request = http.Request('GET', uri)..headers.addAll(headers);
        final streamed = await _http.send(request);
        return http.Response.fromStream(streamed);
      }, fileTimeout);
    } on TimeoutException {
      // M9.14: a bounded timeout is a connectivity problem, not a session
      // problem - no onUnauthorized, no logout.
      throw const ApiException.timeout();
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
      {bool notifyUnauthorized = true, bool isLoginRequest = false}) {
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
        // M9.14: login 429 (isLoginRequest) preserves M9.6 M cooldown
        // semantics - backend's own user-safe message preferred, fixed fallback,
        // never onUnauthorized, never logout. Any OTHER 429 is a generic
        // throttle: fixed noise-free wording, no login language, no logout.
        if (isLoginRequest) {
          throw ApiException(
              429,
              message.isNotEmpty ? message : kTooManyRequestsMessage,
              code: code);
        }
        throw ApiException(429, kRateLimitedMessage, code: code);
      default:
        throw ApiException(500, kServerErrorMessage, code: code);
    }
  }

  Future<dynamic> post(String path,
          {Object? body,
          bool notifyUnauthorized = true,
          bool isLoginRequest = false}) =>
      _send('POST', path,
          body: body,
          notifyUnauthorized: notifyUnauthorized,
          isLoginRequest: isLoginRequest);

  /// Posts an authenticated multipart/form-data request with a single file part
  /// (M9.10 bulk student import).
  ///
  /// The backend attaches the file to the {@code file} part and derives the
  /// import format from the file name extension, so no content type is set
  /// here. Non-2xx statuses map through the exact same [ApiException] logic as
  /// [_send] (including the 401 logout hook and 409 conflict handling).
  Future<dynamic> postMultipart(
    String path, {
    required String field,
    required String filename,
    required List<int> bytes,
    Map<String, dynamic>? params,
  }) async {
    final uri = Uri.parse('$_base$path').replace(
        queryParameters: params != null && params.isNotEmpty
            ? {...params.map((k, v) => MapEntry(k, v.toString()))}
            : {});

    http.Response response;
    try {
      // One 60s budget for the whole operation: token + multipart upload +
      // full response-body read.
      response = await _runWithinBudget(() async {
        final token = await _tokenProvider();
        final request = http.MultipartRequest('POST', uri);
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
        request.files.add(
            http.MultipartFile.fromBytes(field, bytes, filename: filename));
        final streamed = await _http.send(request);
        return http.Response.fromStream(streamed);
      }, fileTimeout);
    } on TimeoutException {
      // M9.14: bounded timeout, connectivity problem - typed, never logout.
      throw const ApiException.timeout();
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

    _throwForStatus(status, response);
  }

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path,
      {Object? body,
      bool notifyUnauthorized = true,
      bool isLoginRequest = false}) async {
    final uri = Uri.parse('$_base$path');

    http.Response response;
    try {
      // One 15s budget for the whole operation: token + connect + send +
      // full response-body read - not two independent phases.
      response = await _runWithinBudget(() async {
        final token = await _tokenProvider();
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
        final request = http.Request(method, uri)..headers.addAll(headers);
        if (body != null) {
          request.body = jsonEncode(body);
        }
        final streamed = await _http.send(request);
        return http.Response.fromStream(streamed);
      }, timeout);
    } on TimeoutException {
      // M9.14: a bounded timeout is a connectivity problem, never a session
      // problem - no onUnauthorized, no logout.
      throw const ApiException.timeout();
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

    _throwForStatus(status, response,
        notifyUnauthorized: notifyUnauthorized,
        isLoginRequest: isLoginRequest);
  }
}
