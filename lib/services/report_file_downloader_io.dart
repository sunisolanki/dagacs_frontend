import 'dart:io';
import 'dart:typed_data';

/// Native (Android/desktop/VM) download: writes the bytes to an app-local
/// temporary directory and returns a user-facing status string.
Future<String> downloadReportFile(
  Uint8List bytes,
  String fileName,
  String? contentType,
) async {
  final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return 'Exported to ${file.path}';
}