import 'department.dart';
import 'program.dart';

/// Matches backend `AcademicSessionDTO`.
class AcademicSession {
  final int? id;
  final String? name;
  final String? code;
  final String? description;
  final int? programId;
  final Program? program;
  final String? createdAt;
  final String? updatedAt;

  const AcademicSession({
    this.id,
    this.name,
    this.code,
    this.description,
    this.programId,
    this.program,
    this.createdAt,
    this.updatedAt,
  });

  factory AcademicSession.fromJson(Map<String, dynamic> json) {
    final progJson = json['program'];
    return AcademicSession(
      id: json['id'] as int?,
      name: json['name'] as String?,
      code: json['code'] as String?,
      description: json['description'] as String?,
      programId: json['programId'] as int?,
      program: progJson is Map<String, dynamic>
          ? Program.fromJson(progJson)
          : null,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

/// One consolidated, human-readable label for an Academic Session:
/// `{session name} — {program name} — {department name}`.
///
/// Some backend responses only embed the session name (and at best a shallow
/// program); [programsById] supplies the program/department detail the caller
/// fetched via `GET /admin/programs` so the full context can be shown without
/// faking data. Missing parts degrade to explicit `* unavailable` markers.
String academicSessionContextLabel(
  AcademicSession? session, {
  Map<int, Program>? programsById,
}) {
  final sessionName = session?.name?.trim();
  if (session == null || sessionName == null || sessionName.isEmpty) {
    return 'Academic session unavailable';
  }
  final Program? program = session.program ??
      ((session.programId != null && programsById != null)
          ? programsById[session.programId]
          : null);
  String? programName;
  String? departmentName;
  if (program == null ||
      (program.name?.trim().isEmpty ?? false)) {
    programName = 'Program unavailable';
  } else {
    programName = program.name;
  }
  if (program != null) {
    final Program? richer =
        (program.id != null && programsById != null)
            ? programsById[program.id]
            : null;
    final Department? department = program.department ?? richer?.department;
    final deptName = department?.name?.trim();
    departmentName = (deptName == null || deptName.isEmpty)
        ? 'Department unavailable'
        : deptName;
  } else {
    departmentName = 'Department unavailable';
  }
  return '$sessionName — $programName — $departmentName';
}

/// Mutable fields sent for POST/PUT `/api/admin/academic-sessions`.
class AcademicSessionRequest {
  const AcademicSessionRequest({
    required this.name,
    required this.code,
    required this.programId,
    this.description,
  });

  final String name;
  final String code;
  final int programId;
  final String? description;

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'programId': programId,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };
}
