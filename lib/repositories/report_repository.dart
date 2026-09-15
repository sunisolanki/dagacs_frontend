import 'package:http/http.dart' as http;

import '../models/hod_coverage_row.dart';
import '../models/hod_daily_lecture_row.dart';
import '../models/report_export.dart';
import '../models/report_page.dart';
import '../models/student_wise_report.dart';
import '../models/teacher_report_row.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Read-only M7.1/M7.2 report access: paginated HOD report feeds, the
/// teacher's own subject-wise report, and M7.2 Excel/PDF exports.
///
/// Authorization (department/HOD scope and teacher self-scope) is always
/// derived server-side from the JWT - no client-supplied IDs are ever sent.
/// Exports are binary attachments; [getBytes] on [ApiClient] preserves the raw
/// bytes and response headers so the file name/content type come from the
/// backend `Content-Disposition`/`Content-Type` headers.
class ReportRepository {
  ReportRepository([ApiClient? client]) : _client = client ?? ApiClient();

  static const int defaultPageSize = 20;

  final ApiClient _client;

  /// HOD daily-lecture report feed (record-backed, paginated).
  Future<ReportPage<HodDailyLectureRow>> getDailyLecture(
      {int page = 0,
      int size = defaultPageSize,
      DateTime? startDate,
      DateTime? endDate}) async {
    final data = await _client.get(_query(
        '/hod/reports/daily-lecture',
        page: page,
        size: size,
        startDate: startDate,
        endDate: endDate));
    return _page(data, HodDailyLectureRow.fromJson);
  }

  /// HOD recording-coverage report feed (record-backed, paginated).
  Future<ReportPage<HodCoverageRow>> getCoverage(
      {int page = 0,
      int size = defaultPageSize,
      DateTime? startDate,
      DateTime? endDate}) async {
    final data = await _client.get(_query('/hod/coverage',
        page: page,
        size: size,
        startDate: startDate,
        endDate: endDate));
    return _page(data, HodCoverageRow.fromJson);
  }

  /// Teacher's own subject-wise attendance report (full-data, non-paginated).
  Future<List<TeacherReportRow>> getTeacherReport(
      {DateTime? startDate, DateTime? endDate}) async {
    final data = await _client.get(_query('/teacher/attendance/report',
        startDate: startDate, endDate: endDate));
    if (data is! List) {
      throw const ApiException.serverError();
    }
    return data
        .whereType<Map>()
        .map((e) => TeacherReportRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Downloads an HOD export for one of the frozen supported report types.
  ///
  /// `format` must be `'xlsx'` or `'pdf'`; the report type is passed through
  /// verbatim and the backend (not this client) decides whether it is
  /// supported (unknown/semester -> 400).
  Future<DownloadPayload> exportHodReport(
      String reportType, String format,
      {DateTime? startDate, DateTime? endDate}) async {
    final path = _query('/hod/reports/$reportType/export.$format',
        startDate: startDate, endDate: endDate);
    return _download(path,
        fallbackName: 'dagacs_hod_$reportType'
            '${_dateSuffix(startDate, endDate)}.$format');
  }

  /// Downloads the teacher's own subject-wise export.
  Future<DownloadPayload> exportTeacherReport(String format,
      {DateTime? startDate, DateTime? endDate}) async {
    final path = _query('/teacher/attendance/report/export.$format',
        startDate: startDate, endDate: endDate);
    return _download(path,
        fallbackName: 'dagacs_teacher_subject_wise'
            '${_dateSuffix(startDate, endDate)}.$format');
  }

  /// Additive student-wise attendance matrix (one class at a time).
  ///
  /// Locked M10B contract: [subjectId] is required and exactly one of
  /// [sectionId] / [batchId] must select the class (XOR). Missing/both/neither
  /// is rejected by the server with 400, a nonexistent ID with 404, and an
  /// out-of-scope/unassigned context with 403. The matrix itself is always
  /// self-scoped to the JWT teacher.
  Future<StudentWiseReport> getStudentWiseReport({
    required int subjectId,
    int? sectionId,
    int? batchId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final path = _query('/teacher/attendance/student-wise',
            startDate: startDate, endDate: endDate,
            extra: {
              'subjectId': subjectId,
              if (sectionId != null) 'sectionId': sectionId,
              if (batchId != null) 'batchId': batchId,
            });
    final data = await _client.get(path);
    if (data is! Map) {
      throw const ApiException.serverError();
    }
    return StudentWiseReport.fromJson(Map<String, dynamic>.from(data));
  }

  /// Downloads the additive student-wise matrix export (xlsx/pdf). Uses the
  /// same locked M10B contract as [getStudentWiseReport].
  Future<DownloadPayload> exportStudentWiseReport(String format,
      {required int subjectId,
      int? sectionId,
      int? batchId,
      DateTime? startDate,
      DateTime? endDate}) async {
    final path = _query('/teacher/attendance/student-wise/export.$format',
            startDate: startDate, endDate: endDate,
            extra: {
              'subjectId': subjectId,
              if (sectionId != null) 'sectionId': sectionId,
              if (batchId != null) 'batchId': batchId,
            });
    return _download(path,
        fallbackName: 'dagacs_teacher_student_wise'
            '${_dateSuffix(startDate, endDate)}.$format');
  }

  // ── Internal helpers ───────────────────────────────────────────

  String _query(String base,
      {int? page,
      int? size,
      DateTime? startDate,
      DateTime? endDate,
      Map<String, Object>? extra}) {
    final params = <String>[];
    if (page != null) {
      params.add('page=$page');
    }
    if (size != null) {
      params.add('size=$size');
    }
    if (startDate != null) {
      params.add('startDate=${_formatDate(startDate)}');
    }
    if (endDate != null) {
      params.add('endDate=${_formatDate(endDate)}');
    }
    if (extra != null) {
      for (final entry in extra.entries) {
        params.add('${entry.key}=${entry.value}');
      }
    }
    return params.isEmpty ? base : '$base?${params.join('&')}';
  }

  ReportPage<T> _page<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    if (data is! Map) {
      throw const ApiException.serverError();
    }
    return ReportPage<T>.fromJson(Map<String, dynamic>.from(data), fromJson);
  }

  Future<DownloadPayload> _download(
      String path, {required String fallbackName}) async {
    final http.Response response = await _client.getBytes(path);
    final headers = response.headers;
    return DownloadPayload(
      bytes: response.bodyBytes,
      fileName:
          _fileNameFromDisposition(headers['content-disposition']) ??
              fallbackName,
      contentType: headers['content-type'],
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _dateSuffix(DateTime? startDate, DateTime? endDate) {
    if (startDate != null && endDate != null) {
      return '_${_formatDate(startDate)}_to_${_formatDate(endDate)}';
    }
    if (startDate != null) {
      return '_${_formatDate(startDate)}_onwards';
    }
    if (endDate != null) {
      return '_to_${_formatDate(endDate)}';
    }
    return '_all';
  }

  /// Extracts the file name from a `Content-Disposition` header such as
  /// `attachment; filename="dagacs_hod_daily-lecture_all.xlsx"`.
  static String? _fileNameFromDisposition(String? header) {
    if (header == null) return null;
    final quoted = RegExp(r'''filename="([^"]+)"''').firstMatch(header);
    if (quoted != null) return quoted.group(1);
    final bare = RegExp(r'filename=([^;]+)').firstMatch(header);
    return bare?.group(1)?.trim();
  }
}