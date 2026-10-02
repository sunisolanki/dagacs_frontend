import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Phase 5.1: where a native export is written, and how the user gets at it.
///
/// **Why this file changed.** It used to write to
/// `Directory.systemTemp.path` - the app's *private cache*. On a phone that
/// folder is unreachable from the Files app, from every other app, and from the
/// share sheet, so an exported HOD report was a file the user could never open,
/// while the UI still said "Downloaded". This version writes to a directory the
/// user can actually reach and offers the platform share sheet.

/// Chooses the directory an export is written to.
///
/// Overridable so the platform plugins are never touched by a unit test.
typedef ReportDirectoryResolver = Future<Directory> Function();

/// Hands a written export to the platform share sheet.
///
/// Overridable for the same reason. Must not throw for the caller: a failed
/// share must never turn a successfully saved file into a failed export.
typedef ReportFileShareLauncher = Future<void> Function(File file);

/// The resolver the default downloader uses. Replace in tests.
ReportDirectoryResolver reportExportDirectory = resolveReportExportDirectory;

/// The share launcher the default downloader uses. Replace in tests.
ReportFileShareLauncher reportExportShare = shareReportExport;

/// A subdirectory of the chosen location, so exports are grouped rather than
/// scattered across the root of the user's Downloads folder.
const String _exportFolderName = 'DAGACS Reports';

/// The best available user-reachable directory for an export.
///
/// The order is deliberate:
/// 1. **the real Downloads folder** - the only location a phone user can browse
///    to without any extra app. Available on Android, macOS, Windows and Linux.
/// 2. **the application documents directory** - iOS has no shared Downloads
///    folder, and the Files app exposes an app's own documents as "On My iPhone".
/// 3. **the temporary directory** - last resort, still better than failing, and
///    the share sheet can still hand the file to another app.
/// 4. **the system temp directory** - only reached if every plugin call fails,
///    so that an export still produces a file on a platform with no plugin
///    registered (a unit test, for instance) rather than throwing.
Future<Directory> resolveReportExportDirectory() async {
  final base = await _preferredBaseDirectory();
  if (base == null) {
    return Directory.systemTemp;
  }
  final folder = Directory('${base.path}${Platform.pathSeparator}$_exportFolderName');
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }
  return folder;
}

Future<Directory?> _preferredBaseDirectory() async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      if (!await downloads.exists()) {
        await downloads.create(recursive: true);
      }
      return downloads;
    }
  } catch (_) {
    // No shared Downloads folder here (iOS) or the plugin is unavailable.
  }
  try {
    return await getApplicationDocumentsDirectory();
  } catch (_) {
    // Fall through to the temporary directory.
  }
  try {
    return await getTemporaryDirectory();
  } catch (_) {
    return null;
  }
}

/// Offers the written file to the platform share sheet.
///
/// Best effort by design: a device with nothing that can receive a file, or an
/// iPad without a share anchor, must not fail an export that already succeeded.
Future<void> shareReportExport(File file) async {
  try {
    await Share.shareXFiles([XFile(file.path)], subject: file.uri.pathSegments.last);
  } catch (_) {
    // Deliberately swallowed - see the doc comment.
  }
}

/// Native (Android/iOS/desktop) export: writes the bytes to a directory the user
/// can reach, then offers the share sheet.
///
/// The [fileName] is the backend's own `Content-Disposition` name and is used
/// verbatim, so the file naming contract of every report is unchanged.
///
/// Returns a truthful description of what happened. Callers must display the
/// returned string rather than assuming a download, which is what previously
/// told a phone user "Downloaded" about a file in private storage.
Future<String> downloadReportFile(
  Uint8List bytes,
  String fileName,
  String? contentType,
) async {
  final directory = await reportExportDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);

  // The file is already on disk, so sharing is strictly best effort. Guarded
  // here as well as inside the default launcher, so that *any* launcher - the
  // default one or one substituted in a test - cannot turn a saved file into a
  // failed export.
  try {
    await reportExportShare(file);
  } catch (_) {
    // Deliberately swallowed: see the doc comment on shareReportExport.
  }

  final shared = await _isInUserReachableFolder(directory);
  return shared
      ? 'Saved $fileName to ${_labelFor(directory)}'
      : 'Saved $fileName in the app folder (use Share to open it)';
}

/// Whether the file really landed somewhere the user can browse to.
///
/// The system temp directory is deliberately excluded: it is app-private cache,
/// which is precisely the failure this file was changed to fix, so the message
/// must not claim otherwise.
Future<bool> _isInUserReachableFolder(Directory directory) async {
  final temp = await _systemTempPath();
  if (temp != null && _isInside(directory.path, temp)) {
    return false;
  }
  return true;
}

Future<String?> _systemTempPath() async {
  try {
    return Directory.systemTemp.path;
  } catch (_) {
    return null;
  }
}

bool _isInside(String child, String parent) {
  final normalizedParent = parent.endsWith(Platform.pathSeparator)
      ? parent
      : '$parent${Platform.pathSeparator}';
  return child == parent || child.startsWith(normalizedParent);
}

String _labelFor(Directory directory) {
  final name = directory.uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (name.isEmpty) {
    return 'Downloads';
  }
  // The last segment is the app's own folder, which adds nothing for the user.
  return name.length >= 2 ? name[name.length - 2] : name.first;
}
