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
/// Response mapping (Phase 6):
///   - 200/201/204 -> decoded body (or null)
///   - 400/403/404/409/500 -> typed [ApiException]
///   - 401 -> typed [ApiException] AND invokes [onUnauthorized] so the app can
///     clear the expired session and route back to login.
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
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        message = (decoded['message'] as String?) ?? '';
      }
    } catch (_) {
      message = '';
    }
    switch (status) {
      case 400:
        throw ApiException(400, message.isNotEmpty ? message : 'Bad request');
      case 401:
        // A 401 on an authenticated request means the session is expired/invalid,
        // so the global onUnauthorized hook fires. Login (POST /auth/login) opts
        // out: an invalid-credentials 401 is a normal flow, not a session expiry.
        if (notifyUnauthorized) {
          onUnauthorized?.call();
        }
        throw const ApiException.unauthorized();
      case 403:
        throw const ApiException.forbidden();
      case 404:
        throw const ApiException.notFound();
      case 409:
        throw ApiException(
            409,
            message.isNotEmpty
                ? message
                : 'Request conflicts with existing data.');
      default:
        throw const ApiException.serverError();
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
