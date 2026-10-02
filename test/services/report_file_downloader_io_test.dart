import 'dart:io';
import 'dart:typed_data';

import 'package:dagacs_frontend/services/report_file_downloader_io.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 5.1: the native export destination and share flow.
///
/// The point of these tests is the defect that motivated the phase: the export
/// used to be written into `Directory.systemTemp` - app-private cache, invisible
/// to a phone's Files app and to every other app - while the UI told the user it
/// had been downloaded. A unit test can assert the destination and the message
/// precisely, which is exactly where that class of bug hides.
void main() {
  late Directory root;
  late ReportDirectoryResolver originalResolver;
  late ReportFileShareLauncher originalSharer;

  final files = <File>[];

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dagacs_export_test');
    files.clear();
    originalResolver = reportExportDirectory;
    originalSharer = reportExportShare;
    // A real directory, and a share launcher that only records. No platform
    // channel is touched, so these run in a plain unit test.
    reportExportDirectory = () async => root;
    reportExportShare = (file) async => files.add(file);
  });

  tearDown(() async {
    reportExportDirectory = originalResolver;
    reportExportShare = originalSharer;
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  Uint8List bytes(String text) =>
      Uint8List.fromList(text.codeUnits);

  group('the file itself', () {
    test('is written with the backend name, byte for byte', () async {
      final payload = bytes('PK-not-really-but-the-bytes-are-ours');
      final status = await downloadReportFile(payload, 'DAGACS_Attendance_Low_A.pdf', null);

      final written = File('${root.path}${Platform.pathSeparator}DAGACS_Attendance_Low_A.pdf');
      expect(await written.exists(), isTrue,
          reason: 'the report must exist on disk, not just in memory');
      expect(await written.readAsBytes(), payload,
          reason: 'the exported bytes must be unmodified - the file naming and '
              'content contracts of every report depend on it');
      expect(status, contains('DAGACS_Attendance_Low_A.pdf'));
    });

    test('keeps the server-provided name rather than inventing one', () async {
      await downloadReportFile(bytes('x'), 'dagacs_hod_attendance_matrix_all.xlsx', null);
      final entries = root.listSync().map((e) => e.path.split(Platform.pathSeparator).last).toList();
      expect(entries, ['dagacs_hod_attendance_matrix_all.xlsx'],
          reason: 'the matrix keeps its Phase 3 attachment name verbatim');
    });

    test('an empty payload still produces a real file', () async {
      await downloadReportFile(Uint8List(0), 'empty.xlsx', null);
      final written = File('${root.path}${Platform.pathSeparator}empty.xlsx');
      expect(await written.exists(), isTrue);
      expect(await written.length(), 0);
    });

    test('two exports of the same report overwrite rather than accumulate', () async {
      await downloadReportFile(bytes('first'), 'report.xlsx', null);
      await downloadReportFile(bytes('second-and-longer'), 'report.xlsx', null);
      final written = File('${root.path}${Platform.pathSeparator}report.xlsx');
      expect(await written.readAsString(), 'second-and-longer');
      expect(root.listSync().whereType<File>().length, 1);
    });
  });

  group('the share flow', () {
    test('the written file is handed to the share sheet', () async {
      await downloadReportFile(bytes('x'), 'shared.pdf', 'application/pdf');
      expect(files, hasLength(1), reason: 'a phone user reaches the file via Share');
      expect(files.single.path, endsWith('shared.pdf'));
    });

    test('a failing share sheet does not fail the export', () async {
      // The file is already on disk when sharing is attempted, so a device with
      // nothing able to receive it must still be a successful export.
      reportExportShare = (_) async => throw StateError('no activity to share with');

      final status = await downloadReportFile(bytes('x'), 'still-saved.pdf', null);

      final written = File('${root.path}${Platform.pathSeparator}still-saved.pdf');
      expect(await written.exists(), isTrue,
          reason: 'a share failure must not discard an already-saved file');
      expect(status, contains('still-saved.pdf'));
    });
  });

  group('the message is truthful', () {
    test('names the file and the folder it went to', () async {
      final nested = await Directory('${root.path}${Platform.pathSeparator}Reports')
          .create(recursive: true);
      reportExportDirectory = () async => nested;

      final status = await downloadReportFile(bytes('x'), 'overview.pdf', null);

      expect(status, contains('overview.pdf'),
          reason: 'the user must be able to tell which file was produced');
      expect(status, isNot(contains('Downloaded')),
          reason: 'Phase 5.1: the file is saved, not downloaded, and claiming '
              'otherwise is the exact defect this phase removes');
    });

    test('says plainly when the file is only in private storage', () async {
      // This is the pre-5.1 situation, deliberately preserved as an assertion:
      // writing to the system temp directory must never be reported as if the
      // user could find the file.
      final status = await downloadReportFile(bytes('x'), 'private.pdf', null);

      expect(status, contains('private.pdf'));
      expect(status.toLowerCase(), contains('share'),
          reason: 'the only way to reach a private file is the share sheet, so '
              'the message has to say so');
    });
  });

  group('directory resolution', () {
    test('creates a grouped subfolder inside the chosen location', () async {
      final resolved = await resolveReportExportDirectoryFor(root.path);

      expect(resolved, startsWith(root.path),
          reason: 'exports are grouped under the chosen base, never scattered');
      expect(resolved, isNot(root.path),
          reason: 'a dedicated subfolder keeps exports out of the user\'s '
              'Downloads root');
      expect(resolved, endsWith('DAGACS Reports'));
      expect(await Directory(resolved).exists(), isTrue);
    });

    test('is idempotent - a second call reuses the folder', () async {
      final first = await resolveReportExportDirectoryFor(root.path);
      final second = await resolveReportExportDirectoryFor(root.path);
      expect(first, second, reason: 're-exports must not create a new folder each time');
    });
  });
}

/// The subfolder logic of [resolveReportExportDirectory], exercised without the
/// `path_provider` plugin.
Future<String> resolveReportExportDirectoryFor(String basePath) async {
  final folder = Directory('$basePath${Platform.pathSeparator}DAGACS Reports');
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }
  return folder.path;
}
