/// Matches the backend `HodLowAttendanceDTO`.
///
/// The backend applies the FIXED 75.0% threshold (`percentage < 75.0`).
/// Flutter only displays the already-filtered list — it never re-applies or
/// configures a threshold.
///
/// The academic-context fields are populated only by the context-scoped query
/// and stay null on the department-wide query.
class HodLowAttendance {
  final String rollNumber;

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

  const HodLowAttendance({
    required this.rollNumber,
    required this.studentName,
    required this.sectionName,
    required this.presentCount,
    required this.totalRecordedCount,
    this.enrollmentNumber,
    this.academicSessionName,
    this.programName,
    this.semesterName,
    this.percentage,
  });

  factory HodLowAttendance.fromJson(Map<String, dynamic> json) {
    return HodLowAttendance(
      rollNumber: json['rollNumber'] as String? ?? '',
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
