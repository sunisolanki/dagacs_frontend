import 'package:http/http.dart' as http;

import '../models/report_export.dart';
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

  /// Server-side searched/paged student list (backend `StudentPageResponse`).
  ///
  /// Only the explicitly selected ids in [query] are applied - the backend
  /// never re-applies any cascade. `page` and `size` default inside [query].
  Future<StudentPage> searchStudents(StudentSearchQuery query) async {
    try {
      final end = _queryString(query.toQueryParameters());
      final data = await _client.get('/admin/students$end');
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return StudentPage.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  /// Cascaded academic filter options (backend `StudentFilterOptionsResponse`).
  ///
  /// The lists are master-data sourced (never student records) so they stay
  /// available even with zero matching students. Pass the currently selected
  /// ids to scope each list to the "consistent academic context".
  Future<StudentFilterOptionsData> getFilterOptions({
    int? academicSessionId,
    int? programId,
    int? semesterId,
    int? batchId,
    int? sectionId,
  }) async {
    try {
      final end = _queryString({
        if (academicSessionId != null) 'academicSessionId': academicSessionId,
        if (programId != null) 'programId': programId,
        if (semesterId != null) 'semesterId': semesterId,
        if (batchId != null) 'batchId': batchId,
        if (sectionId != null) 'sectionId': sectionId,
      });
      final data = await _client.get('/admin/students/filter-options$end');
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return StudentFilterOptionsData.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  static String _queryString(Map<String, dynamic> params) {
    if (params.isEmpty) return '';
    final mapped = params.map((k, v) => MapEntry(k, '$v'));
    return '?${Uri(queryParameters: mapped).query}';
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

  /// Provisions a STUDENT login account linked by the student's email (M9.5.2).
  /// The backend generates a secure temporary password and sets
  /// mustChangePassword=true; the response carries the temporary password
  /// exactly once (never returned again by later GETs).
  /// 409 if the student already has a login or the email is owned elsewhere;
  /// 400 if the student has no email to link a login to.
  Future<StudentManagement> provisionLogin(int id) async {
    try {
      final data = await _client.post('/admin/students/$id/login');
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return StudentManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  /// Flips only the linked login's ACTIVE/INACTIVE status (D4 - never the
  /// student profile).
  Future<StudentManagement> setLoginStatus(int id, String status) async {
    try {
      final data = await _client
          .patch('/admin/students/$id/login/status', body: {'status': status});
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return StudentManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  /// Resets the linked login's password; the raw password is never returned.
  Future<StudentManagement> setLoginPassword(
      int id, StudentLoginPasswordRequest request) async {
    try {
      final data = await _client
          .put('/admin/students/$id/login/password', body: request.toJson());
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return StudentManagement.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  /// Changes the authenticated student's own password (M10A). Identity comes
  /// only from the JWT; the backend verifies [currentPassword] against the
  /// persisted hash before applying [newPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _client.put('/student/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
  }

  /// Downloads the one-time bulk-import credential artifact (XLSX) by id
  /// (M10A). The backend enforces single-download semantics: a second attempt
  /// returns 409 (surfaced as a typed [ApiException] by [ApiClient.getBytes]).
  Future<DownloadPayload> downloadCredentials(String downloadId) async {
    final http.Response response = await _client
        .getBytes('/admin/students/import/credentials/$downloadId');
    return DownloadPayload(
      bytes: response.bodyBytes,
      fileName: _fileNameFromDisposition(response.headers['content-disposition']) ??
          'student_credentials.xlsx',
      contentType: response.headers['content-type'],
    );
  }

  static String? _fileNameFromDisposition(String? disposition) {
    if (disposition == null || disposition.isEmpty) return null;
    final match = RegExp(r'filename="?([^";]+)"?')
        .firstMatch(disposition);
    return match?.group(1);
  }

  /// Bulk-imports students from an uploaded .xlsx or .csv file (M9.10,
  /// ADMIN-only). The backend performs all parsing and validation and, because
  /// the import is all-or-nothing, either persists the whole file or none of
  /// it. The returned [StudentImportResult] carries the SOW summary shape
  /// (totals plus per-row errors). File-level problems arrive as [ApiException]
  /// with the backend's human-readable message.
  Future<StudentImportResult> importStudents({
    required String filename,
    required List<int> bytes,
    int? academicSessionId,
    int? programId,
    int? batchId,
    int? sectionId,
    int? semesterId,
  }) async {
    final params = <String, dynamic>{};
    if (academicSessionId != null) params['academicSessionId'] = academicSessionId;
    if (programId != null) params['programId'] = programId;
    if (batchId != null) params['batchId'] = batchId;
    if (sectionId != null) params['sectionId'] = sectionId;
    if (semesterId != null) params['semesterId'] = semesterId;
    try {
      final data = await _client.postMultipart(
        '/admin/students/import',
        field: 'file',
        filename: filename,
        bytes: bytes,
        params: params,
      );
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return StudentImportResult.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  /// Previews and validates an import file without persisting anything (M9.10,
  /// ADMIN-only). Returns a [StudentImportResult] with validation errors but
  /// zero DB changes. Call this before [importStudents] to show a preview.
  Future<StudentImportResult> previewImport({
    required String filename,
    required List<int> bytes,
    int? academicSessionId,
    int? programId,
    int? batchId,
    int? sectionId,
    int? semesterId,
  }) async {
    final params = <String, dynamic>{};
    if (academicSessionId != null) params['academicSessionId'] = academicSessionId;
    if (programId != null) params['programId'] = programId;
    if (batchId != null) params['batchId'] = batchId;
    if (sectionId != null) params['sectionId'] = sectionId;
    if (semesterId != null) params['semesterId'] = semesterId;
    try {
      final data = await _client.postMultipart(
        '/admin/students/import/preview',
        field: 'file',
        filename: filename,
        bytes: bytes,
        params: params,
      );
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return StudentImportResult.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }
}