import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Centralized API base URL configuration for the DAGACS mobile app.
///
/// Not a single production URL is hardcoded here. The value is resolved from
/// (in order of precedence):
///  1. --dart-define=API_BASE_URL=... (physical devices / any environment)
///  2. A platform-aware development default:
///       - Android emulator -> http://10.0.2.2:8080/api (emulator loopback to host)
///       - web / desktop / iOS simulator -> http://127.0.0.1:8080/api
///
/// The `--dart-define=API_BASE_URL` override is authoritative and always wins.
/// Physical devices MUST provide it because the fallbacks above resolve to the
/// development machine's own loopback, which is unreachable from a real
/// device. For local development against a machine on the LAN use
/// `--dart-define=API_BASE_URL=http://<lan-ip>:8080/api`; production builds
/// MUST use an HTTPS URL (e.g. `https://<prod-host>/api`). No automatic
/// network/address discovery is performed.
///
/// All API calls MUST go through this configuration so that URLs are never
/// scattered across screens.
class AppConfig {
  AppConfig._();

  static const String _fromEnv = String.fromEnvironment('API_BASE_URL');

  /// Returns a fully-qualified API base (including the `/api` prefix).
  static String get apiBaseUrl {
    if (_fromEnv.isNotEmpty) {
      return _fromEnv;
    }
    final host = _defaultHost();
    return 'http://$host:8080/api';
  }

  static String _defaultHost() {
    if (!kIsWeb && Platform.isAndroid) {
      // Android emulator maps host loopback to 10.0.2.2.
      return '10.0.2.2';
    }
    return '127.0.0.1';
  }
}
