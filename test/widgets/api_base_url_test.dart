import 'package:dagacs_frontend/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const envApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  final expectedApiBaseUrl = envApiBaseUrl.isNotEmpty
      ? envApiBaseUrl
      : 'http://127.0.0.1:8080/api';

  group('AppConfig apiBaseUrl', () {
    test('exact value matches compile-time expectation', () {
      expect(AppConfig.apiBaseUrl, equals(expectedApiBaseUrl));
    });

    test('expected value is a valid URI', () {
      final uri = Uri.tryParse(expectedApiBaseUrl);
      expect(uri, isNotNull);
      expect(uri?.host, isNotEmpty);
    });
  });
}
