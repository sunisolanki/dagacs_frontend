import 'dart:typed_data';

import 'report_file_downloader_io.dart'
    if (dart.library.html) 'report_file_downloader_web.dart' as impl;

/// Signature used by report/export screens for platform-aware downloads.
typedef ReportFileDownloader = Future<String> Function(
    Uint8List bytes, String fileName, String? contentType);

/// Saves/triggers a download for an M7.2 export file in a platform-appropriate
/// way:
///   - Flutter Web: browser download through `dart:html` (backend file name and
///     content type preserved).
///   - Android/native: writes the bytes to an app-local temp file via
///     `dart:io` and returns a user-facing status string.
///
/// Screens that need to observe the outcome (or test without touching the
/// platform) should take a [ReportFileDownloader] callback instead of using
/// this default directly; this is the default handler wired into the app.
Future<String> downloadReportFile(
  Uint8List bytes,
  String fileName,
  String? contentType,
) {
  return impl.downloadReportFile(bytes, fileName, contentType);
}