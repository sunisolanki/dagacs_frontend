import '../core/context/hod_academic_context.dart';

/// One selectable node returned by the HOD hierarchy API.
///
/// Values are display labels only. Authorization is enforced entirely
/// server-side from the authenticated HOD, so nothing here is ever treated as
/// an authority by the client.
class HodHierarchyOption {
  const HodHierarchyOption({
    required this.id,
    required this.name,
    this.code,
    this.programId,
    this.programName,
    this.batchId,
    this.batchName,
    this.studentCount,
  });

  final int id;
  final String name;
  final String? code;
  final int? programId;
  final String? programName;
  final int? batchId;
  final String? batchName;
  final int? studentCount;

  factory HodHierarchyOption.fromJson(Map<String, dynamic> json) {
    return HodHierarchyOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      programId: (json['programId'] as num?)?.toInt(),
      programName: json['programName'] as String?,
      batchId: (json['batchId'] as num?)?.toInt(),
      batchName: json['batchName'] as String?,
      studentCount: (json['studentCount'] as num?)?.toInt(),
    );
  }

  HodContextOption toContextOption() => HodContextOption(
        id: id,
        label: name,
        code: code,
      );
}

/// Root of the HOD hierarchy: the HOD's own department plus the two cascade
/// roots.
class HodHierarchyRoot {
  const HodHierarchyRoot({
    required this.departmentId,
    this.departmentName,
    this.departmentCode,
    this.programs = const [],
    this.academicSessions = const [],
  });

  final int departmentId;
  final String? departmentName;
  final String? departmentCode;
  final List<HodHierarchyOption> programs;
  final List<HodHierarchyOption> academicSessions;

  factory HodHierarchyRoot.fromJson(Map<String, dynamic> json) {
    List<HodHierarchyOption> options(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => HodHierarchyOption.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return HodHierarchyRoot(
      departmentId: (json['departmentId'] as num?)?.toInt() ?? 0,
      departmentName: json['departmentName'] as String?,
      departmentCode: json['departmentCode'] as String?,
      programs: options('programs'),
      academicSessions: options('academicSessions'),
    );
  }
}

/// A subject offered in a specific academic context.
class HodHierarchySubject {
  const HodHierarchySubject({
    required this.id,
    required this.name,
    this.code,
    this.semesterId,
    this.semesterName,
    this.programId,
    this.programName,
    this.facultyNames = const [],
  });

  final int id;
  final String name;
  final String? code;
  final int? semesterId;
  final String? semesterName;
  final int? programId;
  final String? programName;

  /// Teachers assigned to teach this offering to the scoped section. Empty
  /// when the request was not section-scoped or nobody is assigned yet.
  final List<String> facultyNames;

  factory HodHierarchySubject.fromJson(Map<String, dynamic> json) {
    final faculty = json['facultyNames'];
    return HodHierarchySubject(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      semesterId: (json['semesterId'] as num?)?.toInt(),
      semesterName: json['semesterName'] as String?,
      programId: (json['programId'] as num?)?.toInt(),
      programName: json['programName'] as String?,
      facultyNames: faculty is List
          ? faculty.whereType<String>().toList(growable: false)
          : const [],
    );
  }

  HodContextOption toContextOption() => HodContextOption(
        id: id,
        label: name,
        code: code,
      );
}

/// Distinguishes the four states a hierarchy level can be in, so a failure is
/// never rendered as an empty selection.
enum HodHierarchyStatus { idle, loading, ready, empty, unauthorized, error }
