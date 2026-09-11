import 'dart:async';
import 'dart:typed_data';

import 'package:dagacs_frontend/models/hod_coverage_row.dart';
import 'package:dagacs_frontend/models/hod_daily_lecture_row.dart';
import 'package:dagacs_frontend/models/hod_low_attendance.dart';
import 'package:dagacs_frontend/models/hod_rollup.dart';
import 'package:dagacs_frontend/models/report_export.dart';
import 'package:dagacs_frontend/models/report_page.dart';
import 'package:dagacs_frontend/network/api_exception.dart';
import 'package:dagacs_frontend/repositories/hod_repository.dart';
import 'package:dagacs_frontend/repositories/report_repository.dart';
import 'package:dagacs_frontend/screens/hod_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHodRepository extends HodRepository {
  _FakeHodRepository();

  List<HodLowAttendance> low = const [];
  List<HodRollup> rollups = const [];
  DateTime? lastLowStart;
  DateTime? lastLowEnd;

  @override
  Future<List<HodRollup>> getRollups(
          {required String type, DateTime? startDate, DateTime? endDate}) async =>
      rollups;

  @override
  Future<List<HodLowAttendance>> getLowAttendance(
          {DateTime? startDate, DateTime? endDate}) async {
    lastLowStart = startDate;
    lastLowEnd = endDate;
    return low;
  }
}

class _FakeReportRepository extends ReportRepository {
  _FakeReportRepository();

  ReportPage<HodDailyLectureRow> daily =
      const ReportPage(items: [], page: 0, totalPages: 0);
  ReportPage<HodCoverageRow> coverage =
      const ReportPage(items: [], page: 0, totalPages: 0);

  /// Optional page-keyed daily pages for pagination-state tests. When non-empty,
  /// [getDailyLecture] serves the page matching the requested page number.
  final Map<int, ReportPage<HodDailyLectureRow>> dailyByPage = {};
  final List<int> dailyRequestedPages = [];

  final List<({DateTime? start, DateTime? end})> dailyCalls = [];
  final List<({DateTime? start, DateTime? end})> coverageCalls = [];
  final List<({String type, String format, DateTime? start, DateTime? end})>
      exportCalls = [];

  Object? dailyError;
  Object? exportError;
  Completer<DownloadPayload>? exportGate;

  @override
  Future<ReportPage<HodDailyLectureRow>> getDailyLecture(
      {int page = 0,
      int size = 20,
      DateTime? startDate,
      DateTime? endDate}) async {
    dailyCalls.add((start: startDate, end: endDate));
    dailyRequestedPages.add(page);
    if (dailyError != null) throw dailyError!;
    if (dailyByPage.isNotEmpty) {
      return dailyByPage[page] ?? daily;
    }
    return daily;
  }

  @override
  Future<ReportPage<HodCoverageRow>> getCoverage(
      {int page = 0,
      int size = 20,
      DateTime? startDate,
      DateTime? endDate}) async {
    coverageCalls.add((start: startDate, end: endDate));
    return coverage;
  }

  @override
  Future<DownloadPayload> exportHodReport(String reportType, String format,
      {DateTime? startDate, DateTime? endDate}) {
    exportCalls.add(
        (type: reportType, format: format, start: startDate, end: endDate));
    if (exportError != null) {
      return Future.error(exportError!);
    }
    if (exportGate != null) {
      return exportGate!.future;
    }
    return Future.value(DownloadPayload(
        bytes: Uint8List.fromList([1]), fileName: 'x.xlsx'));
  }
}

const _dailyPage = ReportPage<HodDailyLectureRow>(
  items: [
    HodDailyLectureRow(
      date: '2026-01-10',
      lecturePeriod: 'LP1',
      subjectCode: 'S1',
      subjectName: 'Data Structures',
      sectionCode: 'A',
      sectionName: 'Section A',
      presentCount: 2,
      totalRecordedCount: 3,
      percentage: 66.66666,
    )
  ],
  page: 0,
  totalPages: 5,
);

const _coveragePage = ReportPage<HodCoverageRow>(
  items: [
    HodCoverageRow(
      subjectCode: 'S1',
      subjectName: 'Data Structures',
      sectionCode: 'A',
      sectionName: 'Section A',
      recordedDateCount: 4,
      sessionCount: 6,
    )
  ],
  page: 0,
  totalPages: 2,
);

Widget _wrap(_FakeHodRepository hod, _FakeReportRepository repo,
    {required Future<String> Function(Uint8List, String, String?) download}) {
  return MaterialApp(
    home: HodReportsScreen(
      hodRepository: hod,
      reportRepository: repo,
      downloadFile: download,
    ),
  );
}

Future<void> _selectDay(WidgetTester tester, int day) async {
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
      of: find.byType(CalendarDatePicker),
      matching: find.text('$day')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('default loads the daily-lecture report and renders rows',
      (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository()..daily = _dailyPage;
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(repo.dailyCalls.length, 1);
    expect(repo.dailyCalls.single.start, isNull);
    expect(repo.dailyCalls.single.end, isNull);
    expect(find.text('Data Structures (S1)'), findsOneWidget);
    expect(find.text('66.66666%'), findsOneWidget);
    expect(find.text('Page 1 of 5'), findsOneWidget);
  });

  testWidgets('selecting a different report type reloads that feed',
      (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository()..coverage = _coveragePage;
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Coverage'));
    await tester.pumpAndSettle();

    expect(repo.coverageCalls.length, 1);
    expect(find.text('Data Structures (S1)'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);
  });

  testWidgets('empty report shows an empty state, not an error',
      (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository(); // empty by default
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No daily lecture data'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('API failure shows a retryable error and retry reloads',
      (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository()
      ..daily = _dailyPage
      ..dailyError = const ApiException.serverError();
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    repo.dailyError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repo.dailyCalls.length, 2);
    expect(find.text('Data Structures (S1)'), findsOneWidget);
  });

  testWidgets('start > end is rejected before any request with dates',
      (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository()..daily = _dailyPage;
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();
    expect(repo.dailyCalls.length, 1);

    await tester.tap(find.text('Start date'));
    await _selectDay(tester, 15);
    await tester.tap(find.text('End date'));
    await _selectDay(tester, 10);

    expect(find.text('Start date must not be after end date.'), findsOneWidget);
    final hasInvalidPair = repo.dailyCalls
        .any((c) => c.start != null && c.end != null && c.start!.isAfter(c.end!));
    expect(hasInvalidPair, isFalse);

    await tester.tap(find.byKey(const Key('export-excel')));
    await tester.pumpAndSettle();
    expect(repo.exportCalls, isEmpty);
    expect(find.text('Start date must not be after end date.'), findsWidgets);
  });

  testWidgets('clearing the invalid dates re-enables loading', (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository()..daily = _dailyPage;
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start date'));
    await _selectDay(tester, 15);
    await tester.tap(find.text('End date'));
    await _selectDay(tester, 10);

    await tester.tap(find.byTooltip('Clear dates'));
    await tester.pumpAndSettle();

    expect(find.text('Start date must not be after end date.'), findsNothing);
    expect(repo.dailyCalls.length, greaterThan(2));
  });

  testWidgets('export success calls the downloader with the backend payload',
      (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository()..daily = _dailyPage;
    final downloaded = <(Uint8List, String, String?)>[];
    await tester.pumpWidget(_wrap(
      hod,
      repo,
      download: (bytes, name, type) async {
        downloaded.add((bytes, name, type));
        return 'Downloaded $name';
      },
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-excel')));
    await tester.pumpAndSettle();

    expect(repo.exportCalls.single.type, 'daily-lecture');
    expect(repo.exportCalls.single.format, 'xlsx');
    expect(downloaded.single.$2, 'x.xlsx');
    expect(downloaded.single.$3, isNull);
    expect(find.text('Downloaded x.xlsx'), findsOneWidget);
  });

  testWidgets('loading state prevents duplicate export requests',
      (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository()
      ..daily = _dailyPage
      ..exportGate = Completer<DownloadPayload>();
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-excel')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('export-pdf')));
    await tester.pump();

    expect(repo.exportCalls.length, 1);
    repo.exportGate!.complete(DownloadPayload(
        bytes: Uint8List.fromList([1]), fileName: 'x.xlsx'));
    await tester.pumpAndSettle();
    expect(repo.exportCalls.length, 1);
  });

  testWidgets('403 export error shows the authorization message',
      (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository()
      ..daily = _dailyPage
      ..exportError = const ApiException.forbidden();
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-pdf')));
    await tester.pumpAndSettle();

    expect(find.text('You are not authorized to access this report.'),
        findsOneWidget);
  });

  testWidgets('backend 400 (e.g. unsupported semester) surfaces its message',
      (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository()
      ..daily = _dailyPage
      ..exportError = ApiException(
          400, 'Unsupported report type for export: semester');
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-excel')));
    await tester.pumpAndSettle();

    expect(find.text('Unsupported report type for export: semester'),
        findsOneWidget);
  });

  testWidgets('semester is not offered as a functional report type',
      (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository()..daily = _dailyPage;
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNWidgets(5));
    expect(
      find.descendant(
          of: find.byType(ChoiceChip), matching: find.text('Semester')),
      findsNothing,
    );
  });

  testWidgets('low-attendance shows the date filter and renders',
      (tester) async {
    final hod = _FakeHodRepository()
      ..low = const [
        HodLowAttendance(
          rollNumber: 'AD2026001',
          studentName: 'Alice Smith',
          sectionName: 'Section A',
          presentCount: 5,
          totalRecordedCount: 8,
          percentage: 62.5,
        )
      ];
    final repo = _FakeReportRepository()..daily = _dailyPage;
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('End date'), findsOneWidget);

    await tester.tap(find.text('Low Attendance'));
    await tester.pumpAndSettle();

    // The date bar is presented for low-attendance too (M9.5.5).
    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('End date'), findsOneWidget);
    expect(find.text('Alice Smith'), findsOneWidget);
  });

  testWidgets('monthly rollups render through the frozen HOD analytics endpoint',
      (tester) async {
    final hod = _FakeHodRepository()
      ..rollups = const [
        HodRollup(
            period: '2026-01', presentCount: 10, totalRecordedCount: 20, percentage: 50.0)
      ];
    final repo = _FakeReportRepository()..daily = _dailyPage;
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();

    expect(find.text('2026-01'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('pagination: previous disabled and next enabled on the first page',
      (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository();
    for (var i = 0; i < 5; i++) {
      repo.dailyByPage[i] =
          ReportPage(items: _dailyPage.items, page: i, totalPages: 5);
    }
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 5'), findsOneWidget);
    final prev = tester.widget<IconButton>(find.byKey(const Key('report-prev-page')));
    final next = tester.widget<IconButton>(find.byKey(const Key('report-next-page')));
    expect(prev.onPressed, isNull, reason: 'previous is disabled on the first page');
    expect(next.onPressed, isNotNull,
        reason: 'next is enabled when another page exists');
  });

  testWidgets(
      'pagination: previous enabled and next disabled once the last page is reached',
      (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository();
    for (var i = 0; i < 5; i++) {
      repo.dailyByPage[i] =
          ReportPage(items: _dailyPage.items, page: i, totalPages: 5);
    }
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('report-next-page')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Page 5 of 5'), findsOneWidget);
    final prev = tester.widget<IconButton>(find.byKey(const Key('report-prev-page')));
    final next = tester.widget<IconButton>(find.byKey(const Key('report-next-page')));
    expect(prev.onPressed, isNotNull, reason: 'previous is enabled before the last page');
    expect(next.onPressed, isNull, reason: 'next is disabled on the last page');
  });

  testWidgets('pagination: only one page disables both buttons',
      (tester) async {
    final hod = _FakeHodRepository();
    final repo = _FakeReportRepository();
    repo.dailyByPage[0] =
        ReportPage(items: _dailyPage.items, page: 0, totalPages: 1);
    await tester.pumpWidget(_wrap(hod, repo, download: (_, _, _) async => 'ok'));
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 1'), findsOneWidget);
    final prev = tester.widget<IconButton>(find.byKey(const Key('report-prev-page')));
    final next = tester.widget<IconButton>(find.byKey(const Key('report-next-page')));
    expect(prev.onPressed, isNull);
    expect(next.onPressed, isNull);
  });
}