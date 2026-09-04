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

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, {Object? body}) async {
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
        onUnauthorized?.call();
        throw ApiException(
            401,
            message.isNotEmpty
                ? message
                : 'Session expired. Please sign in again.');
      case 403:
        throw ApiException(
            403,
            message.isNotEmpty
                ? message
                : 'You do not have permission to access this resource.');
      case 404:
        throw ApiException(404,
            message.isNotEmpty ? message : 'Resource not found.');
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
}
