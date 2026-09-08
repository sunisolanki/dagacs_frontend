/// One row of the teacher's own subject-wise attendance report (M7.1
/// `TeacherSubjectReportDTO`).
///
/// The backend resolves the authenticated teacher from the JWT - the client
/// never sends a teacherId/studentId/departmentId/sectionId. subjectId/sectionId
/// are neutral labels returned by the backend and are intentionally ignored
/// here (nothing to select in the UI).
class TeacherReportRow {
  final String subjectCode;
  final String subjectName;
  final String sectionCode;
  final String sectionName;
  final int presentCount;
  final int totalRecordedCount;
  final double? percentage;

  const TeacherReportRow({
    required this.subjectCode,
    required this.subjectName,
    required this.sectionCode,
    required this.sectionName,
    required this.presentCount,
    required this.totalRecordedCount,
    this.percentage,
  });

  factory TeacherReportRow.fromJson(Map<String, dynamic> json) {
    return TeacherReportRow(
      subjectCode: json['subjectCode'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      sectionCode: json['sectionCode'] as String? ?? '',
      sectionName: json['sectionName'] as String? ?? '',
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      totalRecordedCount: (json['totalRecordedCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }
}