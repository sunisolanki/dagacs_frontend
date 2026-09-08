// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

/// Flutter Web download: creates a temporary anchor element with a blob URL and
/// programmatically clicks it. The backend-provided [fileName] becomes the
/// browser-suggested save name and [contentType] is preserved on the blob.
Future<String> downloadReportFile(
  Uint8List bytes,
  String fileName,
  String? contentType,
) async {
  final blob = html.Blob([bytes], contentType ?? 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return 'Downloaded $fileName';
}