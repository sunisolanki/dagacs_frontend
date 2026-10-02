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
///   - Android/iOS/desktop: writes the bytes to a directory the user can
///     actually reach - the shared Downloads folder where one exists, otherwise
///     the app's documents - and then offers the platform share sheet.
///
/// **Phase 5.1.** The native path used to write to `Directory.systemTemp`, which
/// is app-private cache: unreachable from a phone's Files app and from every
/// other app, while the UI still reported a download. It now writes somewhere
/// reachable and shares the file.
///
/// The returned string is the *truthful* outcome and callers should display it
/// rather than assuming a download occurred.
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