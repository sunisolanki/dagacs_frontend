/// One row of the HOD daily-lecture report (M7.1 `HodDailyLectureReportDTO`).
///
/// The row exists only when a session actually has AttendanceRecord rows - no
/// timetable/expected-lecture semantics. [percentage] is `null` when the total
/// recorded count is zero, never rendered as 0%.
class HodDailyLectureRow {
  final String date;
  final String lecturePeriod;
  final String subjectCode;
  final String subjectName;
  final String sectionCode;
  final String sectionName;
  final int presentCount;
  final int totalRecordedCount;
  final double? percentage;

  const HodDailyLectureRow({
    required this.date,
    required this.lecturePeriod,
    required this.subjectCode,
    required this.subjectName,
    required this.sectionCode,
    required this.sectionName,
    required this.presentCount,
    required this.totalRecordedCount,
    this.percentage,
  });

  factory HodDailyLectureRow.fromJson(Map<String, dynamic> json) {
    return HodDailyLectureRow(
      date: json['date'] as String? ?? '',
      lecturePeriod: json['lecturePeriod'] as String? ?? '',
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