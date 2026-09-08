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

  Future<T> _single<T>(
      Future<dynamic> request, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final data = await request;
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  Future<Department> createDepartment(DepartmentRequest request) =>
      _single(_client.post('/admin/departments', body: request.toJson()),
          Department.fromJson);

  Future<Department> updateDepartment(int id, DepartmentRequest request) =>
      _single(_client.put('/admin/departments/$id', body: request.toJson()),
          Department.fromJson);

  Future<void> deleteDepartment(int id) =>
      _client.delete('/admin/departments/$id');

  Future<Program> createProgram(ProgramRequest request) =>
      _single(_client.post('/admin/programs', body: request.toJson()),
          Program.fromJson);

  Future<Program> updateProgram(int id, ProgramRequest request) =>
      _single(_client.put('/admin/programs/$id', body: request.toJson()),
          Program.fromJson);

  Future<void> deleteProgram(int id) => _client.delete('/admin/programs/$id');

  Future<AcademicSession> createAcademicSession(
          AcademicSessionRequest request) =>
      _single(_client.post('/admin/academic-sessions', body: request.toJson()),
          AcademicSession.fromJson);

  Future<AcademicSession> updateAcademicSession(
          int id, AcademicSessionRequest request) =>
      _single(
          _client.put('/admin/academic-sessions/$id',
              body: request.toJson()),
          AcademicSession.fromJson);

  Future<void> deleteAcademicSession(int id) =>
      _client.delete('/admin/academic-sessions/$id');

  Future<Semester> createSemester(SemesterRequest request) =>
      _single(_client.post('/admin/semesters', body: request.toJson()),
          Semester.fromJson);

  Future<Semester> updateSemester(int id, SemesterRequest request) =>
      _single(_client.put('/admin/semesters/$id', body: request.toJson()),
          Semester.fromJson);

  Future<void> deleteSemester(int id) =>
      _client.delete('/admin/semesters/$id');

  Future<Batch> createBatch(BatchRequest request) =>
      _single(_client.post('/admin/batches', body: request.toJson()),
          Batch.fromJson);

  Future<Batch> updateBatch(int id, BatchRequest request) =>
      _single(_client.put('/admin/batches/$id', body: request.toJson()),
          Batch.fromJson);

  Future<void> deleteBatch(int id) => _client.delete('/admin/batches/$id');

  Future<Section> createSection(SectionRequest request) =>
      _single(_client.post('/admin/sections', body: request.toJson()),
          Section.fromJson);

  Future<Section> updateSection(int id, SectionRequest request) =>
      _single(_client.put('/admin/sections/$id', body: request.toJson()),
          Section.fromJson);

  Future<void> deleteSection(int id) => _client.delete('/admin/sections/$id');

  Future<Subject> createSubject(SubjectRequest request) =>
      _single(_client.post('/admin/subjects', body: request.toJson()),
          Subject.fromJson);

  Future<Subject> updateSubject(int id, SubjectRequest request) =>
      _single(_client.put('/admin/subjects/$id', body: request.toJson()),
          Subject.fromJson);

  Future<void> deleteSubject(int id) => _client.delete('/admin/subjects/$id');

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
