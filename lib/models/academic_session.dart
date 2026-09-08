import 'program.dart';

/// Matches backend `AcademicSessionDTO`.
class AcademicSession {
  final int? id;
  final String? name;
  final String? code;
  final String? semester;
  final int? durationHours;
  final int? lecturePeriods;
  final int? credits;
  final String? description;
  final int? programId;
  final Program? program;
  final String? createdAt;
  final String? updatedAt;

  const AcademicSession({
    this.id,
    this.name,
    this.code,
    this.semester,
    this.durationHours,
    this.lecturePeriods,
    this.credits,
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
      semester: json['semester'] as String?,
      durationHours: json['durationHours'] as int?,
      lecturePeriods: json['lecturePeriods'] as int?,
      credits: json['credits'] as int?,
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

/// Mutable fields sent for POST/PUT `/api/admin/academic-sessions`.
class AcademicSessionRequest {
  const AcademicSessionRequest({
    required this.name,
    required this.code,
    required this.semester,
    required this.durationHours,
    required this.lecturePeriods,
    required this.credits,
    required this.programId,
    this.description,
  });

  final String name;
  final String code;
  final String semester;
  final int durationHours;
  final int lecturePeriods;
  final int credits;
  final int programId;
  final String? description;

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'semester': semester,
        'durationHours': durationHours,
        'lecturePeriods': lecturePeriods,
        'credits': credits,
        'programId': programId,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };
}
