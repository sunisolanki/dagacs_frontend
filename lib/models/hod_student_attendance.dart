/// Matches the backend `HodStudentAttendanceDTO`.
///
/// [percentage] is nullable — `null` means no recorded attendance for the
/// student. The backend is the single source of truth for every value.
///
/// The academic-context fields are populated only by the context-scoped query.
/// On the backward-compatible department-wide query they stay null, so the UI
/// can honestly distinguish "department-wide" from "this exact context".
class HodStudentAttendance {
  final String rollNumber;

  /// Phase 3: stable identifier, populated only by the academic-context-scoped
  /// query. Null on the department-wide query, where the UI therefore does not
  /// offer a drill-down rather than guessing an id.
  final int? studentId;

  /// Nullable: enrolment number is optional on the Student profile.
  final String? enrollmentNumber;

  final String studentName;

  final String sectionName;

  /// Academic context; null on the department-wide query.
  final String? academicSessionName;

  final String? programName;

  final String? semesterName;

  final int presentCount;
  final int totalRecordedCount;
  final double? percentage;

  const HodStudentAttendance({
    required this.rollNumber,
    required this.studentName,
    required this.sectionName,
    required this.presentCount,
    required this.totalRecordedCount,
    this.studentId,
    this.enrollmentNumber,
    this.academicSessionName,
    this.programName,
    this.semesterName,
    this.percentage,
  });

  factory HodStudentAttendance.fromJson(Map<String, dynamic> json) {
    return HodStudentAttendance(
      rollNumber: json['rollNumber'] as String? ?? '',
      studentId: (json['studentId'] as num?)?.toInt(),
      enrollmentNumber: json['enrollmentNumber'] as String?,
      studentName: json['studentName'] as String? ?? '',
      sectionName: json['sectionName'] as String? ?? '',
      academicSessionName: json['academicSessionName'] as String?,
      programName: json['programName'] as String?,
      semesterName: json['semesterName'] as String?,
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      totalRecordedCount: (json['totalRecordedCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }

  /// True when the row carries a verified academic context.
  bool get hasAcademicContext =>
      academicSessionName != null && programName != null && semesterName != null;
}
