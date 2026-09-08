import 'dart:typed_data';

/// A successfully downloaded M7.2 export file.
///
/// [fileName] comes from the backend `Content-Disposition` header when present
/// (falling back to a locally derived name), and [contentType] mirrors the
/// response `Content-Type` so the web downloader can preserve it.
class DownloadPayload {
  final Uint8List bytes;
  final String fileName;
  final String? contentType;

  const DownloadPayload({
    required this.bytes,
    required this.fileName,
    this.contentType,
  });
}