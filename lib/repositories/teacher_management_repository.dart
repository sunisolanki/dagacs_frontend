import '../models/teacher_management.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// ADMIN teacher master-management API access (M9.5.1/M9.5.3).
///
/// Authoritative authorization lives on the backend (`/api/admin/teacher-management/teachers`
/// is ADMIN-only). Collisions (409), weak passwords (400) and RBAC failures
/// (401/403) surface as typed [ApiException]s for the UI to present.
class TeacherManagementRepository {
  TeacherManagementRepository(this._client);

  final ApiClient _client;

  Future<List<TeacherManagement>> getTeachers() async {
    try {
      final data = await _client.get('/admin/teacher-management/teachers');
      if (data is! List) {
        throw const ApiException.serverError();
      }
      return data
          .whereType<Map>()
          .map((e) => TeacherManagement.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<TeacherManagement> getTeacher(int id) async {
    try {
      final data =
          await _client.get('/admin/teacher-management/teachers/$id');
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return TeacherManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  Future<TeacherManagement> createTeacher(TeacherCreateRequest request) async {
    try {
      final data = await _client.post('/admin/teacher-management/teachers',
          body: request.toJson());
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return TeacherManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  Future<TeacherManagement> updateTeacher(
      int id, TeacherUpdateRequest request) async {
    try {
      final data = await _client.put('/admin/teacher-management/teachers/$id',
          body: request.toJson());
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return TeacherManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  Future<TeacherManagement> setTeacherStatus(int id, String status) async {
    try {
      final data = await _client.patch(
          '/admin/teacher-management/teachers/$id/status',
          body: {'status': status});
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return TeacherManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  /// Provision a login account for an existing teacher profile (M9.5.1).
  Future<TeacherManagement> provisionLogin(
      int id, TeacherLoginPasswordRequest request) async {
    try {
      final data = await _client.post(
          '/admin/teacher-management/teachers/$id/login',
          body: request.toJson());
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return TeacherManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  /// Reset the login password (does NOT invalidate already-issued JWTs; it only
  /// affects future sign-ins with the old password).
  Future<TeacherManagement> setLoginPassword(
      int id, TeacherLoginPasswordRequest request) async {
    try {
      final data = await _client.put(
          '/admin/teacher-management/teachers/$id/login/password',
          body: request.toJson());
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return TeacherManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  /// Activate/deactivate the login account without touching the profile (D4).
  Future<TeacherManagement> setLoginStatus(int id, String status) async {
    try {
      final data = await _client.patch(
          '/admin/teacher-management/teachers/$id/login/status',
          body: {'status': status});
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return TeacherManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  /// Designate (or demote) a HOD over the frozen `PATCH /api/admin/teachers/{id}/hod`
  /// endpoint (M6.1 surface reused by M9.5.3). Requires ADMIN; the backend
  /// answers with the read-only [HodIdentity] projection.
  Future<HodIdentity> designateHod(int teacherId,
      TeacherHodDesignationRequest request) async {
    try {
      final data = await _client.patch('/admin/teachers/$teacherId/hod',
          body: request.toJson());
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return HodIdentity.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }
}