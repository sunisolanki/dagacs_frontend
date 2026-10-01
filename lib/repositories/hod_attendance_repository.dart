import '../models/hod_attendance_context.dart';
import '../models/hod_attendance_matrix.dart';
import '../models/hod_attendance_overview.dart';
import '../models/hod_low_attendance_report.dart';
import '../models/hod_student_attendance_detail.dart';
import '../models/hod_subject_attendance_detail.dart';
import '../models/report_export.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Read-only access to the Phase 3 HOD attendance intelligence API
/// (`/api/hod/attendance/**`).
///
/// <b>Authorization is entirely server-side.</b> The department is derived from
/// the JWT and is never a parameter; the academic ids below are a *selection*,
/// and the server proves each one belongs to the HOD's department and to the
/// exact context before any data query runs. A cross-department or
/// out-of-context id is rejected with 403 and no data is returned.
///
/// <b>Academic context is mandatory for the matrix.</b> [getMatrix] refuses to
/// issue a request without all four levels, and surfaces the server's own
/// contract message otherwise, so a mixed-department or mixed-semester
/// cross-tab can never be rendered.
class HodAttendanceRepository {
  HodAttendanceRepository([ApiClient? client]) : _client = client ?? ApiClient();

  /// Server-side default; kept in step with the backend's matrix page size.
  static const int defaultMatrixPageSize = 50;

  /// The exact message the backend returns for an incomplete matrix context.
  static const String matrixContextRequiredMessage =
      'Select Academic Session, Program, Semester and Section to view the '
      'Attendance Matrix.';

  final ApiClient _client;

  // ── Reads ────────────────────────────────────────────────────────────

  Future<HodAttendanceOverview> getOverview({
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final data = await _client.get(_query('/hod/attendance/overview',
        academicSessionId: academicSessionId,
        programId: programId,
        semesterId: semesterId,
        sectionId: sectionId,
        startDate: startDate,
        endDate: endDate));
    return HodAttendanceOverview.fromJson(_asMap(data));
  }

  /// The attendance cross-tab for one fully-resolved academic context.
  ///
  /// [subjectId] narrows the report to one subject; omit it for the complete
  /// multi-subject matrix. [sortBy] accepts `enrollmentNumber` (the default),
  /// `name` or `overallPercentage`.
  Future<HodAttendanceMatrix> getMatrix({
    required int? academicSessionId,
    required int? programId,
    required int? semesterId,
    required int? sectionId,
    int? subjectId,
    DateTime? startDate,
    DateTime? endDate,
    int page = 0,
    int size = defaultMatrixPageSize,
    String sortBy = 'enrollmentNumber',
    String direction = 'asc',
  }) async {
    if (academicSessionId == null ||
        programId == null ||
        semesterId == null ||
        sectionId == null) {
      // Blocked client-side so the user sees the actionable message immediately
      // instead of a generic 400. The server enforces exactly the same rule.
      throw const ApiException.badRequest(matrixContextRequiredMessage);
    }
    final data = await _client.get(_query('/hod/attendance/matrix',
        academicSessionId: academicSessionId,
        programId: programId,
        semesterId: semesterId,
        sectionId: sectionId,
        subjectId: subjectId,
        startDate: startDate,
        endDate: endDate,
        extra: {
          'page': page,
          'size': size,
          'sortBy': sortBy,
          'direction': direction,
        }));
    return HodAttendanceMatrix.fromJson(_asMap(data));
  }

  /// One student's attendance detail inside the current academic context.
  Future<HodStudentAttendanceDetail> getStudentDetail({
    required int studentId,
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    int? subjectId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final data = await _client.get(_query(
        '/hod/attendance/student/$studentId',
        academicSessionId: academicSessionId,
        programId: programId,
        semesterId: semesterId,
        sectionId: sectionId,
        subjectId: subjectId,
        startDate: startDate,
        endDate: endDate));
    return HodStudentAttendanceDetail.fromJson(_asMap(data));
  }

  /// Attendance detail for one subject inside the current academic context.
  Future<HodSubjectAttendanceDetail> getSubjectDetail({
    required int subjectId,
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final data = await _client.get(_query(
        '/hod/attendance/subject/$subjectId',
        academicSessionId: academicSessionId,
        programId: programId,
        semesterId: semesterId,
        sectionId: sectionId,
        startDate: startDate,
        endDate: endDate));
    return HodSubjectAttendanceDetail.fromJson(_asMap(data));
  }

  /// The context-scoped low-attendance report, including the subjects
  /// responsible for each student.
  Future<HodLowAttendanceReport> getLowAttendance({
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final data = await _client.get(_query('/hod/attendance/low',
        academicSessionId: academicSessionId,
        programId: programId,
        semesterId: semesterId,
        sectionId: sectionId,
        startDate: startDate,
        endDate: endDate));
    return HodLowAttendanceReport.fromJson(_asMap(data));
  }

  /// The context metadata of a selection, so the UI can confirm which academic
  /// context a report will cover before requesting any data.
  Future<HodAttendanceContext> getContext({
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
  }) async {
    final data = await _client.get(_query('/hod/attendance/context',
        academicSessionId: academicSessionId,
        programId: programId,
        semesterId: semesterId,
        sectionId: sectionId));
    return HodAttendanceContext.fromJson(_asMap(data));
  }

  // ── Exports ──────────────────────────────────────────────────────────

  /// Downloads the attendance matrix as a cross-tab spreadsheet or PDF.
  ///
  /// The export is always unpaged server-side, so the file contains every row of
  /// the selected context rather than one page of it. The two formats are
  /// produced by the backend from the same data model, so they can never
  /// disagree about a number.
  Future<DownloadPayload> exportMatrix(
    String format, {
    required int? academicSessionId,
    required int? programId,
    required int? semesterId,
    required int? sectionId,
    int? subjectId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (academicSessionId == null ||
        programId == null ||
        semesterId == null ||
        sectionId == null) {
      throw const ApiException.badRequest(matrixContextRequiredMessage);
    }
    final path = _query('/hod/attendance/matrix/export.$format',
        academicSessionId: academicSessionId,
        programId: programId,
        semesterId: semesterId,
        sectionId: sectionId,
        subjectId: subjectId,
        startDate: startDate,
        endDate: endDate);
    return _download(path, 'dagacs_hod_attendance_matrix.$format');
  }

  /// Downloads the academic-context overview (subject summary) as a spreadsheet or
  /// PDF.
  ///
  /// Same unpaged, same-context guarantee as [exportMatrix]: the file is produced
  /// by the backend from the identical data model the on-screen overview renders,
  /// so the two can never disagree about a number.
  Future<DownloadPayload> exportOverview(
    String format, {
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final path = _query('/hod/attendance/overview/export.$format',
        academicSessionId: academicSessionId,
        programId: programId,
        semesterId: semesterId,
        sectionId: sectionId,
        startDate: startDate,
        endDate: endDate);
    return _download(path, 'dagacs_hod_attendance_overview.$format');
  }

  /// Downloads one student's attendance report for the selected context.
  ///
  /// [studentId] is the id the HOD tapped, never a typed value; the server
  /// proves it belongs to the selected context.
  Future<DownloadPayload> exportStudent(
    String format, {
    required int studentId,
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    int? subjectId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final path = _query('/hod/attendance/student/$studentId/export.$format',
        academicSessionId: academicSessionId,
        programId: programId,
        semesterId: semesterId,
        sectionId: sectionId,
        subjectId: subjectId,
        startDate: startDate,
        endDate: endDate);
    return _download(path, 'dagacs_hod_attendance_student.$format');
  }

  /// Downloads one subject's attendance report for the selected context.
  Future<DownloadPayload> exportSubject(
    String format, {
    required int subjectId,
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final path = _query('/hod/attendance/subject/$subjectId/export.$format',
        academicSessionId: academicSessionId,
        programId: programId,
        semesterId: semesterId,
        sectionId: sectionId,
        startDate: startDate,
        endDate: endDate);
    return _download(path, 'dagacs_hod_attendance_subject.$format');
  }

  /// Downloads the low-attendance report for the selected context.
  Future<DownloadPayload> exportLowAttendance(
    String format, {
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final path = _query('/hod/attendance/low/export.$format',
        academicSessionId: academicSessionId,
        programId: programId,
        semesterId: semesterId,
        sectionId: sectionId,
        startDate: startDate,
        endDate: endDate);
    return _download(path, 'dagacs_hod_attendance_low.$format');
  }

  // ── Internal helpers ─────────────────────────────────────────────────

  String _query(
    String base, {
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
    int? subjectId,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, Object>? extra,
  }) {
    final params = <String>[];
    // The academic context is never optional once a report needs it; each id is
    // simply omitted when the HOD has not chosen that level yet.
    if (academicSessionId != null) {
      params.add('academicSessionId=$academicSessionId');
    }
    if (programId != null) {
      params.add('programId=$programId');
    }
    if (semesterId != null) {
      params.add('semesterId=$semesterId');
    }
    if (sectionId != null) {
      params.add('sectionId=$sectionId');
    }
    if (subjectId != null) {
      params.add('subjectId=$subjectId');
    }
    // Date filtering and academic-context filtering are independent and are
    // always combined by the server with AND, never with OR.
    if (startDate != null) {
      params.add('startDate=${_formatDate(startDate)}');
    }
    if (endDate != null) {
      params.add('endDate=${_formatDate(endDate)}');
    }
    if (extra != null) {
      extra.forEach((key, value) => params.add('$key=$value'));
    }
    return params.isEmpty ? base : '$base?${params.join('&')}';
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is! Map) {
      throw const ApiException.serverError();
    }
    return Map<String, dynamic>.from(data);
  }

  Future<DownloadPayload> _download(String path, String fallbackName) async {
    final response = await _client.getBytes(path);
    return DownloadPayload(
      bytes: response.bodyBytes,
      fileName: fileNameFromDisposition(response.headers['content-disposition']) ??
          fallbackName,
      contentType: response.headers['content-type'],
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Extracts the file name from a `Content-Disposition` header such as
  /// `attachment; filename="dagacs_hod_attendance_matrix_all.xlsx"`.
  static String? fileNameFromDisposition(String? header) {
    if (header == null) return null;
    final quoted = RegExp(r'''filename="([^"]+)"''').firstMatch(header);
    if (quoted != null) return quoted.group(1);
    final bare = RegExp(r'filename=([^;]+)').firstMatch(header);
    return bare?.group(1)?.trim();
  }
}
