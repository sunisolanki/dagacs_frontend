import '../models/hod_hierarchy.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Read-only access to the HOD-scoped academic hierarchy.
///
/// Every endpoint is scoped server-side to the authenticated HOD's department
/// via the JWT. This client never sends, and the server never accepts, a
/// department id as an authority.
class HodHierarchyRepository {
  HodHierarchyRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Department identity plus the two cascade roots (programs, sessions).
  Future<HodHierarchyRoot> getRoot() async {
    try {
      final data = await _client.get('/hod/hierarchy');
      if (data is! Map) {
        throw const ApiException.serverError();
      }
      return HodHierarchyRoot.fromJson(Map<String, dynamic>.from(data));
    } on ApiException {
      rethrow;
    }
  }

  /// Semesters of one academic session.
  Future<List<HodHierarchyOption>> getSemesters({required int academicSessionId}) =>
      _list('/hod/hierarchy/semesters?academicSessionId=$academicSessionId',
          HodHierarchyOption.fromJson);

  /// Sections of an academic session, optionally restricted to a semester.
  Future<List<HodHierarchyOption>> getSections({
    required int academicSessionId,
    int? programId,
    int? semesterId,
  }) {
    final params = <String>['academicSessionId=$academicSessionId'];
    if (programId != null) params.add('programId=$programId');
    if (semesterId != null) params.add('semesterId=$semesterId');
    return _list('/hod/hierarchy/sections?${params.join('&')}',
        HodHierarchyOption.fromJson);
  }

  /// Subjects offered in a semester, optionally with the faculty of a section.
  Future<List<HodHierarchySubject>> getSubjects({
    required int semesterId,
    int? sectionId,
  }) {
    final params = <String>['semesterId=$semesterId'];
    if (sectionId != null) params.add('sectionId=$sectionId');
    return _list('/hod/hierarchy/subjects?${params.join('&')}',
        HodHierarchySubject.fromJson);
  }

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
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
