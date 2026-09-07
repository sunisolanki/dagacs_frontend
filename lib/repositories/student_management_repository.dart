import '../models/student_management.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// ADMIN student master-management API access (M5.2).
///
/// Authoritative authorization lives on the backend (`/api/admin/students` is
/// ADMIN-only). This repository simply issues the requests; non-admin roles map
/// to a typed 403 [ApiException].
class StudentManagementRepository {
  StudentManagementRepository(this._client);

  final ApiClient _client;

  Future<List<StudentManagement>> getStudents() async {
    try {
      final data = await _client.get('/admin/students');
      if (data is! List) {
        throw const ApiException.serverError();
      }
      return data
          .whereType<Map>()
          .map((e) => StudentManagement.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<StudentManagement> getStudent(int id) async {
    try {
      final data = await _client.get('/admin/students/$id');
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return StudentManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  Future<StudentManagement> createStudent(StudentManagementRequest request) async {
    try {
      final data = await _client.post('/admin/students', body: request.toJson());
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return StudentManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  Future<StudentManagement> updateStudent(
      int id, StudentManagementRequest request) async {
    try {
      final data =
          await _client.put('/admin/students/$id', body: request.toJson());
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return StudentManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  Future<StudentManagement> setStudentStatus(int id, String status) async {
    try {
      final data = await _client
          .patch('/admin/students/$id/status', body: {'status': status});
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return StudentManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }
}