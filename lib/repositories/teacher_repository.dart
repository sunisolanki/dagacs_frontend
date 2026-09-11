import '../models/teacher_assignment.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Teacher self-service API access (M9.4).
///
/// Uses the TEACHER-only `GET /api/teacher/assignments` endpoint from M9.3.
/// The authenticated teacher identity is resolved by the backend from the JWT —
/// the client never sends a teacherId. Backend authorization remains
/// authoritative; this repository does NOT enforce role checks.
class TeacherRepository {
  TeacherRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<TeacherAssignment>> getMyAssignments() async {
    try {
      final data = await _client.get('/teacher/assignments');
      if (data is! List) {
        throw const ApiException.serverError();
      }
      return data
          .whereType<Map>()
          .map((e) => TeacherAssignment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on ApiException {
      rethrow;
    }
  }
}