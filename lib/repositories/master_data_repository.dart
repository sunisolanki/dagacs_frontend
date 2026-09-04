import '../models/academic_session.dart';
import '../models/batch.dart';
import '../models/department.dart';
import '../models/program.dart';
import '../models/section.dart';
import '../models/semester.dart';
import '../models/subject.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Read-only access to the verified backend master-data API (`/api/admin/**`).
///
/// NOTE: These endpoints are ADMIN-protected on the backend
/// (`@PreAuthorize("hasRole('ADMIN')")`). Non-admin roles will map to 403 -
/// the UI handles that gracefully. Backend authorization remains authoritative.
class MasterDataRepository {
  MasterDataRepository(this._client);

  final ApiClient _client;

  Future<List<Department>> getDepartments() =>
      _list('/admin/departments', Department.fromJson);

  Future<List<Program>> getPrograms() =>
      _list('/admin/programs', Program.fromJson);

  Future<List<AcademicSession>> getAcademicSessions() =>
      _list('/admin/academic-sessions', AcademicSession.fromJson);

  Future<List<Semester>> getSemesters() =>
      _list('/admin/semesters', Semester.fromJson);

  Future<List<Batch>> getBatches() => _list('/admin/batches', Batch.fromJson);

  Future<List<Section>> getSections() =>
      _list('/admin/sections', Section.fromJson);

  Future<List<Subject>> getSubjects() =>
      _list('/admin/subjects', Subject.fromJson);

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
