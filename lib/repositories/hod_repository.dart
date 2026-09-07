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
  Future<List<HodSectionAttendance>> getSections() =>
      _list('/hod/sections', HodSectionAttendance.fromJson);

  /// Subject-wise attendance summary with enrolled student counts.
  Future<List<HodSubjectAttendance>> getSubjects() =>
      _list('/hod/subjects', HodSubjectAttendance.fromJson);

  /// Full per-student attendance summary.
  Future<List<HodStudentAttendance>> getStudents() =>
      _list('/hod/students', HodStudentAttendance.fromJson);

  /// Students below the FIXED 75.0% threshold.
  ///
  /// The backend performs the `percentage < 75.0` filter; Flutter only
  /// displays the result.
  Future<List<HodLowAttendance>> getLowAttendance() =>
      _list('/hod/low-attendance', HodLowAttendance.fromJson);

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
  Future<List<HodAuditLogEntry>> getAuditLogs() =>
      _list('/hod/audit-logs', HodAuditLogEntry.fromJson);

  // ── Internal helpers ───────────────────────────────────────────

  String _query(base, {DateTime? startDate, DateTime? endDate}) {
    final params = <String>[];
    if (startDate != null) {
      params.add('startDate=${_formatDate(startDate)}');
    }
    if (endDate != null) {
      params.add('endDate=${_formatDate(endDate)}');
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
      String path, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final data = await _client.get(path);
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