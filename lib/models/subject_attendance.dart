class SubjectAttendance {
  final int subjectId;
  final String subjectName;
  final int presentCount;
  final int totalRecordedCount;
  final double? percentage;

  SubjectAttendance({
    required this.subjectId,
    required this.subjectName,
    required this.presentCount,
    required this.totalRecordedCount,
    this.percentage,
  });

  factory SubjectAttendance.fromJson(Map<String, dynamic> json) {
    return SubjectAttendance(
      subjectId: json['subjectId'] as int,
      subjectName: json['subjectName'] as String? ?? '',
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      totalRecordedCount: (json['totalRecordedCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }
}
