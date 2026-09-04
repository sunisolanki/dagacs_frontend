import 'academic_session.dart';

/// Matches backend `SemesterDTO`.
class Semester {
  final int? id;
  final String? name;
  final String? code;
  final int? year;
  final int? academicSessionId;
  final AcademicSession? academicSession;
  final String? createdAt;
  final String? updatedAt;

  const Semester({
    this.id,
    this.name,
    this.code,
    this.year,
    this.academicSessionId,
    this.academicSession,
    this.createdAt,
    this.updatedAt,
  });

  factory Semester.fromJson(Map<String, dynamic> json) {
    final sessionJson = json['academicSession'];
    return Semester(
      id: json['id'] as int?,
      name: json['name'] as String?,
      code: json['code'] as String?,
      year: json['year'] as int?,
      academicSessionId: json['academicSessionId'] as int?,
      academicSession: sessionJson is Map<String, dynamic>
          ? AcademicSession.fromJson(sessionJson)
          : null,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}
