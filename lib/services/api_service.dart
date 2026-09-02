import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8080/api';

  static Future<http.Response> get(String path) async {
    final url = '$baseUrl$path';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load: ${response.statusCode}');
    }
    return response;
  }

  static Future<http.Response> post(String path, {dynamic body}) async {
    final url = '$baseUrl$path';
    final response = await http.post(Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body != null ? jsonEncode(body) : null);
    if (response.statusCode != 200) {
      throw Exception('Failed to ${response.statusCode}: $path');
    }
    return response;
  }

  static Future<http.Response> put(String path, {dynamic body}) async {
    final url = '$baseUrl$path';
    final response = await http.put(Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body != null ? jsonEncode(body) : null);
    if (response.statusCode != 200) {
      throw Exception('Failed to ${response.statusCode}: $path');
    }
    return response;
  }

  static Future<http.Response> patch(String path, {dynamic body}) async {
    final url = '$baseUrl$path';
    final response = await http.patch(Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body != null ? jsonEncode(body) : null);
    if (response.statusCode != 200) {
      throw Exception('Failed to ${response.statusCode}: $path');
    }
    return response;
  }

  static Future<http.Response> delete(String path) async {
    final url = '$baseUrl$path';
    final response = await http.delete(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to ${response.statusCode}: $path');
    }
    return response;
  }
}