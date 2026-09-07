import '../models/attendance_mark_request.dart';
import '../models/attendance_percentage.dart';
import '../models/attendance_record.dart';
import '../models/attendance_session.dart';
import '../models/attendance_session_create_request.dart';
import '../models/attendance_session_update_request.dart';
import '../models/attendance_update_request.dart';
import '../models/session_student.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Attendance API access for both teacher and student roles.
///
/// Backend authorization remains authoritative — this repository does NOT
/// enforce any role checks. It simply sends the correct requests to the
/// correct paths.
class AttendanceRepository {
  AttendanceRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  // ── Teacher endpoints ──────────────────────────────────────────

  Future<List<AttendanceSession>> getSessions() =>
      _list('/teacher/attendance/sessions', AttendanceSession.fromJson);

  Future<AttendanceSession> createSession(
      AttendanceSessionCreateRequest request) async {
    try {
      final data = await _client.post(
        '/teacher/attendance/sessions',
        body: request.toJson(),
      );
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return AttendanceSession.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  Future<AttendanceSession> updateSession(
      int sessionId, AttendanceSessionUpdateRequest request) async {
    try {
      final data = await _client.put(
        '/teacher/attendance/sessions/$sessionId',
        body: request.toJson(),
      );
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return AttendanceSession.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  Future<List<SessionStudent>> getStudentsForSession(int sessionId) =>
      _list(
        '/teacher/attendance/sessions/$sessionId/students',
        SessionStudent.fromJson,
      );

  Future<List<AttendanceRecord>> getRecordsForSession(int sessionId) =>
      _list(
        '/teacher/attendance/sessions/$sessionId/records',
        AttendanceRecord.fromJson,
      );

  Future<List<AttendanceRecord>> markAttendance(
      AttendanceMarkRequest request) async {
    try {
      final data = await _client.post(
        '/teacher/attendance/mark',
        body: request.toJson(),
      );
      if (data is! List) {
        throw const ApiException.serverError();
      }
      return data
          .whereType<Map>()
          .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<AttendanceRecord> updateAttendance(
      int recordId, AttendanceUpdateRequest request) async {
    try {
      final data = await _client.put(
        '/teacher/attendance/$recordId',
        body: request.toJson(),
      );
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return AttendanceRecord.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  // ── Student endpoints ──────────────────────────────────────────

  Future<List<AttendanceRecord>> getMyAttendance() =>
      _list('/student/attendance/my', AttendanceRecord.fromJson);

  /// Overall attendance calculation.
  ///
  /// The authenticated student's identity is resolved by the backend from the
  /// JWT — no studentId is sent. The result is displayed as-is; Flutter does
  /// not recalculate the percentage.
  ///
  /// Optional [startDate] / [endDate] bound the inclusive date-range filter;
  /// both are sent as canonical `YYYY-MM-DD` query parameters only when present.
  Future<AttendancePercentage> getOverallAttendanceCalculation(
          {DateTime? startDate, DateTime? endDate}) =>
      _single(_calculationPath(startDate: startDate, endDate: endDate));

  /// Subject-wise attendance calculation for the authenticated student.
  Future<AttendancePercentage> getSubjectAttendanceCalculation(
          int subjectId,
          {DateTime? startDate, DateTime? endDate}) =>
      _single(_calculationPath(
          subjectId: subjectId, startDate: startDate, endDate: endDate));

  // ── Internal helpers ───────────────────────────────────────────

  String _calculationPath(
      {int? subjectId, DateTime? startDate, DateTime? endDate}) {
    final path = subjectId == null
        ? '/student/attendance/calculation'
        : '/student/attendance/calculation/subject/$subjectId';
    final params = <String>[];
    if (startDate != null) {
      params.add('startDate=${_formatDate(startDate)}');
    }
    if (endDate != null) {
      params.add('endDate=${_formatDate(endDate)}');
    }
    return params.isEmpty ? path : '$path?${params.join('&')}';
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<AttendancePercentage> _single(String path) async {
    try {
      final data = await _client.get(path);
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return AttendancePercentage.fromJson(Map<String, dynamic>.from(data));
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
