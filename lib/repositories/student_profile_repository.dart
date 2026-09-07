import '../models/student_profile.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Student profile API access (M5.1).
///
/// Backend authorization remains authoritative — this repository does NOT
/// enforce any role checks. The student identity is resolved by the backend
/// from the JWT; no studentId is ever sent.
class StudentProfileRepository {
  StudentProfileRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<StudentProfile> getMyProfile() async {
    try {
      final data = await _client.get('/student/profile');
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return StudentProfile.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }
}