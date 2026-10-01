import '../models/hod_audit_log_entry.dart';
import '../models/hod_dashboard.dart';
import '../models/hod_low_attendance.dart';
import '../models/hod_rollup.dart';
import '../models/hod_section_attendance.dart';
import '../models/hod_student_attendance.dart';
import '../models/hod_subject_attendance.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Read-only HOD governance & analytics API access.
///
/// All endpoints are scoped server-side to the HOD's own department via the
/// JWT — no entity IDs are ever sent. Semester rollups are NOT DERIVABLE by
/// the backend, so [getRollups] only ever issues `type=monthly` or
/// `type=quarterly`.
class HodRepository {
  HodRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Department-wide overview plus overall attendance for the period.
  Future<HodDashboard> getDashboard(
          {DateTime? startDate, DateTime? endDate}) =>
      _single('/hod/dashboard',
          startDate: startDate, endDate: endDate);

  /// Section-wise attendance summary (latest attendance date semantics).
  ///
  /// [academicSessionId]/[programId]/[semesterId]/[sectionId] are optional. When
  /// none is supplied the backend runs the original department-wide query, so
  /// the pre-existing behaviour is preserved exactly.
  Future<List<HodSectionAttendance>> getSections({
    DateTime? startDate,
    DateTime? endDate,
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
  }) =>
      _list('/hod/sections', HodSectionAttendance.fromJson,
          startDate: startDate,
          endDate: endDate,
          academicSessionId: academicSessionId,
          programId: programId,
          semesterId: semesterId,
          sectionId: sectionId);

  /// Subject-wise attendance summary with enrolled student counts.
  Future<List<HodSubjectAttendance>> getSubjects({
    DateTime? startDate,
    DateTime? endDate,
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
  }) =>
      _list('/hod/subjects', HodSubjectAttendance.fromJson,
          startDate: startDate,
          endDate: endDate,
          academicSessionId: academicSessionId,
          programId: programId,
          semesterId: semesterId,
          sectionId: sectionId);

  /// Full per-student attendance summary.
  Future<List<HodStudentAttendance>> getStudents({
    DateTime? startDate,
    DateTime? endDate,
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
  }) =>
      _list('/hod/students', HodStudentAttendance.fromJson,
          startDate: startDate,
          endDate: endDate,
          academicSessionId: academicSessionId,
          programId: programId,
          semesterId: semesterId,
          sectionId: sectionId);

  /// Students below the FIXED 75.0% threshold.
  Future<List<HodLowAttendance>> getLowAttendance({
    DateTime? startDate,
    DateTime? endDate,
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
  }) =>
      _list('/hod/low-attendance', HodLowAttendance.fromJson,
          startDate: startDate,
          endDate: endDate,
          academicSessionId: academicSessionId,
          programId: programId,
          semesterId: semesterId,
          sectionId: sectionId);

  /// Monthly or quarterly attendance rollup for the department.
  Future<List<HodRollup>> getRollups(
      {required String type, DateTime? startDate, DateTime? endDate}) async {
    if (type != 'monthly' && type != 'quarterly') {
      throw ArgumentError.value(
          type, 'type', 'HOD rollups only support monthly or quarterly.');
    }
    return _list(
      _rollupPath(type: type, startDate: startDate, endDate: endDate),
      HodRollup.fromJson,
    );
  }

  /// Correction history visible to the HOD's department.
  Future<List<HodAuditLogEntry>> getAuditLogs(
          {DateTime? startDate, DateTime? endDate}) =>
      _list('/hod/audit-logs', HodAuditLogEntry.fromJson,
          startDate: startDate, endDate: endDate);

  // ── Internal helpers ───────────────────────────────────────────

  String _query(
    base, {
    DateTime? startDate,
    DateTime? endDate,
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
  }) {
    final params = <String>[];
    if (startDate != null) {
      params.add('startDate=${_formatDate(startDate)}');
    }
    if (endDate != null) {
      params.add('endDate=${_formatDate(endDate)}');
    }
    // Optional academic context. Omitted entirely when the HOD has not chosen
    // one, which keeps the backend on its department-wide query.
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
    return params.isEmpty ? base : '$base?${params.join('&')}';
  }

  String _rollupPath(
      {required String type, DateTime? startDate, DateTime? endDate}) {
    final base = '/hod/rollups?type=$type';
    final params = <String>[];
    if (startDate != null) {
      params.add('startDate=${_formatDate(startDate)}');
    }
    if (endDate != null) {
      params.add('endDate=${_formatDate(endDate)}');
    }
    return params.isEmpty ? base : '$base&${params.join('&')}';
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<HodDashboard> _single(String path,
          {DateTime? startDate, DateTime? endDate}) async {
    try {
      final data = await _client.get(_query(path,
          startDate: startDate, endDate: endDate));
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return HodDashboard.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    DateTime? startDate,
    DateTime? endDate,
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? sectionId,
  }) async {
    try {
      final data = await _client.get(_query(path,
          startDate: startDate,
          endDate: endDate,
          academicSessionId: academicSessionId,
          programId: programId,
          semesterId: semesterId,
          sectionId: sectionId));
      if (data is! List) {
        throw const ApiException.serverError();
      }
      return data
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on ApiException {
      rethrow;
    }
  }
}